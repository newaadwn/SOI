import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../controllers/audio_controller.dart';
import '../../../controllers/comment_record_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/comment_record_model.dart';
import '../../../utils/position_converter.dart';
import '../../about_archiving/widgets/common/wave_form_widget/custom_waveform_widget.dart';

/// 오디오 녹음을 위한 위젯
///
/// 녹음 시작/중지 기능과 파형 표시 기능을 제공합니다.
/// AudioController을 사용하여 녹음 및 업로드 로직을 처리합니다.

// ✅ 녹음 상태 enum 추가
enum RecordingState {
  idle, // 녹음 대기
  recording, // 녹음 중
  recorded, // 녹음 완료 (재생 가능)
}

class AudioRecorderWidget extends StatefulWidget {
  // 콜백 함수 시그니처 변경: 파일 경로와 파형 데이터 함께 전달
  final Function(String?, List<double>?)? onRecordingCompleted;

  // CommentRecord 저장 완료 콜백
  final Function(CommentRecordModel)? onCommentSaved;

  // 자동 시작 여부 (음성 댓글용)
  final bool autoStart;

  // 사진 ID (comment_records에 저장하기 위해 필요)
  final String? photoId;

  // ✅ 사용 컨텍스트 구분: true=댓글 모드, false=사진 편집 모드
  final bool isCommentMode;

  // 프로필 이미지 드래그 콜백
  final Function(Offset)? onProfileImageDragged;

  // 저장된 댓글 데이터 (프로필 모드로 시작할 때 사용)
  final CommentRecordModel? savedComment;

  // 현재 프로필 이미지 위치 (외부에서 관리되는 위치)
  final Offset? profileImagePosition;

  // 프로필 위치를 동적으로 가져오기 위한 콜백
  final Offset? Function()? getProfileImagePosition;

  // ✅ 음성 댓글 위치 설정 완료 후 리셋 콜백
  final VoidCallback? onCommentPositioned;

  // 현재 사용자가 올린 사진인지 여부 (아이콘 변경용)
  final bool isCurrentUserPhoto;

  const AudioRecorderWidget({
    super.key,
    this.onRecordingCompleted,
    this.onCommentSaved,
    this.autoStart = false, // 기본값은 false
    this.photoId, // 선택적 파라미터
    this.isCommentMode = true, // ✅ 기본값은 댓글 모드 (기존 동작 유지)
    this.onProfileImageDragged,
    this.savedComment,
    this.profileImagePosition,
    this.getProfileImagePosition,
    this.onCommentPositioned, // ✅ 새로운 콜백 추가
    this.isCurrentUserPhoto = true, // 기본값은 true (기존 동작 유지)
  });

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  // audio관련 기능을 가지고 있는 controller
  late AudioController _audioController;

  /// audio_waveforms 패키지의 녹음 컨트롤러를 설정
  late RecorderController recorderController;

  /// 재생 컨트롤러 (nullable로 변경)
  PlayerController? playerController;

  /// 현재 녹음 상태
  RecordingState _currentState = RecordingState.idle;

  /// 녹음된 파일 경로
  String? _recordedFilePath;

  /// 파형 데이터
  List<double>? _waveformData;

  ///  프로필 이미지 표시 모드 (파형 클릭 시 활성화)
  bool _isProfileMode = false;

  /// 최근 저장된 댓글 ID (드래그 시 위치 업데이트에 사용)
  String? _lastSavedCommentId;

  /// 사용자 프로필 이미지 URL
  String? _userProfileImageUrl;

  @override
  void initState() {
    super.initState();

    // 저장된 댓글이 있으면 프로필 모드로 시작
    if (widget.savedComment != null) {
      _currentState = RecordingState.recorded;
      _isProfileMode = true;
      _userProfileImageUrl = widget.savedComment!.profileImageUrl;
      _recordedFilePath = widget.savedComment!.audioUrl;
      _waveformData = widget.savedComment!.waveformData;
    } else if (widget.autoStart) {
      // autoStart가 true면 처음부터 recording 상태로 시작
      _currentState = RecordingState.recording;
    }

    // audio_waveforms 설정
    recorderController =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 44100;
    recorderController.checkPermission();

    // ✅ 재생 컨트롤러 초기화
    playerController = PlayerController();

    // Provider에서 필요한 Controller 가져오기
    _audioController = Provider.of<AudioController>(context, listen: false);

    // 자동 시작이 활성화된 경우 녹음 시작
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider에서 필요한 ViewModel 가져오기
    // This line might be redundant if _audioController is already initialized in initState
    // unless there's a specific reason to re-fetch it here (e.g., if the provider changes).
    _audioController = Provider.of<AudioController>(context, listen: false);
  }

  /// 녹음 시작 함수
  Future<void> _startRecording() async {
    // 파형 표시를 위한 녹음 컨트롤러 시작
    try {
      await recorderController.record();

      // AudioController의 녹음 시작 함수 호출

      await _audioController.startRecording();

      // ✅ 녹음 상태로 변경
      setState(() {
        _currentState = RecordingState.recording;
      });

      // AudioController 상태 감지를 위한 periodic check 시작
      _startAudioControllerListener();

      debugPrint('녹음 시작 완료 - 상태: $_currentState');
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
      setState(() {
        _currentState = RecordingState.idle;
      });
    }
  }

  /// 녹음 정지 후 즉시 재생 가능한 상태로 전환
  Future<void> _stopAndPreparePlayback() async {
    try {
      debugPrint('녹음 정지 및 재생 준비 시작...');

      // 파형 데이터 추출 (녹음 중지 전에 추출) - 원래 잘 작동하는 방식
      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );

      // 파형 데이터 실제 레벨 유지 (정규화 없이) - 절댓값만 적용
      if (waveformData.isNotEmpty) {
        // 절댓값만 적용, 정규화는 하지 않음
        waveformData = waveformData.map((value) => value.abs()).toList();
      }

      // 녹음 중지
      await _audioController.stopRecordingSimple();

      // 재생 준비
      if (_audioController.currentRecordingPath != null &&
          _audioController.currentRecordingPath!.isNotEmpty &&
          playerController != null) {
        try {
          await playerController!.preparePlayer(
            path: _audioController.currentRecordingPath!,
            shouldExtractWaveform: true, // 파형 추출 활성화
          );

          // 파형 데이터가 비어있으면 PlayerController에서 추출
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
        _currentState = RecordingState.recorded;
        _recordedFilePath = _audioController.currentRecordingPath;
        _waveformData = waveformData;
      });

      // ✅ 콜백 호출 추가 - 실제로 잘 작동하는 파형 데이터를 전달
      if (widget.onRecordingCompleted != null) {
        widget.onRecordingCompleted!(
          _audioController.currentRecordingPath,
          waveformData,
        );
      }

      debugPrint(
        '녹음 정지 및 재생 준비 완료, 최종 파형 데이터: ${_waveformData?.length ?? 0} samples',
      );
    } catch (e) {
      debugPrint('녹음 정지 오류: $e');
    }
  }

  /// 녹음 중지 함수
  Future<void> _stopRecording() async {
    try {
      // 파형 데이터 추출 (원래 잘 작동하는 방식과 동일)
      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );

      // 녹음 중지
      recorderController.stop();

      // AudioController의 간단한 녹음 중지 함수 호출
      await _audioController.stopRecordingSimple();

      // 상태 업데이트
      setState(() {
        _currentState = RecordingState.recorded;
        _recordedFilePath = _audioController.currentRecordingPath;
        _waveformData = waveformData;
      });

      // 재생 컨트롤러 준비
      if (_recordedFilePath != null &&
          _recordedFilePath!.isNotEmpty &&
          playerController != null) {
        try {
          await playerController!.preparePlayer(
            path: _recordedFilePath!,
            shouldExtractWaveform: false, // 이미 파형 데이터가 있으므로
          );
        } catch (e) {
          debugPrint('재생 컨트롤러 준비 오류: $e');
        }
      }

      // 콜백이 있는 경우 녹음 파일 경로와 파형 데이터 함께 전달
      if (widget.onRecordingCompleted != null) {
        widget.onRecordingCompleted!(
          _audioController.currentRecordingPath,
          waveformData,
        );
      }
    } catch (e) {
      debugPrint('❌ 녹음 중지 오류: $e');
      setState(() {
        _currentState = RecordingState.idle;
      });
    }
  }

  /// ✅ 재생/일시정지 토글 함수
  Future<void> _togglePlayback() async {
    if (playerController == null || _recordedFilePath == null) return;

    try {
      if (playerController!.playerState.isPlaying) {
        await playerController!.pausePlayer();
        debugPrint('재생 일시정지');
      } else {
        // 준비 상태 확인 후 재생
        if (playerController!.playerState == PlayerState.initialized ||
            playerController!.playerState == PlayerState.paused) {
          await playerController!.startPlayer();
          debugPrint('재생 시작');
        } else {
          // 준비되지 않았으면 다시 준비
          await playerController!.preparePlayer(path: _recordedFilePath!);
          await playerController!.startPlayer();
          debugPrint('재생 준비 후 시작');
        }
      }
      setState(() {}); // UI 갱신
    } catch (e) {
      debugPrint('재생/일시정지 오류: $e');
    }
  }

  /// ✅ 녹음 파일 삭제 함수
  void _deleteRecording() {
    try {
      // 재생 중이면 중지
      if (playerController?.playerState.isPlaying == true) {
        playerController?.stopPlayer();
      }

      // ✅ mounted 체크 후 상태 초기화
      if (mounted) {
        setState(() {
          _currentState = RecordingState.idle;
          _recordedFilePath = null;
          _waveformData = null;
        });
      }
    } catch (e) {
      debugPrint('녹음 파일 삭제 오류: $e');
    }
  }

  /// 🎯 CommentRecord 저장 메서드 (feed의 방식을 참고)
  Future<void> _saveCommentRecord({
    required String audioFilePath,
    required List<double> waveformData,
    required int duration,
  }) async {
    try {
      // AuthController에서 현재 사용자 정보 가져오기
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        return;
      }

      // 현재 사용자의 프로필 이미지 URL 가져오기
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(currentUserId);

      // CommentRecordController를 사용하여 저장
      final commentRecordController = CommentRecordController();

      // 현재 프로필 위치 사용 (피드와 동일한 방식)
      // getProfileImagePosition 콜백이 있으면 최신 위치를 가져오고, 없으면 profileImagePosition 사용
      final currentProfilePosition =
          widget.getProfileImagePosition?.call() ?? widget.profileImagePosition;

      // 절대 좌표를 상대 좌표로 변환
      Offset? relativePosition;
      if (currentProfilePosition != null) {
        // PhotoDetailScreen에서 사용하는 이미지 크기와 동일하게 설정
        final imageSize = Size(354.w, 500.h);

        relativePosition = PositionConverter.toRelativePosition(
          currentProfilePosition,
          imageSize,
        );
      }

      final commentRecord = await commentRecordController.createCommentRecord(
        audioFilePath: audioFilePath,
        photoId: widget.photoId!,
        recorderUser: currentUserId,
        waveformData: waveformData,
        duration: duration,
        profileImageUrl: profileImageUrl,
        profilePosition: null, // 더 이상 절대 좌표는 사용하지 않음
        relativePosition: relativePosition, // 새로운 상대 좌표 방식 사용
      );

      if (commentRecord != null) {
        // 프로필 이미지 URL 설정
        _userProfileImageUrl = profileImageUrl;
        _lastSavedCommentId = commentRecord.id; // commentId 저장

        // 저장 완료 콜백 호출
        if (widget.onCommentSaved != null) {
          widget.onCommentSaved!(commentRecord);
        }
      }
    } catch (e) {
      debugPrint('CommentRecord 저장 중 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 상태에 따라 다른 UI 표시
    switch (_currentState) {
      case RecordingState.idle:
        // 항상 녹음 버튼 활성화 (여러 댓글 허용)
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(50),
            onTap: _startRecording,
            child: Image.asset(
              widget.isCurrentUserPhoto
                  ? 'assets/record_icon.png'
                  : 'assets/comment.png',
              width: 64,
              height: 64,
            ),
          ),
        );

      case RecordingState.recording:
        return Selector<AudioController, String>(
          selector:
              (context, controller) => controller.formattedRecordingDuration,
          builder: (context, duration, child) {
            return _buildRecordingUI(duration);
          },
        );

      case RecordingState.recorded:
        return _buildPlaybackUI();
    }
  }

  Widget _buildRecordingUI(String duration) {
    return Container(
      width: 376.w,
      height: 52.h,
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1c),
        borderRadius: BorderRadius.circular(14.6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(width: 14.w), // 반응형 간격
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 32.w, // 반응형 너비
              height: 32.h, // 반응형 높이
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/trash.png',
                width: 32.w, // 반응형 너비
                height: 32.h, // 반응형 높이
              ),
            ),
          ),
          SizedBox(width: 17.w), // 반응형 간격
          Expanded(
            child: AudioWaveforms(
              size: Size(1, 52.h),
              recorderController: recorderController,
              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),
          SizedBox(width: (13.15).w), // 반응형 간격
          SizedBox(
            width: 40.w,
            child: Text(
              duration,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontFamily: "Pretendard",
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 19.w),
            child: IconButton(
              onPressed: () {
                _stopAndPreparePlayback();
              },
              icon: Icon(
                Icons.stop,
                color: Colors.white,
                size: 28.sp, // 반응형 아이콘 크기
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 재생 UI 빌드 (녹음 완료 후) - 프로필 모드일 때 완전히 대체
  Widget _buildPlaybackUI() {
    // 🎯 프로필 모드일 때는 전체 UI를 프로필 이미지로 완전히 대체
    if (_isProfileMode) {
      return _buildFullProfileModeUI();
    }

    // 기존 녹음 UI (파형 모드)
    return Container(
      width: 376.w, // 반응형 너비
      height: 52.h, // 반응형 높이
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1c), // 회색 배경
        borderRadius: BorderRadius.circular(14.6), // 반응형 반지름
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(width: 14.w), // 반응형 간격
          // 쓰레기통 아이콘 (삭제)
          GestureDetector(
            onTap: _deleteRecording,
            child: Container(
              width: 32.w, // 반응형 너비
              height: 32.h, // 반응형 높이
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/trash.png'),
            ),
          ),

          SizedBox(width: 17.w), // 반응형 간격
          // 재생 파형 (클릭하면 프로필 모드로 전환)
          Expanded(child: _buildWaveformDisplay()),
          SizedBox(width: (13.15).w), // 반응형 간격
          // 재생 시간 표시
          StreamBuilder<int>(
            stream:
                playerController?.onCurrentDurationChanged ??
                const Stream.empty(),
            builder: (context, snapshot) {
              final currentDurationMs = snapshot.data ?? 0;
              final currentDuration = Duration(milliseconds: currentDurationMs);
              final minutes = currentDuration.inMinutes;
              final seconds = currentDuration.inSeconds % 60;
              return SizedBox(
                width: 40.w,
                child: Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontFamily: "Pretendard",
                  ),
                ),
              );
            },
          ),

          // 재생/일시정지 버튼
          Padding(
            padding: EdgeInsets.only(right: 19.w),
            child: IconButton(
              onPressed: _togglePlayback,
              icon: StreamBuilder<PlayerState>(
                stream:
                    playerController?.onPlayerStateChanged ??
                    const Stream.empty(),
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data?.isPlaying ?? false;
                  return Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28.sp, // 반응형 아이콘 크기
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 프로필 모드 UI - 전체 녹음 UI를 프로필 이미지로 완전히 대체 (feed 스타일)
  Widget _buildFullProfileModeUI() {
    double screenWidth = MediaQuery.of(context).size.width;
    //double screenHeight = MediaQuery.of(context).size.height;

    final profileWidget = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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

    // Draggable로 감싸서 드래그 가능하게 만들기
    return Draggable<String>(
      // commentId 가 반드시 있어야 위치 저장 가능. 없으면 빈 문자열 전달하여 DragTarget 거부.
      data: _lastSavedCommentId ?? '',

      feedback: Transform.scale(
        scale: 1.0, // 드래그 중에는 조금 더 크게
        child: Opacity(opacity: 0.8, child: profileWidget),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: profileWidget),
      onDragEnd: (details) {
        // DragTarget에서 성공적으로 처리된 경우에만 리셋
        if (details.wasAccepted) {
          // ✅ 위치 설정 완료 콜백 호출 (부모가 리셋을 담당)
          if (widget.onCommentPositioned != null) {
            widget.onCommentPositioned!();
          }
          // 드래그 성공 후에는 아이콘 바로 리셋하지 않고 유지하여 추가 위치 조정 허용 (요구 시 주석 해제)
          // Future.delayed(Duration(milliseconds: 300), () { _resetToMicrophoneIcon(); });
        } else {
          // 외부 콜백이 있으면 호출, 없으면 내부 처리
          if (widget.onProfileImageDragged != null) {
            widget.onProfileImageDragged!(details.offset);
          }
        }
      },
      child: profileWidget,
    );
  }

  /// AudioController 상태 감지를 위한 리스너
  Timer? _audioControllerTimer;
  bool _wasRecording = true;

  void _startAudioControllerListener() {
    _wasRecording = true;
    _audioControllerTimer = Timer.periodic(Duration(milliseconds: 100), (
      timer,
    ) {
      // mounted 체크 - 위젯이 dispose된 경우 타이머 취소
      if (!mounted) {
        timer.cancel();
        _audioControllerTimer = null;
        return;
      }

      // AudioController의 녹음 상태가 변경되었는지 확인
      final isCurrentlyRecording = _audioController.isRecording;

      if (_wasRecording && !isCurrentlyRecording) {
        timer.cancel();
        _audioControllerTimer = null;

        // AudioRecorderWidget의 _stopRecording 로직 호출
        _handleAudioControllerStopped();
      }
    });
  }

  void _stopAudioControllerListener() {
    _audioControllerTimer?.cancel();
    _audioControllerTimer = null;
  }

  /// AudioController에서 녹음이 중지되었을 때 호출되는 메서드
  Future<void> _handleAudioControllerStopped() async {
    try {
      // mounted 체크 - 위젯이 dispose된 경우 early return
      if (!mounted) {
        return;
      }

      // RecorderController 중지하기 전에 파형 데이터 먼저 추출
      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );

      // RecorderController 중지
      await recorderController.stop();

      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
      } // 녹음된 파일 경로 설정
      _recordedFilePath = _audioController.currentRecordingPath;

      // 재생 컨트롤러 준비
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

      if (widget.isCommentMode && // 댓글 모드인 경우에만
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

      // setState() 호출 전 mounted 체크
      if (!mounted) {
        return;
      }

      // 상태 변경
      setState(() {
        _currentState = RecordingState.recorded;
        _waveformData = waveformData;
      });

      // 콜백 호출
      if (widget.onRecordingCompleted != null) {
        widget.onRecordingCompleted!(_recordedFilePath, waveformData);
      }
    } catch (e) {
      // setState() 호출 전 mounted 체크
      if (mounted) {
        setState(() {
          _currentState = RecordingState.idle;
        });
      }
    }
  }

  /// 🎵 파형 표시 위젯 빌드
  Widget _buildWaveformDisplay() {
    return _waveformData != null && _waveformData!.isNotEmpty
        ? GestureDetector(
          onTap: _onWaveformTapped, // 파형 클릭 시 프로필 모드로 전환
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

  /// 🎵 파형 클릭 시 호출되는 메서드
  void _onWaveformTapped() async {
    // 댓글 모드가 아닌 경우 프로필 모드로 전환하지 않음
    if (!widget.isCommentMode) {
      return;
    }

    // 사용자 프로필 이미지 로드
    await _loadUserProfileImage();

    // mounted 체크 후 상태 변경
    if (mounted) {
      setState(() {
        _isProfileMode = true;
      });
    }
  }

  ///  사용자 프로필 이미지 로드
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

  /// ✅ 마이크 아이콘으로 리셋하는 메서드
  void _resetToMicrophoneIcon() {
    if (mounted) {
      setState(() {
        _currentState = RecordingState.idle;
        _isProfileMode = false;
        _recordedFilePath = null;
        _waveformData = null;
        _userProfileImageUrl = null;
        _lastSavedCommentId = null;
      });
    }
  }

  /// ✅ 외부에서 호출 가능한 public 리셋 메서드
  void resetToMicrophoneIcon() {
    _resetToMicrophoneIcon();
  }

  @override
  void dispose() {
    _stopAudioControllerListener(); // Timer 정리
    recorderController.dispose();
    playerController?.dispose(); // 재생 컨트롤러도 dispose (null 체크)
    super.dispose();
  }
}
