import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:provider/provider.dart';

import '../../../controllers/audio_controller.dart';
import '../../../controllers/comment_record_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/comment_record_model.dart';
import '../../about_archiving/widgets/custom_waveform_widget.dart';

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

  /// 사용자 프로필 이미지 URL
  String? _userProfileImageUrl;

  @override
  void initState() {
    super.initState();

    // 🔍 전달받은 photoId 확인
    debugPrint('🔍 AudioRecorderWidget 초기화 - photoId: ${widget.photoId}');

    // 저장된 댓글이 있으면 프로필 모드로 시작
    if (widget.savedComment != null) {
      _currentState = RecordingState.recorded;
      _isProfileMode = true;
      _userProfileImageUrl = widget.savedComment!.profileImageUrl;
      _recordedFilePath = widget.savedComment!.audioUrl;
      _waveformData = widget.savedComment!.waveformData;
      debugPrint('🎯 저장된 댓글로 프로필 모드 시작 - ID: ${widget.savedComment!.id}');
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
    // 저장된 댓글이 있으면 녹음 시작하지 않음
    if (widget.savedComment != null) {
      debugPrint('❌ 이미 저장된 댓글이 있어 녹음을 시작할 수 없습니다.');
      return;
    }

    // 파형 표시를 위한 녹음 컨트롤러 시작
    try {
      debugPrint(' AudioRecorderWidget._startRecording 시작!!! ');
      debugPrint('녹음 시작 준비...');

      // 파형을 그리는 패키지의 녹음 컨트롤러 시작
      debugPrint('RecorderController 시작...');
      await recorderController.record();
      debugPrint('RecorderController 시작 완료');

      // AudioController의 녹음 시작 함수 호출
      debugPrint(' AudioController 녹음 시작...');
      await _audioController.startRecording();
      debugPrint('AudioController 녹음 시작 완료');
      debugPrint('현재 녹음 경로: ${_audioController.currentRecordingPath}');

      // ✅ 녹음 상태로 변경
      setState(() {
        _currentState = RecordingState.recording;
      });

      // AudioController 상태 감지를 위한 periodic check 시작
      _startAudioControllerListener();

      debugPrint('녹음 시작 완료 - 상태: ${_currentState}');
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
      debugPrint('🌊 녹음 중 수집된 파형 데이터: ${waveformData.length} samples');

      // 파형 데이터 실제 레벨 유지 (정규화 없이) - 절댓값만 적용
      if (waveformData.isNotEmpty) {
        // 절댓값만 적용, 정규화는 하지 않음
        waveformData = waveformData.map((value) => value.abs()).toList();

        // 실제 최대값 확인용 로그
        double maxValue = waveformData.reduce((a, b) => a > b ? a : b);
        debugPrint('📊 파형 실제 최대값: $maxValue (정규화 없이)');
        debugPrint('📈 파형 샘플 (처음 5개): ${waveformData.take(5).toList()}');
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
            debugPrint(
              '📊 RecorderController에서 파형이 비어있음, PlayerController에서 추출 시도',
            );
            final extractedWaveform = await playerController!
                .extractWaveformData(
                  path: _audioController.currentRecordingPath!,
                  noOfSamples: 100,
                );
            if (extractedWaveform.isNotEmpty) {
              waveformData = extractedWaveform;
              debugPrint(
                '✅ PlayerController에서 파형 추출 성공: ${waveformData.length} samples',
              );
            }
          }

          debugPrint('재생 준비 완료: ${_audioController.currentRecordingPath}');
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
        debugPrint('🎯 _stopAndPreparePlayback에서 콜백 함수 호출 중...');
        debugPrint('  - audioPath: ${_audioController.currentRecordingPath}');
        debugPrint('  - waveformData 길이: ${waveformData.length}');
        debugPrint('  - waveformData 샘플: ${waveformData.take(5).toList()}');

        widget.onRecordingCompleted!(
          _audioController.currentRecordingPath,
          waveformData,
        );

        debugPrint('✅ _stopAndPreparePlayback 콜백 함수 호출 완료');
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
      debugPrint('🛑🛑🛑 AudioRecorderWidget._stopRecording 시작!!! 🛑🛑🛑');
      debugPrint('녹음 중지 시작...');

      // 파형 데이터 추출 (원래 잘 작동하는 방식과 동일)
      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );
      debugPrint(
        '🌊 _stopRecording - 수집된 파형 데이터: ${waveformData.length} samples',
      );

      // 파형 데이터 처리 - 절댓값만 적용
      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
        double maxValue = waveformData.reduce((a, b) => a > b ? a : b);
        debugPrint('📊 _stopRecording - 파형 최대값: $maxValue');
        debugPrint(
          '📈 _stopRecording - 파형 샘플 (처음 5개): ${waveformData.take(5).toList()}',
        );
      }

      // 녹음 중지
      final path = await recorderController.stop();
      debugPrint('📁 RecorderController 중지 완료, 경로: $path');

      // AudioController의 간단한 녹음 중지 함수 호출
      await _audioController.stopRecordingSimple();
      debugPrint('✅ AudioController 중지 완료');

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
          debugPrint('재생 컨트롤러 준비 완료: $_recordedFilePath');
        } catch (e) {
          debugPrint('재생 컨트롤러 준비 오류: $e');
        }
      }

      // 🎯 CommentRecord 저장은 _handleAudioControllerStopped에서만 수행
      debugPrint('🔍 CommentRecord 저장은 AudioController 중지 감지 시에만 수행됩니다.');

      // 콜백이 있는 경우 녹음 파일 경로와 파형 데이터 함께 전달
      if (widget.onRecordingCompleted != null) {
        debugPrint('🎯 _stopRecording - 콜백 함수 호출 중...');
        debugPrint('  - audioPath: ${_audioController.currentRecordingPath}');
        debugPrint('  - waveformData 길이: ${waveformData.length}');
        debugPrint('  - waveformData 샘플: ${waveformData.take(5).toList()}');

        widget.onRecordingCompleted!(
          _audioController.currentRecordingPath,
          waveformData,
        );

        debugPrint('✅ _stopRecording - 콜백 함수 호출 완료');
      }

      debugPrint('🎉 _stopRecording - 녹음 중지 및 처리 완료');
    } catch (e) {
      debugPrint('❌ 녹음 중지 오류: $e');
      setState(() {
        _currentState = RecordingState.idle;
      });
    }
  }

  /// ✅ 재생/일시정지 토글 함수
  Future<void> _togglePlayback() async {
    if (playerController == null) return;

    try {
      if (playerController!.playerState.isPlaying) {
        await playerController!.pausePlayer();
        debugPrint('재생 일시정지');
      } else {
        // 재생이 끝났다면 처음부터 다시 시작
        if (playerController!.playerState.isStopped) {
          await playerController!.startPlayer();
          debugPrint('재생 시작 (처음부터)');
        } else {
          await playerController!.startPlayer();
          debugPrint('재생 시작');
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

      debugPrint('녹음 파일 삭제 완료');
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
      debugPrint('🎤 CommentRecord 저장 시작...');

      // AuthController에서 현재 사용자 정보 가져오기
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        debugPrint('❌ 현재 사용자 ID를 찾을 수 없습니다.');
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
      debugPrint('🔍 음성 댓글 저장 시 현재 프로필 위치: $currentProfilePosition');

      final commentRecord = await commentRecordController.createCommentRecord(
        audioFilePath: audioFilePath,
        photoId: widget.photoId!,
        recorderUser: currentUserId,
        waveformData: waveformData,
        duration: duration,
        profileImageUrl: profileImageUrl,
        profilePosition: currentProfilePosition,
      );

      if (commentRecord != null) {
        debugPrint('✅ CommentRecord 저장 성공 - ID: ${commentRecord.id}');

        // 프로필 이미지 URL 설정
        _userProfileImageUrl = profileImageUrl;

        // ✅ mounted 체크 후 저장 성공 시 자동으로 프로필 모드로 전환
        if (mounted) {
          setState(() {
            _isProfileMode = true;
          });
        }

        // 저장 완료 콜백 호출
        if (widget.onCommentSaved != null) {
          widget.onCommentSaved!(commentRecord);
        }
      } else {
        debugPrint('❌ CommentRecord 저장 실패');
      }
    } catch (e) {
      debugPrint('❌ CommentRecord 저장 중 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    //double screenWidth = MediaQuery.of(context).size.width;
    //sdouble screenHeight = MediaQuery.of(context).size.height;

    // ✅ 상태에 따라 다른 UI 표시
    switch (_currentState) {
      case RecordingState.idle:
        // 저장된 댓글이 있으면 녹음 버튼 비활성화
        if (widget.savedComment != null) {
          return Container(
            width: 64,
            height: 64,
            child: Center(
              child: Text(
                '이미 댓글이\n저장됨',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: _startRecording,
          child: Image.asset(
            'assets/record_icon.png',
            width: 64, // 반응형 너비
            height: 64, // 반응형 높이
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
          GestureDetector(
            onTap: _stopRecording,
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
          Expanded(
            child: AudioWaveforms(
              size: Size(
                1,
                (screenHeight * 0.061).clamp(45.0, 65.0), // 반응형 높이
              ),
              recorderController: recorderController,
              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),
          Text(
            duration,
            style: TextStyle(
              color: Colors.white,
              fontSize: (screenWidth * 0.036).clamp(12.0, 16.0), // 반응형 폰트 크기
            ),
          ),
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

  /// ✅ 재생 UI 빌드 (녹음 완료 후) - 프로필 모드일 때 완전히 대체
  Widget _buildPlaybackUI() {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // 🎯 프로필 모드일 때는 전체 UI를 프로필 이미지로 완전히 대체
    if (_isProfileMode) {
      return _buildFullProfileModeUI();
    }

    // 기존 녹음 UI (파형 모드)
    return Container(
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
          // ✅ 쓰레기통 아이콘 (삭제)
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
          // ✅ 재생 파형 (클릭하면 프로필 모드로 전환)
          Expanded(child: _buildWaveformDisplay()),

          // ✅ 재생 시간 표시
          StreamBuilder<int>(
            stream:
                playerController?.onCurrentDurationChanged ??
                const Stream.empty(),
            builder: (context, snapshot) {
              final currentDurationMs = snapshot.data ?? 0;
              final currentDuration = Duration(milliseconds: currentDurationMs);
              final minutes = currentDuration.inMinutes;
              final seconds = currentDuration.inSeconds % 60;
              return Text(
                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (screenWidth * 0.036).clamp(
                    12.0,
                    16.0,
                  ), // 반응형 폰트 크기
                ),
              );
            },
          ),

          // ✅ 재생/일시정지 버튼
          IconButton(
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
                  size: (screenWidth * 0.061).clamp(20.0, 28.0), // 반응형 아이콘 크기
                );
              },
            ),
          ),

          SizedBox(width: (screenWidth * 0.061).clamp(20.0, 28.0)), // 반응형 간격
        ],
      ),
    );
  }

  /// 🎯 프로필 모드 UI - 전체 녹음 UI를 프로필 이미지로 완전히 대체 (feed 스타일)
  Widget _buildFullProfileModeUI() {
    double screenWidth = MediaQuery.of(context).size.width;
    //double screenHeight = MediaQuery.of(context).size.height;

    final profileWidget = Container(
      width: 27,
      height: 27,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
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
      data: 'profile_image',
      onDragStarted: () {
        debugPrint('🚀 AudioRecorderWidget에서 드래그 시작됨');
      },
      feedback: Transform.scale(
        scale: 1.2, // 드래그 중에는 조금 더 크게
        child: Opacity(opacity: 0.8, child: profileWidget),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3, // 드래그 중에는 원본을 투명하게
        child: profileWidget,
      ),
      onDragEnd: (details) {
        // 드래그가 끝났을 때 위치 정보 처리
        debugPrint(
          '🏁 AudioRecorderWidget에서 드래그 종료 - 위치: ${details.offset}, 성공: ${details.wasAccepted}',
        );
        if (details.wasAccepted) {
          debugPrint('✅ 드래그가 성공적으로 DragTarget에 접수됨');
        } else {
          debugPrint('❌ 드래그가 DragTarget에 접수되지 않음');
        }

        // 외부 콜백이 있으면 호출, 없으면 내부 처리
        if (widget.onProfileImageDragged != null) {
          widget.onProfileImageDragged!(details.offset);
        } else {
          _onProfileImageDragged(details.offset);
        }
      },
      child: GestureDetector(
        onTap: _onProfileImageTapped, // 클릭하면 다시 파형 모드로 전환
        child: profileWidget,
      ),
    );
  }

  /// 🖼️ 프로필 이미지 드래그 처리
  void _onProfileImageDragged(Offset globalPosition) {
    debugPrint('[DRAG] 프로필 이미지 드래그됨 - 위치: $globalPosition');

    // 위치 업데이트는 DragTarget(PhotoDetailScreen)에서만 처리
    // 여기서는 드래그 이벤트만 로깅
    debugPrint('[DRAG] 드래그 완료 - 위치 업데이트는 DragTarget에서 처리됩니다.');
  }

  /// AudioController 상태 감지를 위한 리스너
  Timer? _audioControllerTimer;
  bool _wasRecording = true;

  void _startAudioControllerListener() {
    _wasRecording = true;
    _audioControllerTimer = Timer.periodic(Duration(milliseconds: 100), (
      timer,
    ) {
      // ✅ mounted 체크 - 위젯이 dispose된 경우 타이머 취소
      if (!mounted) {
        timer.cancel();
        _audioControllerTimer = null;
        return;
      }

      // AudioController의 녹음 상태가 변경되었는지 확인
      final isCurrentlyRecording = _audioController.isRecording;

      if (_wasRecording && !isCurrentlyRecording) {
        debugPrint('🔔 AudioController 녹음 완료 감지!');
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
    debugPrint('🛑🛑🛑 AudioController 중지 감지 - 저장 로직 시작!!! 🛑🛑🛑');

    try {
      // ✅ mounted 체크 - 위젯이 dispose된 경우 early return
      if (!mounted) {
        debugPrint('⚠️ 위젯이 이미 dispose됨 - AudioController 중지 처리 취소');
        return;
      }

      // ✅ RecorderController 중지하기 전에 파형 데이터 먼저 추출
      List<double> waveformData = List<double>.from(
        recorderController.waveData,
      );
      debugPrint('🌊 중지 전 수집된 파형 데이터: ${waveformData.length} samples');

      // RecorderController 중지
      await recorderController.stop();
      debugPrint('📊 RecorderController 중지 완료');

      if (waveformData.isNotEmpty) {
        waveformData = waveformData.map((value) => value.abs()).toList();
        debugPrint('🔧 파형 데이터 처리 완료: ${waveformData.length} samples');
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

      // 🎯 CommentRecord 저장 (댓글 모드이고 photoId가 있는 경우에만)
      debugPrint('🔍 CommentRecord 저장 조건 체크:');
      debugPrint('  - widget.isCommentMode: ${widget.isCommentMode}');
      debugPrint('  - widget.photoId: ${widget.photoId}');
      debugPrint('  - _recordedFilePath: $_recordedFilePath');
      debugPrint('  - waveformData.isNotEmpty: ${waveformData.isNotEmpty}');
      debugPrint('  - waveformData.length: ${waveformData.length}');

      if (widget.isCommentMode && // ✅ 댓글 모드인 경우에만
          widget.photoId != null &&
          _recordedFilePath != null &&
          _recordedFilePath!.isNotEmpty &&
          waveformData.isNotEmpty) {
        debugPrint('✅ 모든 조건 충족 - CommentRecord 저장 시작...');
        await _saveCommentRecord(
          audioFilePath: _recordedFilePath!,
          waveformData: waveformData,
          duration: _audioController.recordingDuration,
        );
        debugPrint('✅ CommentRecord 저장 완료!');
      } else {
        debugPrint('❌ CommentRecord 저장 조건 불충족');
        if (!widget.isCommentMode) debugPrint('  - 사진 편집 모드 (댓글 저장 안함)');
        if (widget.photoId == null) debugPrint('  - photoId가 null');
        if (_recordedFilePath == null || _recordedFilePath!.isEmpty) {
          debugPrint('  - recordedFilePath 문제');
        }
        if (waveformData.isEmpty) debugPrint('  - waveformData 비어있음');
      }

      // ✅ setState() 호출 전 mounted 체크
      if (!mounted) {
        debugPrint('⚠️ 위젯이 dispose됨 - setState() 호출 취소');
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

      debugPrint('🎉 AudioController 중지 처리 완료');
    } catch (e) {
      debugPrint('❌ AudioController 중지 처리 오류: $e');

      // ✅ setState() 호출 전 mounted 체크
      if (mounted) {
        setState(() {
          _currentState = RecordingState.idle;
        });
      }
    }
  }

  /// 🎵 파형 표시 위젯 빌드
  Widget _buildWaveformDisplay() {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

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

              return Container(
                height: (screenHeight * 0.023).clamp(18.0, 25.0),
                padding: EdgeInsets.symmetric(
                  horizontal: (screenWidth * 0.02).clamp(6.0, 10.0),
                  vertical: (screenHeight * 0.006).clamp(4.0, 7.0),
                ),
                child: CustomWaveformWidget(
                  waveformData: _waveformData!,
                  color: Colors.grey,
                  activeColor: Colors.white,
                  progress: progress,
                ),
              );
            },
          ),
        )
        : GestureDetector(
          onTap: _onWaveformTapped,
          child: Container(
            height: (screenHeight * 0.061).clamp(45.0, 65.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(
                (screenWidth * 0.02).clamp(6.0, 10.0),
              ),
            ),
            child: Center(
              child: Text(
                '파형 없음',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: (screenWidth * 0.031).clamp(10.0, 14.0),
                ),
              ),
            ),
          ),
        );
  }

  /// 🎵 파형 클릭 시 호출되는 메서드
  void _onWaveformTapped() async {
    debugPrint('🎵 파형 클릭됨 - 프로필 모드로 전환');

    // ✅ 댓글 모드가 아닌 경우 프로필 모드로 전환하지 않음
    if (!widget.isCommentMode) {
      debugPrint('📸 사진 편집 모드 - 프로필 모드 전환 비활성화');
      return;
    }

    // 사용자 프로필 이미지 로드
    await _loadUserProfileImage();

    // ✅ mounted 체크 후 상태 변경
    if (mounted) {
      setState(() {
        _isProfileMode = true;
      });
    }
  }

  /// 👤 프로필 이미지 클릭 시 호출되는 메서드
  void _onProfileImageTapped() async {
    debugPrint('👤 프로필 이미지 클릭됨');

    // 저장된 댓글의 오디오 URL이 있으면 재생
    if (widget.savedComment != null &&
        widget.savedComment!.audioUrl.isNotEmpty) {
      debugPrint('🎵 저장된 음성 댓글 재생 시작: ${widget.savedComment!.audioUrl}');

      try {
        // AudioController를 사용하여 음성 재생
        await _audioController.toggleAudio(widget.savedComment!.audioUrl);
        debugPrint('✅ 음성 재생 시작됨');
      } catch (e) {
        debugPrint('❌ 음성 재생 실패: $e');
      }
    } else if (_recordedFilePath != null && _recordedFilePath!.isNotEmpty) {
      // 현재 녹음된 파일이 있으면 재생
      debugPrint('🎵 현재 녹음 파일 재생: $_recordedFilePath');

      try {
        await _audioController.toggleAudio(_recordedFilePath!);
        debugPrint('✅ 현재 녹음 파일 재생 시작됨');
      } catch (e) {
        debugPrint('❌ 현재 녹음 파일 재생 실패: $e');
      }
    } else {
      debugPrint('🔄 재생할 음성이 없어 파형 모드로 전환');
      // ✅ mounted 체크 후 상태 변경
      if (mounted) {
        setState(() {
          _isProfileMode = false;
        });
      }
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

        debugPrint('✅ 프로필 이미지 로드 완료: $profileImageUrl');
      }
    } catch (e) {
      debugPrint('❌ 프로필 이미지 로드 실패: $e');
    }
  }

  @override
  void dispose() {
    _stopAudioControllerListener(); // Timer 정리
    recorderController.dispose();
    playerController?.dispose(); // ✅ 재생 컨트롤러도 dispose (null 체크)
    super.dispose();
  }
}
