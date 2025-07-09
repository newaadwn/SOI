import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../models/audio_model.dart';
//import 'package:flutter_swift_camera/services/audio_converter_service.dart';

/// 오디오 녹음/재생 기능을 위한 Controller 클래스
/// View와 Model 사이의 중개 역할을 합니다.
class AudioController extends ChangeNotifier {
  // 상태 변수
  bool _isRecording = false; // 녹음 중인지 여부
  bool _isPlaying = false; // 재생 중인지 여부
  String? _audioFilePath; // 임시로 저장된 녹음 파일의 경로
  Timer? _recordingTimer; // 녹음 시간 측정용 타이머
  int _recordingDuration = 0; // 녹음 시간(초)
  StreamSubscription<RecordingDisposition>? _recordingLevelSubscription;
  double _recordingLevel = 0.0;
  FlutterSoundPlayer? _player;

  // AudioModel 인스턴스
  final AudioModel _audioModel = AudioModel();

  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get audioFilePath => _audioFilePath;
  int get recordingDuration => _recordingDuration;
  double get recordingLevel => _recordingLevel;

  /// 녹음 시간을 MM:SS 형식으로 포맷팅하여 반환
  String get formattedRecordingDuration {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// 초기화 함수
  Future<void> initialize() async {
    await _audioModel.openRecorder();
  }

  /// 녹음 시작
  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      _audioFilePath = await _audioModel.startRecording();
      if (_audioFilePath != null) {
        _isRecording = true;
        _recordingDuration = 0;

        // 녹음 레벨 모니터링 시작
        _recordingLevelSubscription = _audioModel.startRecordingLevelMonitoring(
          (level) {
            _recordingLevel = level;
            notifyListeners();
          },
        );

        // 타이머 시작
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _recordingDuration++;
          notifyListeners();
        });

        notifyListeners();
      }
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
    }
  }

  /// 녹음 중지
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      // 타이머 취소
      _recordingTimer?.cancel();
      _recordingTimer = null;

      // 레벨 모니터링 취소
      _recordingLevelSubscription?.cancel();
      _recordingLevelSubscription = null;

      // 녹음 중지 및 파일 경로 받기
      final path = await _audioModel.stopRecording();
      _isRecording = false;
      _audioFilePath = path;
      notifyListeners();
      return path;
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
      _isRecording = false;
      notifyListeners();
      return null;
    }
  }

  /// 녹음된 오디오 재생
  Future<void> playRecordedAudio() async {
    if (_isPlaying || _audioFilePath == null) return;

    try {
      _player = await _audioModel.playRecordedAudio(_audioFilePath);
      if (_player != null) {
        _isPlaying = true;
        notifyListeners();

        // 재생이 끝나면 상태 업데이트
        _player!.onProgress!.listen((event) {
          // 재생 진행 상태 업데이트 가능
        });

        // 재생 완료 시 호출될 콜백
        Future.delayed(const Duration(seconds: 2), () {
          if (_isPlaying) {
            _isPlaying = false;
            notifyListeners();
          }
        });
      }
    } catch (e) {
      debugPrint('오디오 재생 오류: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// 오디오 재생 중지
  void stopPlaying() {
    if (_player != null) {
      _player!.stopPlayer();
      _player = null;
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// 녹음된 파일을 Firebase Storage에 업로드
  Future<String?> uploadAudioToFirestorage() async {
    try {
      final downloadUrl = await _audioModel.uploadAudioToFirestorage(
        _audioFilePath,
      );
      return downloadUrl;
    } catch (e) {
      debugPrint('오디오 파일 업로드 오류: $e');
      return null;
    }
  }

  /// 오디오 프로세싱 및 업로드를 위한 메서드
  /// 녹음된 오디오를 처리하고 Firebase Storage에 업로드한 후 URL 반환
  Future<String> processAudioForUpload() async {
    try {
      if (_audioFilePath == null) {
        // 녹음된 파일이 없는 경우 빈 문자열 반환
        return '';
      }

      // Firebase Storage에 업로드
      final downloadUrl = await _audioModel.uploadAudioToFirestorage(
        _audioFilePath,
      );

      return downloadUrl ?? '';
    } catch (e) {
      debugPrint('오디오 처리 및 업로드 오류: $e');
      return '';
    }
  }

  /// 녹음된 임시 파일 삭제
  Future<void> deleteRecordedAudio() async {
    if (_audioFilePath != null) {
      await _audioModel.deleteRecordedAudio(_audioFilePath);
      _audioFilePath = null;
      notifyListeners();
    }
  }

  /// 리소스 해제
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recordingLevelSubscription?.cancel();
    _player?.closePlayer();
    _audioModel.closeRecorder();
    super.dispose();
  }
}
