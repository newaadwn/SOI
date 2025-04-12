import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_swift_camera/services/audio_converter_service.dart';

/// 오디오 녹음/업로드 로직을 담당하는 ViewModel
class AudioViewModel extends ChangeNotifier {
  FlutterSoundRecorder? _recorder; // 녹음기 인스턴스
  bool _isRecording = false; // 녹음 중인지 여부
  String? _audioFilePath; // 녹음된 파일 경로

  // 녹음 시간 추적
  final Duration _recordingDuration = Duration.zero;
  Duration get recordingDuration => _recordingDuration;

  /// Getter: 녹음 중인지 여부
  bool get isRecording => _isRecording;

  /// Getter: 오디오 파일 경로
  String? get audioFilePath => _audioFilePath;

  // 녹음 시간 갱신용 타이머
  //Timer? _timer;

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

  /// 녹음 시작
  Future<void> startRecording() async {
    final String path =
        '${(await getTemporaryDirectory()).path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder?.startRecorder(toFile: path);
    _isRecording = true;
    notifyListeners(); // 녹음 상태 변경 알림
  }

  /// 녹음 중지
  Future<void> stopRecording() async {
    final String? path = await _recorder?.stopRecorder();
    _isRecording = false;
    if (path != null) {
      _audioFilePath = path;
    }
    print('Audio file path: $_audioFilePath');
    notifyListeners(); // 녹음 상태 변경 알림
  }

  /// 녹음 파일을 AAC로 변환 (더 나은 호환성)
  Future<String> _convertToAAC(String inputFilePath) async {
    // 네이티브 코드를 사용하여 오디오 변환
    return await AudioConverterService.convertToAAC(inputFilePath);
  }

  /// 녹음 파일을 Firebase Storage에 업로드 후 다운로드 URL 반환
  Future<String> uploadAudioToFirestorage(
    String categoryId,
    String nickName,
  ) async {
    if (_audioFilePath == null) {
      throw Exception('No audio file to upload');
    }

    // 녹음된 파일을 AAC로 변환 (필요시)
    final aacFilePath = await _convertToAAC(_audioFilePath!);

    // Firebase Storage에 업로드 (확장자는 m4a로 변경)
    final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final ref = FirebaseStorage.instance.ref().child(
      'categories_audio/$fileName',
    );
    final file = File(aacFilePath);
    await ref.putFile(file);
    _audioFilePath = null; // 파일 경로 초기화
    return await ref.getDownloadURL();
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _recorder = null;
    super.dispose();
  }
}
