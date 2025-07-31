import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:provider/provider.dart';

import '../../../controllers/audio_controller.dart';
import '../../about_archiving/widgets/custom_waveform_widget.dart';

/// 음성 댓글 전용 위젯
///
/// 피드 화면에서 음성 댓글을 녹음하고 재생하는 기능을 제공합니다.
/// AudioRecorderWidget보다 단순하고 음성 댓글에 최적화되어 있습니다.

enum VoiceCommentState {
  idle, // 초기 상태 (녹음 버튼 표시)
  recording, // 녹음 중
  recorded, // 녹음 완료 (재생 가능)
  saved, // 저장 완료 (프로필 이미지 표시)
}

class VoiceCommentWidget extends StatefulWidget {
  final bool autoStart; // 자동 녹음 시작 여부
  final Function(String?, List<double>?, int?)?
  onRecordingCompleted; // 녹음 완료 콜백 (duration 추가)
  final VoidCallback? onRecordingDeleted; // 녹음 삭제 콜백
  final VoidCallback? onSaved; // 저장 완료 콜백 추가
  final String? profileImageUrl; // 프로필 이미지 URL 추가
  final bool startAsSaved; // 저장된 상태로 시작할지 여부
  final Function(Offset)? onProfileImageDragged; // 프로필 이미지 드래그 콜백

  const VoiceCommentWidget({
    super.key,
    this.autoStart = false,
    this.onRecordingCompleted,
    this.onRecordingDeleted,
    this.onSaved,
    this.profileImageUrl, // 프로필 이미지 URL 추가
    this.startAsSaved = false, // 기본값은 false
    this.onProfileImageDragged, // 드래그 콜백 추가
  });

  @override
  State<VoiceCommentWidget> createState() => _VoiceCommentWidgetState();
}

class _VoiceCommentWidgetState extends State<VoiceCommentWidget> {
  late AudioController _audioController;
  late RecorderController _recorderController;
  PlayerController? _playerController;

  VoiceCommentState _currentState = VoiceCommentState.idle;
  List<double>? _waveformData;
  DateTime? _recordingStartTime; // 녹음 시작 시간 추가

  /// 외부에서 저장 완료를 알리는 메서드
  void markAsSaved() {
    if (mounted) {
      _markAsSaved();
    }
  }

  @override
  void initState() {
    super.initState();

    // 저장된 상태로 시작해야 하는 경우
    if (widget.startAsSaved) {
      _currentState = VoiceCommentState.saved;
      // debugPrint('🖼️ VoiceCommentWidget이 저장된 상태로 시작됨');
      return; // 컨트롤러 초기화 없이 리턴
    }

    _initializeControllers();

    // autoStart는 saved 상태가 아닐 때만 적용
    if (widget.autoStart && _currentState != VoiceCommentState.saved) {
      _currentState = VoiceCommentState.recording;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });
    }
  }

  void _initializeControllers() {
    _audioController = Provider.of<AudioController>(context, listen: false);

    _recorderController =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 44100;

    _playerController = PlayerController();
    // debugPrint('🎛️ 음성 댓글 컨트롤러 초기화 완료');
  }

  @override
  void dispose() {
    // 저장된 상태가 아닌 경우에만 컨트롤러 해제
    if (_currentState != VoiceCommentState.saved) {
      _recorderController.dispose();
      _playerController?.dispose();
    }
    super.dispose();
  }

  /// 녹음 시작
  Future<void> _startRecording() async {
    try {
      // debugPrint('🎤 음성 댓글 녹음 시작');

      // 녹음 시작 시간 기록
      _recordingStartTime = DateTime.now();

      await _recorderController.record();
      await _audioController.startRecording();

      setState(() {
        _currentState = VoiceCommentState.recording;
      });

      // debugPrint('✅ 음성 댓글 녹음 시작 완료');
    } catch (e) {
      // debugPrint('❌ 녹음 시작 오류: $e');
      setState(() {
        _currentState = VoiceCommentState.idle;
      });
    }
  }

  /// 녹음 중지 및 재생 준비
  Future<void> _stopAndPreparePlayback() async {
    try {
      // debugPrint('🛑 음성 댓글 녹음 중지');

      // 파형 데이터 추출
      List<double> waveformData = List<double>.from(
        _recorderController.waveData,
      );
      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
      }

      // 녹음 중지
      await _recorderController.stop();
      await _audioController.stopRecordingSimple();

      final filePath = _audioController.currentRecordingPath;
      if (filePath != null && filePath.isNotEmpty) {
        // 녹음 시간 계산
        final recordingDuration =
            _recordingStartTime != null
                ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
                : 0;

        // 재생 준비
        await _playerController?.preparePlayer(
          path: filePath,
          shouldExtractWaveform: true,
        );

        setState(() {
          _currentState = VoiceCommentState.recorded;
          _waveformData = waveformData;
        });

        // 콜백 호출 (duration 포함)
        widget.onRecordingCompleted?.call(
          filePath,
          waveformData,
          recordingDuration,
        );

        // debugPrint('✅ 음성 댓글 녹음 완료: $filePath, 시간: ${recordingDuration}ms');
      }
    } catch (e) {
      // debugPrint('❌ 녹음 중지 오류: $e');
    }
  }

  /// 녹음 취소 (쓰레기통 클릭)
  void _deleteRecording() {
    try {
      // 재생 중이면 중지
      if (_playerController?.playerState.isPlaying == true) {
        _playerController?.stopPlayer();
      }

      // 상태 초기화
      setState(() {
        _currentState = VoiceCommentState.idle;
        _waveformData = null;
      });

      // 삭제 콜백 호출
      widget.onRecordingDeleted?.call();

      // debugPrint('음성 댓글 녹음 삭제 완료');
    } catch (e) {
      // debugPrint('녹음 삭제 오류: $e');
    }
  }

  /// 재생/일시정지 토글
  Future<void> _togglePlayback() async {
    try {
      if (_playerController?.playerState.isPlaying == true) {
        await _playerController!.pausePlayer();
        // debugPrint('재생 일시정지');
      } else {
        // 재생이 끝났다면 처음부터 다시 시작
        if (_playerController!.playerState.isStopped) {
          await _playerController!.startPlayer();
          // debugPrint('재생 시작 (처음부터)');
        } else {
          await _playerController!.startPlayer();
          // debugPrint('재생 시작');
        }
      }
      setState(() {}); // UI 갱신
    } catch (e) {
      // debugPrint('재생/일시정지 오류: $e');
    }
  }

  /// 녹음 중 UI (AudioRecorderWidget과 동일)
  Widget _buildRecordingUI(String duration) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: (screenWidth * 0.956).clamp(300.0, 400.0), // 반응형 너비
      height: (screenHeight * 0.061).clamp(45.0, 65.0), // 반응형 높이
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1c),
        borderRadius: BorderRadius.circular(
          (screenWidth * 0.037).clamp(12.0, 18.0),
        ), // 반응형 반지름
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(width: (screenWidth * 0.036).clamp(10.0, 18.0)), // 반응형 간격
          // 쓰레기통 아이콘 (녹음 취소)
          GestureDetector(
            onTap: _deleteRecording,
            child: Container(
              width: (screenWidth * 0.081).clamp(28.0, 36.0), // 반응형 너비
              height: (screenWidth * 0.081).clamp(28.0, 36.0), // 반응형 높이
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/trash.png',
                width: (screenWidth * 0.081).clamp(28.0, 36.0), // 반응형 너비
                height: (screenWidth * 0.081).clamp(28.0, 36.0), // 반응형 높이
              ),
            ),
          ),
          SizedBox(width: (screenWidth * 0.05).clamp(15.0, 25.0)), // 반응형 간격
          // 실시간 파형
          Expanded(
            child: AudioWaveforms(
              size: Size(
                1,
                (screenHeight * 0.061).clamp(45.0, 65.0), // 반응형 높이
              ),
              recorderController: _recorderController,
              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),
          // 녹음 시간
          Text(
            duration,
            style: TextStyle(
              color: Colors.white,
              fontSize: (screenWidth * 0.036).clamp(12.0, 16.0), // 반응형 폰트 크기
            ),
          ),
          // 중지 버튼
          IconButton(
            onPressed: () {
              _stopAndPreparePlayback();
            },
            icon: Icon(
              Icons.stop,
              color: Colors.white,
              size: (screenWidth * 0.061).clamp(20.0, 28.0), // 반응형 아이콘 크기
            ),
          ),
          SizedBox(width: (screenWidth * 0.061).clamp(20.0, 28.0)), // 반응형 간격
        ],
      ),
    );
  }

  /// 재생 UI (AudioRecorderWidget과 동일)
  Widget _buildPlaybackUI() {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () {
        // 쓰레기통과 재생 버튼 영역을 제외한 부분 클릭 시 저장 완료 상태로 변경
        _markAsSaved();
      },
      child: Container(
        width: (screenWidth * 0.956).clamp(300.0, 400.0), // 반응형 너비
        height: (screenHeight * 0.061).clamp(45.0, 65.0), // 반응형 높이
        decoration: BoxDecoration(
          color: const Color(0xff1c1c1c), // 회색 배경
          borderRadius: BorderRadius.circular(
            (screenWidth * 0.037).clamp(12.0, 18.0),
          ), // 반응형 반지름
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(width: (screenWidth * 0.036).clamp(10.0, 18.0)), // 반응형 간격
            // 쓰레기통 아이콘 (삭제)
            GestureDetector(
              onTap: _deleteRecording,
              child: Container(
                width: (screenWidth * 0.081).clamp(28.0, 36.0), // 반응형 너비
                height: (screenWidth * 0.081).clamp(28.0, 36.0), // 반응형 높이
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/trash.png',
                  width: (screenWidth * 0.081).clamp(28.0, 36.0), // 반응형 너비
                  height: (screenWidth * 0.081).clamp(28.0, 36.0), // 반응형 높이
                ),
              ),
            ),
            SizedBox(width: (screenWidth * 0.05).clamp(15.0, 25.0)), // 반응형 간격
            // 재생 파형 (회색 배경에 흰색으로 채워짐)
            Expanded(
              child:
                  _waveformData != null && _waveformData!.isNotEmpty
                      ? StreamBuilder<int>(
                        stream:
                            _playerController?.onCurrentDurationChanged ??
                            const Stream.empty(),
                        builder: (context, positionSnapshot) {
                          final currentPosition = positionSnapshot.data ?? 0;
                          // maxDuration을 사용하여 총 길이 가져오기
                          final totalDuration =
                              _playerController?.maxDuration ?? 1;
                          final progress =
                              totalDuration > 0
                                  ? (currentPosition / totalDuration).clamp(
                                    0.0,
                                    1.0,
                                  )
                                  : 0.0;

                          return Container(
                            height: (screenHeight * 0.023).clamp(16.0, 24.0),
                            alignment: Alignment.center,
                            child: CustomWaveformWidget(
                              waveformData: _waveformData!,
                              color: const Color(0xff5a5a5a),
                              activeColor: Colors.white,
                              progress: progress,
                            ),
                          );
                        },
                      )
                      : Container(
                        height: (screenHeight * 0.023).clamp(16.0, 24.0),
                        alignment: Alignment.center,
                        child: Text(
                          '파형 없음',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: (screenWidth * 0.028).clamp(10.0, 14.0),
                          ),
                        ),
                      ),
            ),
            SizedBox(width: (screenWidth * 0.025).clamp(8.0, 12.0)), // 반응형 간격
            // 재생/일시정지 버튼
            StreamBuilder<PlayerState>(
              stream:
                  _playerController?.onPlayerStateChanged ??
                  const Stream.empty(),
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final isPlaying = playerState?.isPlaying ?? false;

                return GestureDetector(
                  onTap: _togglePlayback,
                  child: Container(
                    width: (screenWidth * 0.081).clamp(28.0, 36.0),
                    height: (screenWidth * 0.081).clamp(28.0, 36.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: (screenWidth * 0.051).clamp(18.0, 24.0),
                    ),
                  ),
                );
              },
            ),
            SizedBox(width: (screenWidth * 0.036).clamp(10.0, 18.0)), // 반응형 간격
          ],
        ),
      ),
    );
  }

  /// 저장 완료 상태로 변경
  void _markAsSaved() {
    // debugPrint(' 음성 댓글 상태 변경: ${_currentState.toString()} → saved');

    // 컨트롤러들을 완전히 정리하고 초기화
    _cleanupControllers();

    setState(() {
      _currentState = VoiceCommentState.saved;
      _waveformData = null; // 파형 데이터 정리
    });

    // 저장 완료 콜백 호출
    widget.onSaved?.call();

    // debugPrint('✅ 음성 댓글이 저장 완료 상태로 변경됨 - 컨트롤러 정리 완료');
  }

  /// 컨트롤러들을 정리하는 메서드
  void _cleanupControllers() {
    try {
      // 재생 중이면 중지
      if (_playerController?.playerState.isPlaying == true) {
        _playerController?.stopPlayer();
      }

      // 녹음 중이면 중지
      if (_recorderController.isRecording) {
        _recorderController.stop();
      }

      // 컨트롤러들 해제
      _playerController?.dispose();
      _playerController = null;

      // debugPrint('🧹 컨트롤러 정리 완료');
    } catch (e) {
      // debugPrint('❌ 컨트롤러 정리 중 오류: $e');
    }
  }

  /// 저장된 프로필 이미지 UI
  Widget _buildSavedProfileUI() {
    // debugPrint('🖼️ 저장된 프로필 이미지 UI 빌드 중: ${widget.profileImageUrl}');

    final profileWidget = Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child:
          widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty
              ? ClipOval(
                child: Image.network(
                  widget.profileImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person, color: Colors.white, size: 14),
                    );
                  },
                ),
              )
              : Container(
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person, color: Colors.white, size: 14),
              ),
    );

    // 드래그 기능이 있는 경우 Draggable로 감싸기
    if (widget.onProfileImageDragged != null) {
      return Draggable<String>(
        data: 'profile_image',
        feedback: Transform.scale(
          scale: 1.2, // 드래그 중에는 조금 더 크게
          child: Opacity(opacity: 0.8, child: profileWidget),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3, // 드래그 중에는 원본을 투명하게
          child: profileWidget,
        ),
        onDragEnd: (details) {
          // 드래그가 끝났을 때 위치 정보 전달
          widget.onProfileImageDragged?.call(details.offset);
        },
        child: profileWidget,
      );
    }

    return profileWidget;
  }

  @override
  Widget build(BuildContext context) {
    // 상태에 따라 다른 UI 표시
    switch (_currentState) {
      case VoiceCommentState.idle:
        // comment.png 표시 (기존 feed_home.dart에서 처리)
        return const SizedBox.shrink();

      case VoiceCommentState.recording:
        return Selector<AudioController, String>(
          selector:
              (context, controller) => controller.formattedRecordingDuration,
          builder: (context, duration, child) {
            return _buildRecordingUI(duration);
          },
        );

      case VoiceCommentState.recorded:
        return _buildPlaybackUI();

      case VoiceCommentState.saved:
        return _buildSavedProfileUI();
    }
  }
}
