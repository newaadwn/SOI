import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/audio_data_model.dart';

/// Firebase에서 오디오 관련 데이터를 가져오고, 저장하고, 업데이트하고 삭제하는 등의 로직들
class AudioRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const MethodChannel _channel = MethodChannel('native_recorder');

  // ==================== 권한 관리 (네이티브) ====================

  /// 마이크 권한 상태 확인 (네이티브에서 처리)
  static Future<bool> checkMicrophonePermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod(
        'checkMicrophonePermission',
      );

      return hasPermission;
    } catch (e) {
      debugPrint('네이티브 마이크 권한 확인 오류: $e');
      return false;
    }
  }

  /// 마이크 권한 요청 (네이티브에서 처리)
  static Future<bool> requestMicrophonePermission() async {
    try {
      // debugPrint('🎤 네이티브에서 마이크 권한을 요청합니다...');
      final bool granted = await _channel.invokeMethod(
        'requestMicrophonePermission',
      );

      if (granted) {
        return true;
      } else {
        debugPrint('네이티브 마이크 권한이 거부되었습니다.');
        return false;
      }
    } catch (e) {
      debugPrint('네이티브 마이크 권한 요청 중 오류: $e');
      return false;
    }
  }

  // ==================== 네이티브 녹음 관리 ====================

  /// 네이티브 녹음 시작 (메인)
  /// Returns: 생성된 파일 경로
  static Future<String> startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      //final String fileExtension = '.m4a'; // AAC 코덱 사용
      String filePath =
          '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final String startedPath = await _channel.invokeMethod('startRecording', {
        'filePath': filePath,
      });

      return startedPath; // 실제 생성된 파일 경로 반환
    } catch (e) {
      debugPrint('네이티브 녹음 시작 오류: $e');
      return '';
    }
  }

  /// 네이티브 녹음 중지
  /// Returns: 녹음된 파일 경로
  static Future<String?> stopRecording() async {
    try {
      final String? filePath = await _channel.invokeMethod('stopRecording');

      return filePath;
    } catch (e) {
      debugPrint('네이티브 녹음 중지 오류: $e');
      return null;
    }
  }

  /// 네이티브 녹음 상태 확인
  static Future<bool> isRecording() async {
    try {
      final bool recording = await _channel.invokeMethod('isRecording');
      return recording;
    } catch (e) {
      debugPrint('네이티브 녹음 상태 확인 오류: $e');
      return false;
    }
  }

  // 네이티브 녹음에서는 레벨 스트림 제공하지 않음

  // ==================== 재생 관리 (네이티브) ====================

  /// 플레이어 초기화 (audioplayers 패키지 사용)
  Future<void> initializePlayer() async {
    // debugPrint('네이티브 플레이어 초기화 완료');
  }

  /// 플레이어 종료
  Future<void> disposePlayer() async {
    // debugPrint('네이티브 플레이어 종료 완료');
  }

  /// 오디오 재생 (URL) - audioplayers 사용
  Future<void> playFromUrl(String url) async {
    // audioplayers 패키지를 사용하여 재생
    // 실제 구현은 AudioController에서 처리
    // debugPrint('URL 재생: $url');
  }

  /// 오디오 재생 (로컬 파일) - audioplayers 사용
  Future<void> playFromFile(String filePath) async {
    // audioplayers 패키지를 사용하여 로컬 파일 재생
    // 실제 구현은 AudioController에서 처리
    // debugPrint('로컬 파일 재생: $filePath');
  }

  /// 재생 중지
  Future<void> stopPlaying() async {
    // debugPrint('재생 중지');
  }

  /// 재생 일시정지
  Future<void> pausePlaying() async {
    // debugPrint('재생 일시정지');
  }

  /// 재생 재개
  Future<void> resumePlaying() async {
    // debugPrint('재생 재개');
  }

  /// 재생 상태 확인 (기본값 false)
  bool get isPlaying => false;

  // 네이티브에서는 재생 진행률 스트림 제공하지 않음

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
        // print('임시 파일 삭제 실패: $e');
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

  // ==================== Supabase Storage 관리 ====================

  /// 오디오 파일을 Supabase Storage에 업로드
  Future<String?> uploadAudioToSupabaseStorage({
    required File audioFile,
    required String categoryId,
    required String userId,
    String? customFileName,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      // 파일 존재 확인
      if (!await audioFile.exists()) {
        debugPrint('오디오 파일이 존재하지 않습니다: ${audioFile.path}');
        return null;
      }

      // 파일 크기 확인
      final fileSize = await audioFile.length();
      if (fileSize == 0) {
        debugPrint('오디오 파일 크기가 0입니다');
        return null;
      }

      // 파일명 생성
      final fileName =
          customFileName ??
          '${categoryId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      debugPrint('AudioRepository: Supabase에 오디오 업로드 시작 - $fileName');

      // supabase storage에 오디오 업로드
      await supabase.storage.from('audio').upload(fileName, audioFile);

      // 즉시 공개 URL 생성
      final publicUrl = supabase.storage.from('audio').getPublicUrl(fileName);

      debugPrint('AudioRepository: 오디오 업로드 성공 - $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('AudioRepository: 오디오 업로드 오류 - $e');
      return null;
    }
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
      // print('오디오 파일 삭제 실패: $e');
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

  /// 오디오 파일에서 파형 데이터 추출
  Future<List<double>> extractWaveformData(String audioFilePath) async {
    // debugPrint('🌊 파형 데이터 추출 시작 - 파일: $audioFilePath');

    final controller = PlayerController();

    try {
      await controller.preparePlayer(
        path: audioFilePath,
        shouldExtractWaveform: true,
      );

      // 파형 추출 완료 대기 (PhotoGridItem과 동일한 로직)
      List<double> rawData = [];
      int attempts = 0;
      const maxAttempts = 200; // 20초 대기 (업로드 시에는 더 오래 기다림)

      // debugPrint('⏳ 파형 추출 완료 대기 중...');
      while (attempts < maxAttempts && rawData.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;

        try {
          final currentData = controller.waveformData;
          if (currentData.isNotEmpty) {
            rawData = currentData;

            break;
          }
        } catch (e) {
          // 아직 준비되지 않음, 계속 대기
        }

        // 진행률 로그 (5초마다)
        if (attempts % 50 == 0) {
          // debugPrint('⏳ 파형 추출 대기 중... ${attempts * 100}ms');
        }
      }

      // debugPrint('📊 원본 파형 데이터 길이: ${rawData.length}');

      if (rawData.isEmpty) {
        // debugPrint('❌ 파형 데이터 추출 시간 초과 또는 실패');
        return [];
      }

      // 데이터 최적화 (100개 포인트로 압축)
      final compressedData = _compressWaveformData(rawData, targetLength: 100);
      // debugPrint('🗜️ 압축된 파형 데이터 길이: ${compressedData.length}');
      // debugPrint('📈 파형 샘플: ${compressedData.take(5).toList()}...');

      return compressedData;
    } catch (e) {
      // debugPrint('❌ 파형 데이터 추출 실패: $e');
      return [];
    } finally {
      controller.dispose();
    }
  }

  /// 파형 데이터 압축
  List<double> _compressWaveformData(
    List<double> data, {
    int targetLength = 100,
  }) {
    if (data.length <= targetLength) return data;

    final step = data.length / targetLength;
    final compressed = <double>[];

    for (int i = 0; i < targetLength; i++) {
      final index = (i * step).round();
      if (index < data.length) {
        compressed.add(data[index]);
      }
    }

    return compressed;
  }

  /// 오디오 길이 계산 (더 정확한 방법)
  Future<double> getAudioDurationAccurate(String audioFilePath) async {
    final controller = PlayerController();

    try {
      await controller.preparePlayer(path: audioFilePath);
      final duration = controller.maxDuration;
      return duration / 1000.0; // 밀리초를 초로 변환
    } catch (e) {
      // debugPrint('오디오 길이 계산 실패: $e');
      return 0.0;
    } finally {
      controller.dispose();
    }
  }
}
