import 'dart:async';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 오디오 녹음/업로드 로직을 담당하는 모델 클래스
class AudioModel {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  /// 마이크 권한 요청 및 레코더 세션 열기
  Future<void> openRecorder() async {
    await Permission.microphone.request(); // 마이크 권한 요청
    await _recorder.openRecorder(); // 오디오 세션 열기
  }

  /// 녹음 시작
  Future<String?> startRecording() async {
    try {
      // 임시 디렉토리에 파일 경로 생성
      final tempDir = await getTemporaryDirectory();
      final recordingPath =
          '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

      debugPrint('녹음 경로 설정: $recordingPath');

      // 녹음 시작
      await _recorder.openRecorder();
      await _recorder.startRecorder(toFile: recordingPath);

      return recordingPath;
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
      return null;
    }
  }

  /// 녹음 중지
  Future<String?> stopRecording() async {
    try {
      // 녹음 중지
      final String? path = await _recorder.stopRecorder();

      // 경로 확인
      if (path != null && path.isNotEmpty) {
        debugPrint('녹음 중지 성공 - 경로: $path');
        final file = File(path);
        final exists = await file.exists();
        debugPrint('파일 존재 여부: $exists ($path)');

        if (!exists) {
          debugPrint('경고: 파일이 존재하지 않습니다: $path');
          return null;
        }

        return path;
      } else {
        debugPrint('경고: 녹음 파일 경로를 찾을 수 없습니다.');
        return null;
      }
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
      return null;
    }
  }

  /// 녹음 파일을 Firebase Storage에 업로드 후 다운로드 URL 반환
  Future<String?> uploadAudioToFirestorage(String? audioFilePath) async {
    if (audioFilePath == null) {
      debugPrint('No audio file to upload');
      return null;
    }

    try {
      // 파일 존재 여부 확인
      final file = File(audioFilePath);
      if (!await file.exists()) {
        debugPrint('오디오 파일이 존재하지 않습니다: $audioFilePath');
        return null;
      }

      // 확인: 파일이 실제로 읽을 수 있는지 확인
      try {
        await file.readAsBytes();
      } catch (e) {
        debugPrint('오디오 파일을 읽을 수 없습니다: $e');
        return null;
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
      return null;
    }
  }

  /// 오디오 파일 삭제
  Future<bool> deleteRecordedAudio(String? audioFilePath) async {
    if (audioFilePath == null) return false;

    try {
      final file = File(audioFilePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Audio file deleted: $audioFilePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to delete audio file: $e');
      return false;
    }
  }

  /// 녹음된 오디오 재생
  Future<FlutterSoundPlayer?> playRecordedAudio(String? audioFilePath) async {
    if (audioFilePath == null) {
      debugPrint('No audio file to play');
      return null;
    }

    try {
      FlutterSoundPlayer player = FlutterSoundPlayer();
      await player.openPlayer();

      // 오디오 파일 재생
      await player.startPlayer(
        fromURI: audioFilePath,
        whenFinished: () {
          player.closePlayer();
        },
      );

      return player;
    } catch (e) {
      debugPrint('Error playing audio: $e');
      return null;
    }
  }

  /// 레코더 해제
  Future<void> closeRecorder() async {
    await _recorder.closeRecorder();
  }

  /// 댓글용 오디오 업로드
  Future<String?> uploadCommentAudio(
    String audioFilePath,
    String nickName,
  ) async {
    try {
      // 파일명에 사용자 닉네임과 현재 시각의 초 단위를 포함.
      final fileName = "${nickName}_comment_${DateTime.now().second}";
      final file = File(audioFilePath);

      // 로컬 파일이 존재하는지 확인.
      if (!file.existsSync()) {
        debugPrint('File does not exist: $audioFilePath');
        return null;
      }

      // Firebase Storage에 업로드.
      final ref = FirebaseStorage.instance.ref().child(
        'categories_comments_audio/$fileName',
      );
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading comment audio: $e');
      return null;
    }
  }

  /// 실시간 녹음 레벨 모니터링 시작
  StreamSubscription<RecordingDisposition>? startRecordingLevelMonitoring(
    Function(double) onLevelChanged,
  ) {
    if (!_recorder.isRecording) return null;

    _recorder.setSubscriptionDuration(const Duration(milliseconds: 50));
    return _recorder.onProgress?.listen((event) {
      onLevelChanged(event.decibels ?? 0.0);
    });
  }
}
