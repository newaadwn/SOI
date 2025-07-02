import 'package:flutter/services.dart';

/// 네이티브 오디오 변환 기능을 제공하는 서비스 클래스
class AudioConverterService {
  static const MethodChannel _channel = MethodChannel(
    'com.app.audio_converter',
  );

  /// AAC/M4A 파일을 MP3로 변환
  ///
  /// [inputFilePath] 변환할 오디오 파일 경로
  /// 반환값: 변환된 MP3 파일 경로
  static Future<String> convertToMp3(String inputFilePath) async {
    try {
      final result = await _channel.invokeMethod('convertAudioToMp3', {
        'inputPath': inputFilePath,
      });
      return result as String;
    } on PlatformException catch (e) {
      throw Exception('Failed to convert audio file: ${e.message}');
    }
  }

  /// 오디오 파일을 AAC 포맷으로 변환
  ///
  /// [inputFilePath] 변환할 오디오 파일 경로
  /// 반환값: AAC 포맷(M4A 컨테이너)으로 변환된 파일 경로
  static Future<String> convertToAAC(String inputFilePath) async {
    try {
      final result = await _channel.invokeMethod('convertAudioToAAC', {
        'inputPath': inputFilePath,
      });
      return result as String;
    } on PlatformException catch (e) {
      throw Exception('Failed to convert audio file: ${e.message}');
    }
  }
}
