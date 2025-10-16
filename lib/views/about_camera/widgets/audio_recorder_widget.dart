import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../controllers/audio_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/comment_record_controller.dart';
import '../../../models/comment_record_model.dart';
import '../../../utils/position_converter.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

/// 오디오 녹음 위젯
///
/// 음성 녹음과 재생 기능을 제공하는 위젯입니다.
/// 댓글 모드와 편집 모드에서 서로 다른 동작을 합니다.

enum RecordingState {
  recording, // 녹음 중
  recorded, // 녹음 완료 상태
  profile, // 프로필 모드 (댓글용)
}

class AudioRecorderWidget extends StatefulWidget {
  // 기본 콜백들
  final Function(String?, List<double>?)? onRecordingCompleted;
  final Function(String audioFilePath, List<double> waveformData, int duration)?
  onRecordingFinished;
  final Function(CommentRecordModel)? onCommentSaved;
  final VoidCallback? onRecordingCleared;
  final String? initialRecordingPath;
  final List<double>? initialWaveformData;

  // 동작 설정
  final bool autoStart;
  final bool isCommentMode;
  final bool isCurrentUserPhoto;

  // 댓글 관련 설정
  final String? photoId;
  final CommentRecordModel? savedComment;

  // 프로필 위치 관련
  final Function(Offset)? onProfileImageDragged;
  final Offset? profileImagePosition;
  final Offset? Function()? getProfileImagePosition;
  final VoidCallback? onCommentPositioned;

  const AudioRecorderWidget({
    super.key,
    this.onRecordingCompleted,
    this.onRecordingFinished,
    this.onCommentSaved,
    this.onRecordingCleared,
    this.initialRecordingPath,
    this.initialWaveformData,
    this.autoStart = false,
    this.photoId,
    this.isCommentMode = true,
    this.onProfileImageDragged,
    this.savedComment,
    this.profileImagePosition,
    this.getProfileImagePosition,
    this.onCommentPositioned,
    this.isCurrentUserPhoto = true,
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget>
    with SingleTickerProviderStateMixin {
  // ========== 컨트롤러들 ==========
  late AudioController _audioController;
  late RecorderController recorderController;
  PlayerController? playerController;

  // ========== 상태 관리 변수들 ==========
  RecordingState _currentState = RecordingState.recording;
  RecordingState? _lastState;

  // 녹음 데이터
  String? _recordedFilePath;
  List<double>? _waveformData;

  // 댓글 관련
  String? _lastSavedCommentId;
  String? _userProfileImageUrl;

  // 오디오 상태 모니터링
  Timer? _audioControllerTimer;
  bool _wasRecording = true;

  // ========== 생명주기 메서드들 ==========
  @override
  void initState() {
    super.initState();
    _initializeAudioControllers();
    _initializeState();
    _handleAutoStart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audioController = Provider.of<AudioController>(context, listen: false);
  }

  @override
  void dispose() {
    _stopAudioControllerListener();
    recorderController.dispose();
    playerController?.dispose();
    super.dispose();
  }

  // ========== 초기화 메서드들 ==========
  void _initializeAudioControllers() {
    recorderController =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 44100;

    recorderController.checkPermission();
    playerController = PlayerController();
    _audioController = Provider.of<AudioController>(context, listen: false);
  }

  void _initializeState() {
    if (widget.savedComment != null) {
      _currentState = RecordingState.recorded;
      _userProfileImageUrl = widget.savedComment!.profileImageUrl;
      _recordedFilePath = widget.savedComment!.audioUrl;
      _waveformData = widget.savedComment!.waveformData;
    } else if (widget.initialRecordingPath != null &&
        widget.initialRecordingPath!.isNotEmpty) {
      _currentState = RecordingState.recorded;
      _recordedFilePath = widget.initialRecordingPath;
      _waveformData = widget.initialWaveformData;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preparePlayerForExistingRecording();
      });
    } else if (widget.autoStart) {
      _currentState = RecordingState.recording;
    }
  }

  Future<void> _preparePlayerForExistingRecording() async {
    if (!mounted) return;

    final path = widget.initialRecordingPath;
    if (path == null || path.isEmpty || playerController == null) {
      return;
    }

    try {
      await playerController!.preparePlayer(
        path: path,
        shouldExtractWaveform: widget.initialWaveformData == null,
      );

      if ((_waveformData == null || _waveformData!.isEmpty)) {
        final extractedWaveform = await playerController!.extractWaveformData(
          path: path,
          noOfSamples: 100,
        );

        if (extractedWaveform.isNotEmpty && mounted) {
          setState(() {
            _waveformData = extractedWaveform;
          });
        } else if (_waveformData == null && extractedWaveform.isNotEmpty) {
          _waveformData = extractedWaveform;
        }
      }
    } catch (e) {
      debugPrint('기존 녹음 준비 오류: $e');
    }
  }

  void _handleAutoStart() {
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });
    }
  }

  // ========== 녹음 관련 메서드들 ==========

  Future<void> _startRecording() async {
    try {
      await recorderController.record();
      await _audioController.startRecording();
      _setState(RecordingState.recording);
      _startAudioControllerListener();
      debugPrint('녹음 시작 완료 - 상태: $_currentState');
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
      // 에러 발생 시 위젯을 제거하여 텍스트 필드로 돌아감
      widget.onRecordingCleared?.call();
    }
  }

  Future<void> _stopAndPreparePlayback() async {
    try {
      debugPrint('녹음 정지 및 재생 준비 시작...');

      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );

      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
      }

      await _audioController.stopRecordingSimple();

      if (_audioController.currentRecordingPath != null &&
          _audioController.currentRecordingPath!.isNotEmpty &&
          playerController != null) {
        try {
          await playerController!.preparePlayer(
            path: _audioController.currentRecordingPath!,
            shouldExtractWaveform: true,
          );

          if (waveformData.isEmpty) {
            final extractedWaveform = await playerController!
                .extractWaveformData(
                  path: _audioController.currentRecordingPath!,
                  noOfSamples: 100,
                );
            if (extractedWaveform.isNotEmpty) {
              waveformData = extractedWaveform;
            }
          }
        } catch (e) {
          debugPrint('재생 준비 오류: $e');
        }
      }

      setState(() {
        _lastState = _currentState;
        _currentState = RecordingState.recorded;
        _recordedFilePath = _audioController.currentRecordingPath;
        _waveformData = waveformData;
      });

      if (widget.onRecordingCompleted != null) {
        widget.onRecordingCompleted!(
          _audioController.currentRecordingPath,
          waveformData,
        );
      }
    } catch (e) {
      debugPrint('녹음 정지 오류: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      debugPrint('녹음 취소 및 완전 초기화 시작...');

      _stopAudioControllerListener();

      if (recorderController.hasPermission) {
        await recorderController.stop();
      }

      await _audioController.stopRecordingSimple();

      if (playerController?.playerState.isPlaying == true) {
        await playerController?.stopPlayer();
      }

      // 상태 초기화 (setState 호출하지 않음)
      _lastState = _currentState;
      _recordedFilePath = null;
      _waveformData = null;
      _userProfileImageUrl = null;
      _lastSavedCommentId = null;

      debugPrint('녹음 취소 및 초기화 완료');
    } catch (e) {
      debugPrint('녹음 취소 오류: $e');
      // 에러 발생 시에도 상태만 초기화 (setState 호출하지 않음)
      _lastState = _currentState;
      _recordedFilePath = null;
      _waveformData = null;
      _userProfileImageUrl = null;
      _lastSavedCommentId = null;
    }

    // 부모 위젯에 알려서 텍스트 필드로 전환
    widget.onRecordingCleared?.call();
  }

  void _deleteRecording() {
    try {
      if (playerController?.playerState.isPlaying == true) {
        playerController?.stopPlayer();
      }

      // 상태 초기화 (setState 호출하지 않음)
      _lastState = _currentState;
      _recordedFilePath = null;
      _waveformData = null;
    } catch (e) {
      debugPrint('녹음 파일 삭제 오류: $e');
    }

    // 부모 위젯에 알려서 텍스트 필드로 전환
    widget.onRecordingCleared?.call();
  }

  // ========== 재생 관련 메서드들 ==========

  Future<void> _togglePlayback() async {
    if (playerController == null || _recordedFilePath == null) return;

    try {
      if (playerController!.playerState.isPlaying) {
        await playerController!.pausePlayer();
        debugPrint('재생 일시정지');
      } else {
        if (playerController!.playerState == PlayerState.initialized ||
            playerController!.playerState == PlayerState.paused) {
          await playerController!.startPlayer();
          debugPrint('재생 시작');
        } else {
          await playerController!.preparePlayer(path: _recordedFilePath!);
          await playerController!.startPlayer();
          debugPrint('재생 준비 후 시작');
        }
      }
      setState(() {});
    } catch (e) {
      debugPrint('재생/일시정지 오류: $e');
    }
  }

  void _onWaveformTapped() async {
    if (!widget.isCommentMode) {
      return;
    }

    if (mounted) {
      setState(() {
        _lastState = _currentState;
        _currentState = RecordingState.profile;
      });
    }

    _loadUserProfileImage();
  }

  // ========== 프로필 관련 메서드들 ==========

  Future<void> _loadUserProfileImage() async {
    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final currentUserId = authController.getUserId;

      if (currentUserId != null) {
        final profileImageUrl = await authController.getUserProfileImageUrlById(
          currentUserId,
        );

        if (mounted) {
          setState(() {
            _userProfileImageUrl = profileImageUrl;
          });
        }
      }
    } catch (e) {
      debugPrint('프로필 이미지 로드 실패: $e');
    }
  }

  Future<void> _saveCommentRecord({
    required String audioFilePath,
    required List<double> waveformData,
    required int duration,
  }) async {
    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        debugPrint('❌ 현재 사용자 ID가 null입니다');
        return;
      }

      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(currentUserId);

      final commentRecordController = CommentRecordController();
      final currentProfilePosition =
          widget.getProfileImagePosition?.call() ?? widget.profileImagePosition;

      Offset? relativePosition;
      if (currentProfilePosition != null) {
        final imageSize = Size(354.w, 500.h);
        relativePosition = PositionConverter.toRelativePosition(
          currentProfilePosition,
          imageSize,
        );
      } else {
        relativePosition = null;
        debugPrint('음성 댓글 위치 미설정 - 사용자가 드래그를 통해 위치를 설정해야 합니다.');
      }

      final commentRecord = await commentRecordController.createCommentRecord(
        audioFilePath: audioFilePath,
        photoId: widget.photoId!,
        recorderUser: currentUserId,
        waveformData: waveformData,
        duration: duration,
        profileImageUrl: profileImageUrl,
        relativePosition: relativePosition,
      );

      if (commentRecord != null) {
        _userProfileImageUrl = profileImageUrl;
        _lastSavedCommentId = commentRecord.id;

        if (widget.onCommentSaved != null) {
          widget.onCommentSaved!(commentRecord);
        }
      }
    } catch (e) {
      debugPrint('CommentRecord 저장 중 오류: $e');
    }
  }

  // ========== 오디오 상태 모니터링 ==========

  void _startAudioControllerListener() {
    _wasRecording = true;
    _audioControllerTimer = Timer.periodic(Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        _audioControllerTimer = null;
        return;
      }

      final isCurrentlyRecording = _audioController.isRecording;

      if (_wasRecording && !isCurrentlyRecording) {
        timer.cancel();
        _audioControllerTimer = null;
        _handleAudioControllerStopped();
      }
    });
  }

  void _stopAudioControllerListener() {
    _audioControllerTimer?.cancel();
    _audioControllerTimer = null;
  }

  Future<void> _handleAudioControllerStopped() async {
    try {
      if (!mounted) {
        return;
      }

      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );
      await recorderController.stop();

      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
      }

      _recordedFilePath = _audioController.currentRecordingPath;

      if (playerController != null && _recordedFilePath != null) {
        try {
          await playerController!.preparePlayer(
            path: _recordedFilePath!,
            shouldExtractWaveform: false,
          );
        } catch (e) {
          debugPrint('재생 컨트롤러 준비 오류: $e');
        }
      }

      if (widget.isCommentMode &&
          widget.photoId != null &&
          _recordedFilePath != null &&
          _recordedFilePath!.isNotEmpty &&
          waveformData.isNotEmpty) {
        await _saveCommentRecord(
          audioFilePath: _recordedFilePath!,
          waveformData: waveformData,
          duration: _audioController.recordingDuration,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _lastState = _currentState;
        _currentState = RecordingState.recorded;
        _waveformData = waveformData;
      });

      if (widget.onRecordingCompleted != null) {
        widget.onRecordingCompleted!(_recordedFilePath, waveformData);
      }
      if (widget.onRecordingFinished != null &&
          _recordedFilePath != null &&
          waveformData.isNotEmpty) {
        widget.onRecordingFinished!(
          _recordedFilePath!,
          waveformData,
          _audioController.recordingDuration,
        );
      }
    } catch (e) {
      if (mounted) {
        // 에러 발생 시 위젯을 제거하여 텍스트 필드로 돌아감
        widget.onRecordingCleared?.call();
      }
    }
  }

  // ========== 상태 관리 및 헬퍼 메서드들 ==========

  void _setState(RecordingState newState) {
    if (mounted) {
      setState(() {
        _lastState = _currentState;
        _currentState = newState;
      });
    }
  }

  void _resetToMicrophoneIcon() {
    // idle 상태가 제거되어 이 메서드는 더 이상 사용되지 않음
    // 대신 onRecordingCleared를 호출하여 텍스트 필드로 돌아감
    widget.onRecordingCleared?.call();
  }

  void resetToMicrophoneIcon() {
    _resetToMicrophoneIcon();
  }

  // ========== UI 빌드 메서드들 ==========

  @override
  Widget build(BuildContext context) {
    bool shouldAnimate =
        !(_lastState == RecordingState.recording &&
            _currentState == RecordingState.recorded);

    if (!shouldAnimate) {
      return _buildCurrentStateWidget();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: _buildCurrentStateWidget(),
    );
  }

  Widget _buildCurrentStateWidget() {
    String widgetKey;
    if (_lastState == RecordingState.recording &&
        _currentState == RecordingState.recorded) {
      widgetKey = 'audio-ui-no-animation';
    } else if (_currentState == RecordingState.profile) {
      widgetKey = 'profile-mode';
    } else {
      widgetKey = _currentState.toString();
    }

    switch (_currentState) {
      case RecordingState.recording:
        return Selector<AudioController, String>(
          key: ValueKey(widgetKey),
          selector:
              (context, controller) => controller.formattedRecordingDuration,
          builder: (context, duration, child) {
            return SizedBox(
              height: 46,
              child: _buildAudioUI(
                backgroundColor: const Color(
                  0xff373737,
                ).withValues(alpha: 0.66),
                isRecording: true,
                duration: duration,
              ),
            );
          },
        );

      case RecordingState.recorded:
        return SizedBox(
          key: ValueKey(widgetKey),
          height: 46,
          child: _buildAudioUI(
            backgroundColor: const Color(0xff222222),
            isRecording: false,
          ),
        );

      case RecordingState.profile:
        return Container(
          key: ValueKey(widgetKey),
          child: _buildFullProfileModeUI(),
        );
    }
  }

  Widget _buildAudioUI({
    required Color backgroundColor,
    required bool isRecording,
    String? duration,
  }) {
    final borderRadius = BorderRadius.circular(21.5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      key: const ValueKey('audio_ui'),
      curve: Curves.easeInOut,

      decoration: BoxDecoration(borderRadius: borderRadius),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: borderRadius,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder:
                  (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
              child: Container(color: backgroundColor),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 14.w),
              // 삭제 버튼
              GestureDetector(
                onTap: isRecording ? _cancelRecording : _deleteRecording,
                child: Image.asset('assets/trash.png', width: 25, height: 25),
              ),
              SizedBox(width: 17.w),
              // 파형 표시 영역
              Expanded(
                child:
                    isRecording
                        ? AudioWaveforms(
                          size: Size(1, 44.h),
                          recorderController: recorderController,
                          waveStyle: const WaveStyle(
                            waveColor: Colors.white,
                            extendWaveform: true,
                            showMiddleLine: false,
                          ),
                        )
                        : _buildWaveformDisplay(),
              ),
              SizedBox(width: 13.w),
              // 시간 표시
              SizedBox(
                child:
                    isRecording
                        ? Text(
                          duration ?? '00:00',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.40,
                          ),
                        )
                        : StreamBuilder<int>(
                          stream:
                              playerController?.onCurrentDurationChanged ??
                              const Stream.empty(),
                          builder: (context, snapshot) {
                            final currentDurationMs = snapshot.data ?? 0;
                            final currentDuration = Duration(
                              milliseconds: currentDurationMs,
                            );
                            final minutes = currentDuration.inMinutes;
                            final seconds = currentDuration.inSeconds % 60;
                            return Text(
                              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.40,
                              ),
                            );
                          },
                        ),
              ),
              // 재생/정지 버튼
              IconButton(
                onPressed:
                    isRecording ? _stopAndPreparePlayback : _togglePlayback,
                padding: EdgeInsets.only(bottom: 0.h),
                icon:
                    isRecording
                        ? Icon(Icons.stop, color: Colors.white, size: 35.sp)
                        : StreamBuilder<PlayerState>(
                          stream:
                              playerController?.onPlayerStateChanged ??
                              const Stream.empty(),
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data?.isPlaying ?? false;
                            return Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 35.sp,
                            );
                          },
                        ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformDisplay() {
    return _waveformData != null && _waveformData!.isNotEmpty
        ? GestureDetector(
          onTap: _onWaveformTapped,
          child: StreamBuilder<int>(
            stream:
                playerController?.onCurrentDurationChanged ??
                const Stream.empty(),
            builder: (context, positionSnapshot) {
              final currentPosition = positionSnapshot.data ?? 0;
              final totalDuration = playerController?.maxDuration ?? 1;
              final progress =
                  totalDuration > 0
                      ? (currentPosition / totalDuration).clamp(0.0, 1.0)
                      : 0.0;

              return CustomWaveformWidget(
                waveformData: _waveformData!,
                color: Colors.grey,
                activeColor: Colors.white,
                progress: progress,
              );
            },
          ),
        )
        : GestureDetector(
          onTap: _onWaveformTapped,
          child: Container(
            height: 52.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '파형 없음',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14.sp,
                  fontFamily: "Pretendard",
                ),
              ),
            ),
          ),
        );
  }

  Widget _buildFullProfileModeUI() {
    double screenWidth = MediaQuery.of(context).size.width;

    final profileWidget = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child:
            _userProfileImageUrl != null && _userProfileImageUrl!.isNotEmpty
                ? Image.network(
                  _userProfileImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        color: Colors.grey.shade600,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: (screenWidth * 0.08).clamp(30.0, 40.0),
                        ),
                      ),
                )
                : Container(
                  color: Colors.grey.shade600,
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: (screenWidth * 0.08).clamp(30.0, 40.0),
                  ),
                ),
      ),
    );

    return Draggable<String>(
      data: _lastSavedCommentId ?? '',
      feedback: Transform.scale(
        scale: 1.0,
        child: Opacity(opacity: 0.8, child: profileWidget),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: profileWidget),
      onDragEnd: (details) {
        if (details.wasAccepted) {
          if (widget.onCommentPositioned != null) {
            widget.onCommentPositioned!();
          }
        } else {
          if (widget.onProfileImageDragged != null) {
            widget.onProfileImageDragged!(details.offset);
          }
        }
      },
      child: profileWidget,
    );
  }
}
