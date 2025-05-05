import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:flutter_swift_camera/services/audio_converter_service.dart';

/// 오디오 녹음/업로드 로직을 담당하는 ViewModel
class AudioViewModel extends ChangeNotifier {
  FlutterSoundRecorder? _recorder; // 녹음기 인스턴스
  bool _isRecording = false; // 녹음 중인지 여부
  String? _audioFilePath; // 녹음된 파일 경로
  bool _isProcessingAudio = false; // 오디오 처리(업로드 등) 상태

  // 실시간 audio 레벨을 위한 스트림 컨트롤러
  final StreamController<double> _dbLevelController =
      StreamController<double>.broadcast();
  StreamSubscription<RecordingDisposition>? _recorderSubscription;

  /// 실시간 오디오 레벨 스트림 (데시벨)
  Stream<double> get dbLevelStream => _dbLevelController.stream;

  // 녹음 시간 추적
  Duration _recordingDuration = Duration.zero;
  Duration get recordingDuration => _recordingDuration;

  /// Getter: 녹음 중인지 여부
  bool get isRecording => _isRecording;

  /// Getter: 오디오 파일 경로
  String? get audioFilePath => _audioFilePath;

  /// Getter: 오디오 처리중 여부
  bool get isProcessingAudio => _isProcessingAudio;

  // 녹음 시간 문자열 포맷 (예: 00:05, 01:23)
  String get formattedRecordingDuration {
    final minutes = _recordingDuration.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _recordingDuration.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // 생성자
  AudioViewModel() {
    _recorder = FlutterSoundRecorder();
    _openRecorder();
  }

  /// 마이크 권한 요청 및 레코더 세션 열기
  Future<void> _openRecorder() async {
    await Permission.microphone.request(); // 마이크 권한 요청
    await _recorder?.openRecorder(); // 오디오 세션 열기
  }

  // 녹음 경로를 저장할 변수 추가
  String? _recordingPath;

  /// 녹음 시작
  Future<void> startRecording() async {
    try {
      // 임시 디렉토리에 파일 경로 생성
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

      debugPrint('녹음 경로 설정: $_recordingPath');

      // 녹음 시작 전 녹음 시간 초기화
      _recordingDuration = Duration.zero;

      // 녹음 시작
      await _recorder?.startRecorder(toFile: _recordingPath);

      // 오디오 레벨 업데이트 구독 설정 (50ms 간격)
      _recorder?.setSubscriptionDuration(const Duration(milliseconds: 50));
      _recorderSubscription = _recorder?.onProgress?.listen((event) {
        // 데시벨 값을 스트림에 추가
        _dbLevelController.add(event.decibels ?? 0.0);

        // 녹음 시간 업데이트
        _recordingDuration = event.duration;
        notifyListeners();
      });

      _isRecording = true;
      notifyListeners(); // 녹음 상태 변경 알림
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
      _isRecording = false;
      notifyListeners();
    }
  }

  /// 녹음 중지
  Future<void> stopRecording() async {
    if (!_isRecording) {
      debugPrint('녹음 중이 아닙니다.');
      return;
    }

    try {
      // 레벨 업데이트 구독 해제
      await _recorderSubscription?.cancel();

      // 녹음 중지
      final String? path = await _recorder?.stopRecorder();
      _isRecording = false;

      // iOS에서 가끔 path가 비어있는 문제 해결
      if (path != null && path.isNotEmpty) {
        _audioFilePath = path;
        debugPrint('녹음 중지 성공 - 경로: $path');
      } else if (_recordingPath != null) {
        // iOS에서 path가 null이나 비어있으면 시작 시 저장한 경로 사용
        _audioFilePath = _recordingPath;
        debugPrint('녹음 중지 - 미리 저장해둔 경로 사용: $_recordingPath');
      } else {
        debugPrint('경고: 녹음 파일 경로를 찾을 수 없습니다.');
      }

      // 경로 확인
      if (_audioFilePath != null) {
        final file = File(_audioFilePath!);
        final exists = await file.exists();
        debugPrint('파일 존재 여부: $exists (${_audioFilePath})');

        if (!exists) {
          debugPrint('경고: 파일이 존재하지 않습니다: $_audioFilePath');
        }
      }

      notifyListeners(); // 녹음 상태 변경 알림
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
      _isRecording = false;
      notifyListeners();
    }
  }

  /// 녹음 파일을 AAC로 변환 (더 나은 호환성)
  /*Future<String> _convertToAAC(String inputFilePath) async {
    // 네이티브 코드를 사용하여 오디오 변환
    return await AudioConverterService.convertToAAC(inputFilePath);
  }*/

  /// 녹음 파일을 Firebase Storage에 업로드 후 다운로드 URL 반환
  Future<String> uploadAudioToFirestorage() async {
    if (_audioFilePath == null) {
      throw Exception('No audio file to upload');
    }

    _isProcessingAudio = true;
    notifyListeners();

    try {
      // 파일 존재 여부 확인
      final file = File(_audioFilePath!);
      if (!await file.exists()) {
        debugPrint('오디오 파일이 존재하지 않습니다: $_audioFilePath');
        throw Exception('Audio file does not exist: $_audioFilePath');
      }

      // 확인: 파일이 실제로 읽을 수 있는지 확인
      try {
        await file.readAsBytes();
      } catch (e) {
        debugPrint('오디오 파일을 읽을 수 없습니다: $e');
        throw Exception('Cannot read audio file: $e');
      }

      // Firebase Storage에 업로드 (확장자는 m4a로 변경)
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance.ref().child(
        'categories_audio/$fileName',
      );

      await ref.putFile(file);
      final String downloadUrl = await ref.getDownloadURL();

      debugPrint('오디오 업로드 성공: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('오디오 업로드 오류: $e');
      rethrow; // 호출자에게 예외를 전달
    } finally {
      _isProcessingAudio = false;
      notifyListeners();
    }
  }

  /// 오디오 업로드 후 로컬 파일 경로 초기화
  void clearAudioFilePath() {
    _audioFilePath = null;
    notifyListeners();
  }

  /// 사진과 함께 오디오 업로드를 처리하는 메서드
  ///
  /// 오디오가 있는 경우에만 업로드하고 URL을 반환합니다.
  /// 오디오가 없는 경우 빈 문자열을 반환합니다.
  Future<String> processAudioForUpload() async {
    String audioUrl = '';
    
    // 오디오 파일 존재 여부 먼저 확인
    if (_audioFilePath != null) {
      try {
        final file = File(_audioFilePath!);
        final exists = await file.exists();
        
        if (!exists) {
          debugPrint('오디오 업로드 건너뜀 - 파일이 존재하지 않음: $_audioFilePath');
          return '';
        }
        
        // 파일이 0바이트인지 확인
        final fileSize = await file.length();
        if (fileSize == 0) {
          debugPrint('오디오 업로드 건너뜀 - 파일 크기가 0입니다: $_audioFilePath');
          return '';
        }
        
        // 모든 검증 통과하면 업로드 진행
        audioUrl = await uploadAudioToFirestorage();
        debugPrint('오디오 업로드 완료: $audioUrl');
      } catch (e) {
        debugPrint('오디오 업로드 오류: $e');
        // 오류가 발생해도 앱이 계속 실행되도록 빈 문자열 반환
        return '';
      }
    } else {
      debugPrint('오디오 파일 경로가 없어 업로드를 건너뜁니다');
    }
    
    return audioUrl;
  }

  /// 녹음된 오디오 재생
  Future<void> playRecordedAudio() async {
    if (_audioFilePath == null) {
      throw Exception('No audio file to play');
    }

    FlutterSoundPlayer player = FlutterSoundPlayer();
    await player.openPlayer();

    // 오디오 파일 재생
    await player.startPlayer(
      fromURI: _audioFilePath,
      whenFinished: () {
        player.closePlayer();
      },
    );
  }

  /// 오디오 파일 삭제
  Future<void> deleteRecordedAudio() async {
    if (_audioFilePath != null) {
      try {
        final file = File(_audioFilePath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Audio file deleted: $_audioFilePath');
        }
      } catch (e) {
        debugPrint('Failed to delete audio file: $e');
      }
      _audioFilePath = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // 구독 및 컨트롤러 해제
    _recorderSubscription?.cancel();
    _dbLevelController.close();
    _recorder?.closeRecorder();
    _recorder = null;
    super.dispose();
  }
}
