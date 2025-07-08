import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/audio_data_model.dart';

/// Firebase에서 오디오 관련 데이터를 가져오고, 저장하고, 업데이트하고 삭제하는 등의 로직들
class AudioRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  static const MethodChannel _channel = MethodChannel('native_recorder');

  // ==================== 권한 관리 ====================

  /// 마이크 권한 요청
  static Future<bool> requestPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('requestPermission');
      return granted;
    } catch (e) {
      print('Error requesting permission: $e');
      return false;
    }
  }

  /// 저장소 권한 요청
  Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status == PermissionStatus.granted;
  }

  // ==================== 녹음 관리 ====================

  /// 레코더 초기화
  Future<void> initializeRecorder() async {
    await _recorder.openRecorder();
  }

  /// 레코더 종료
  Future<void> disposeRecorder() async {
    await _recorder.closeRecorder();
  }

  /// 네이티브 녹음 시작
  /// [filePath]: 녹음 파일이 저장될 경로 (확장자 .m4a)
  static Future<String> startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final String fileExtension = '.m4a'; // 녹음 파일 확장자
      String filePath =
          '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final String started = await _channel.invokeMethod('startRecording', {
        'filePath': filePath,
      });
      return started;
    } catch (e) {
      print('Error starting recording: $e');
      return '';
    }
  }

  /// 네이티브 녹음 중지
  /// Returns: 녹음된 파일 경로
  static Future<String?> stopRecording() async {
    try {
      final String? filePath = await _channel.invokeMethod('stopRecording');
      debugPrint('녹음 파일 경로: $filePath');
      return filePath;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  /// 녹음 상태 확인
  static Future<bool> isRecording() async {
    try {
      final bool recording = await _channel.invokeMethod('isRecording');
      return recording;
    } catch (e) {
      print('Error checking recording status: $e');
      return false;
    }
  }

  /// 녹음 레벨 스트림
  Stream<RecordingDisposition>? get recordingStream => _recorder.onProgress;

  // ==================== 재생 관리 ====================

  /// 플레이어 초기화
  Future<void> initializePlayer() async {
    await _player.openPlayer();
  }

  /// 플레이어 종료
  Future<void> disposePlayer() async {
    await _player.closePlayer();
  }

  /// 오디오 재생 (로컬 파일)
  Future<void> playFromFile(String filePath) async {
    await _player.startPlayer(fromURI: filePath);
  }

  /// 오디오 재생 (URL)
  Future<void> playFromUrl(String url) async {
    await _player.startPlayer(fromURI: url);
  }

  /// 재생 중지
  Future<void> stopPlaying() async {
    await _player.stopPlayer();
  }

  /// 재생 일시정지
  Future<void> pausePlaying() async {
    await _player.pausePlayer();
  }

  /// 재생 재개
  Future<void> resumePlaying() async {
    await _player.resumePlayer();
  }

  /// 재생 상태 확인
  bool get isPlaying => _player.isPlaying;

  /// 재생 진행률 스트림
  Stream<PlaybackDisposition>? get playbackStream => _player.onProgress;

  // ==================== 파일 관리 ====================

  /// 파일 크기 계산 (MB 단위)
  Future<double> getFileSize(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0.0;

    final bytes = await file.length();
    return bytes / (1024 * 1024); // MB로 변환
  }

  /// 오디오 파일 길이 계산 (초 단위)
  Future<int> getAudioDuration(String filePath) async {
    // FlutterSound를 사용하여 오디오 길이 측정
    // 실제 구현에서는 더 정확한 방법을 사용할 수 있습니다.
    final file = File(filePath);
    if (!await file.exists()) return 0;

    // 임시적으로 파일 크기 기반 추정 (실제로는 더 정확한 방법 필요)
    final sizeInMB = await getFileSize(filePath);
    return (sizeInMB * 60).round(); // 대략적인 추정
  }

  /// 임시 파일 삭제
  Future<void> deleteLocalFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 임시 디렉토리 정리
  Future<void> cleanupTempFiles() async {
    final tempDir = await getTemporaryDirectory();
    final audioFiles = tempDir.listSync().where(
      (file) =>
          file.path.contains('audio_') &&
          (file.path.endsWith('.ogg') ||
              file.path.endsWith('.aac') ||
              file.path.endsWith('.m4a') ||
              file.path.endsWith('.wav')),
    );

    for (final file in audioFiles) {
      try {
        await file.delete();
      } catch (e) {
        print('임시 파일 삭제 실패: $e');
      }
    }
  }

  // ==================== Firestore 관리 ====================

  /// 오디오 데이터 저장
  Future<String> saveAudioData(AudioDataModel audio) async {
    final docRef = await _firestore
        .collection('audios')
        .add(audio.toFirestore());
    return docRef.id;
  }

  /// 오디오 데이터 업데이트
  Future<void> updateAudioData(
    String audioId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('audios').doc(audioId).update(data);
  }

  /// 오디오 데이터 삭제
  Future<void> deleteAudioData(String audioId) async {
    await _firestore.collection('audios').doc(audioId).delete();
  }

  /// 특정 오디오 데이터 조회
  Future<AudioDataModel?> getAudioData(String audioId) async {
    final doc = await _firestore.collection('audios').doc(audioId).get();

    if (!doc.exists || doc.data() == null) return null;

    return AudioDataModel.fromFirestore(doc.data()!, doc.id);
  }

  /// 카테고리별 오디오 목록 조회
  Future<List<AudioDataModel>> getAudiosByCategory(String categoryId) async {
    final querySnapshot =
        await _firestore
            .collection('audios')
            .where('categoryId', isEqualTo: categoryId)
            .orderBy('createdAt', descending: true)
            .get();

    return querySnapshot.docs
        .map((doc) => AudioDataModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// 사용자별 오디오 목록 조회
  Future<List<AudioDataModel>> getAudiosByUser(String userId) async {
    final querySnapshot =
        await _firestore
            .collection('audios')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();

    return querySnapshot.docs
        .map((doc) => AudioDataModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// 카테고리별 오디오 스트림
  Stream<List<AudioDataModel>> getAudiosByCategoryStream(String categoryId) {
    return _firestore
        .collection('audios')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => AudioDataModel.fromFirestore(doc.data(), doc.id),
                  )
                  .toList(),
        );
  }

  // ==================== Firebase Storage 관리 ====================

  /// 오디오 파일 업로드
  Future<String> uploadAudioFile(String audioId, String filePath) async {
    final file = File(filePath);

    // 파일 확장자 추출
    final fileExtension = filePath.split('.').last;

    final fileName =
        'audio_${audioId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final ref = _storage.ref().child('audios').child(audioId).child(fileName);

    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask.whenComplete(() => null);

    return await snapshot.ref.getDownloadURL();
  }

  /// 오디오 파일 삭제
  Future<void> deleteAudioFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      print('오디오 파일 삭제 실패: $e');
    }
  }

  /// 업로드 진행률 스트림
  Stream<TaskSnapshot> getUploadProgressStream(
    String audioId,
    String filePath,
  ) {
    final file = File(filePath);

    // 파일 확장자 추출
    final fileExtension = filePath.split('.').last;

    final fileName =
        'audio_${audioId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final ref = _storage.ref().child('audios').child(audioId).child(fileName);

    return ref.putFile(file).snapshotEvents;
  }
}
