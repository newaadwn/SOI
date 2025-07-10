import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/comment_data_model.dart';

/// Firebase에서 comment 관련 데이터를 가져오고, 저장하고, 업데이트하고 삭제하는 등의 로직들
class CommentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const MethodChannel _channel = MethodChannel('native_recorder');

  // ==================== 권한 관리 ====================

  /// 마이크 권한 요청
  static Future<bool> requestMicrophonePermission() async {
    try {
      final bool granted = await _channel.invokeMethod('requestPermission');
      return granted;
    } catch (e) {
      debugPrint('Error requesting permission: $e');
      return false;
    }
  }

  // ==================== 네이티브 녹음 관리 ====================

  /// 레코더 초기화 (네이티브만 사용)
  Future<void> initializeRecorder() async {
    debugPrint('댓글 네이티브 녹음 초기화 완료');
  }

  /// 레코더 종료
  Future<void> disposeRecorder() async {
    debugPrint('댓글 네이티브 녹음 종료 완료');
  }

  /// 네이티브 녹음 시작 (메인)
  static Future<String> startRecording() async {
    try {
      // 2. 임시 디렉토리 경로 가져오기 (수정된 부분)
      final Directory tempDir = await getTemporaryDirectory();
      final String fileExtension = '.m4a';
      final String filePath =
          '${tempDir.path}/comment_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      // 3. 전체 파일 경로를 인자로 전달 (수정된 부분)
      final Map<String, dynamic> args = {'filePath': filePath};

      final String resultPath = await _channel.invokeMethod(
        'startRecording',
        args,
      );
      print('🎤 댓글 네이티브 녹음 시작: $resultPath');
      return resultPath;
    } catch (e) {
      print('❌ 댓글 네이티브 녹음 시작 오류: $e');
      rethrow;
    }
  }

  /// 네이티브 녹음 중지
  static Future<String?> stopRecording() async {
    try {
      final String? filePath = await _channel.invokeMethod('stopRecording');
      debugPrint('🎤 댓글 네이티브 녹음 중지: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('❌ 댓글 네이티브 녹음 중지 오류: $e');
      return null;
    }
  }

  /// 네이티브 녹음 상태 확인
  static Future<bool> isRecording() async {
    try {
      final bool recording = await _channel.invokeMethod('isRecording');
      return recording;
    } catch (e) {
      debugPrint('❌ 댓글 네이티브 녹음 상태 확인 오류: $e');
      return false;
    }
  }

  /// 네이티브 녹음 레벨 스트림 (UI 표시용)
  static Future<Stream<double>> getRecordingAmplitudeStream() async {
    try {
      return _channel
          .invokeMethod('getRecordingAmplitudeStream')
          .then(
            (value) => Stream.periodic(
              const Duration(milliseconds: 100),
              (count) => (value as double?) ?? 0.0,
            ),
          );
    } catch (e) {
      debugPrint('❌ 녹음 레벨 스트림 오류: $e');
      return Stream.value(0.0);
    }
  }

  // ==================== 네이티브 재생 관리 ====================

  /// 네이티브 플레이어 초기화
  static Future<void> initializePlayer() async {
    try {
      await _channel.invokeMethod('initializePlayer');
      debugPrint('🎵 네이티브 플레이어 초기화 완료');
    } catch (e) {
      debugPrint('❌ 네이티브 플레이어 초기화 오류: $e');
    }
  }

  /// 네이티브 플레이어 종료
  static Future<void> disposePlayer() async {
    try {
      await _channel.invokeMethod('disposePlayer');
      debugPrint('🎵 네이티브 플레이어 종료 완료');
    } catch (e) {
      debugPrint('❌ 네이티브 플레이어 종료 오류: $e');
    }
  }

  /// 네이티브 오디오 재생 (URL)
  static Future<void> playFromUrl(String url) async {
    try {
      final Map<String, dynamic> args = {'url': url};
      await _channel.invokeMethod('playFromUrl', args);
      debugPrint('🎵 네이티브 오디오 재생 시작: $url');
    } catch (e) {
      debugPrint('❌ 네이티브 오디오 재생 오류: $e');
    }
  }

  /// 네이티브 오디오 재생 (로컬 파일)
  static Future<void> playFromPath(String filePath) async {
    try {
      final Map<String, dynamic> args = {'filePath': filePath};
      await _channel.invokeMethod('playFromPath', args);
      debugPrint('🎵 네이티브 오디오 재생 시작: $filePath');
    } catch (e) {
      debugPrint('❌ 네이티브 오디오 재생 오류: $e');
    }
  }

  /// 네이티브 재생 중지
  static Future<void> stopPlaying() async {
    try {
      await _channel.invokeMethod('stopPlaying');
      debugPrint('🎵 네이티브 오디오 재생 중지');
    } catch (e) {
      debugPrint('❌ 네이티브 오디오 재생 중지 오류: $e');
    }
  }

  /// 네이티브 재생 일시정지
  static Future<void> pausePlaying() async {
    try {
      await _channel.invokeMethod('pausePlaying');
      debugPrint('🎵 네이티브 오디오 재생 일시정지');
    } catch (e) {
      debugPrint('❌ 네이티브 오디오 재생 일시정지 오류: $e');
    }
  }

  /// 네이티브 재생 재개
  static Future<void> resumePlaying() async {
    try {
      await _channel.invokeMethod('resumePlaying');
      debugPrint('🎵 네이티브 오디오 재생 재개');
    } catch (e) {
      debugPrint('❌ 네이티브 오디오 재생 재개 오류: $e');
    }
  }

  /// 네이티브 재생 상태 확인
  static Future<bool> isPlaying() async {
    try {
      final bool playing = await _channel.invokeMethod('isPlaying');
      return playing;
    } catch (e) {
      debugPrint('❌ 네이티브 재생 상태 확인 오류: $e');
      return false;
    }
  }

  /// 네이티브 재생 위치 설정 (초 단위)
  static Future<void> seekTo(double positionInSeconds) async {
    try {
      final Map<String, dynamic> args = {'position': positionInSeconds};
      await _channel.invokeMethod('seekTo', args);
      debugPrint('🎵 네이티브 오디오 위치 설정: ${positionInSeconds}초');
    } catch (e) {
      debugPrint('❌ 네이티브 오디오 위치 설정 오류: $e');
    }
  }

  /// 네이티브 재생 진행률 스트림
  static Future<Stream<Map<String, dynamic>>>
  getPlaybackProgressStream() async {
    try {
      return _channel
          .invokeMethod('getPlaybackProgressStream')
          .then(
            (value) => Stream.periodic(
              const Duration(milliseconds: 100),
              (count) =>
                  (value as Map<String, dynamic>?) ??
                  {'position': 0.0, 'duration': 0.0},
            ),
          );
    } catch (e) {
      debugPrint('❌ 재생 진행률 스트림 오류: $e');
      return Stream.value({'position': 0.0, 'duration': 0.0});
    }
  }

  // ==================== 네이티브 파일 관리 ====================

  /// 네이티브로 파일 크기 계산 (MB 단위)
  static Future<double> getFileSize(String filePath) async {
    try {
      final Map<String, dynamic> args = {'filePath': filePath};
      final double sizeInBytes = await _channel.invokeMethod(
        'getFileSize',
        args,
      );
      return sizeInBytes / (1024 * 1024); // MB로 변환
    } catch (e) {
      debugPrint('❌ 네이티브 파일 크기 계산 오류: $e');
      // 폴백: Dart로 파일 크기 계산
      final file = File(filePath);
      if (!await file.exists()) return 0.0;
      final bytes = await file.length();
      return bytes / (1024 * 1024);
    }
  }

  /// 네이티브로 오디오 파일 길이 계산 (초 단위)
  static Future<double> getAudioDuration(String filePath) async {
    try {
      final Map<String, dynamic> args = {'filePath': filePath};
      final double duration = await _channel.invokeMethod(
        'getAudioDuration',
        args,
      );
      return duration;
    } catch (e) {
      debugPrint('❌ 네이티브 오디오 길이 계산 오류: $e');
      // 폴백: 파일 크기 기반 추정
      final sizeInMB = await getFileSize(filePath);
      return sizeInMB * 60; // 대략적인 추정
    }
  }

  /// 네이티브로 오디오 파일 형식 변환
  static Future<String?> convertAudioFormat(
    String inputPath,
    String outputFormat, // 'aac', 'mp3', 'm4a' 등
  ) async {
    try {
      final Map<String, dynamic> args = {
        'inputPath': inputPath,
        'outputFormat': outputFormat,
      };
      final String? outputPath = await _channel.invokeMethod(
        'convertAudioFormat',
        args,
      );
      debugPrint('🔄 네이티브 오디오 형식 변환 완료: $outputPath');
      return outputPath;
    } catch (e) {
      debugPrint('❌ 네이티브 오디오 형식 변환 오류: $e');
      return null;
    }
  }

  /// 네이티브로 오디오 압축
  static Future<String?> compressAudio(
    String inputPath,
    double quality, // 0.0 ~ 1.0
  ) async {
    try {
      final Map<String, dynamic> args = {
        'inputPath': inputPath,
        'quality': quality,
      };
      final String? outputPath = await _channel.invokeMethod(
        'compressAudio',
        args,
      );
      debugPrint('📦 네이티브 오디오 압축 완료: $outputPath');
      return outputPath;
    } catch (e) {
      debugPrint('❌ 네이티브 오디오 압축 오류: $e');
      return null;
    }
  }

  /// 임시 파일 삭제
  Future<void> deleteLocalFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ==================== Firestore 관리 ====================

  /// 댓글 데이터 저장
  Future<String> saveComment(CommentDataModel comment) async {
    final docRef = await _firestore
        .collection('comments')
        .add(comment.toFirestore());
    return docRef.id;
  }

  /// 댓글 데이터 업데이트
  Future<void> updateComment(
    String commentId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('comments').doc(commentId).update(data);
  }

  /// 댓글 데이터 삭제 (소프트 삭제)
  Future<void> deleteComment(String commentId) async {
    await _firestore.collection('comments').doc(commentId).update({
      'status': CommentStatus.deleted.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 댓글 데이터 완전 삭제
  Future<void> hardDeleteComment(String commentId) async {
    await _firestore.collection('comments').doc(commentId).delete();
  }

  /// 특정 댓글 데이터 조회
  Future<CommentDataModel?> getComment(String commentId) async {
    final doc = await _firestore.collection('comments').doc(commentId).get();

    if (!doc.exists || doc.data() == null) return null;

    return CommentDataModel.fromFirestore(doc.data()!, doc.id);
  }

  /// 사진별 댓글 목록 조회
  Future<List<CommentDataModel>> getCommentsByPhoto(
    String categoryId,
    String photoId,
  ) async {
    final querySnapshot =
        await _firestore
            .collection('comments')
            .where('categoryId', isEqualTo: categoryId)
            .where('photoId', isEqualTo: photoId)
            .where('status', isEqualTo: CommentStatus.active.name)
            .orderBy('createdAt', descending: false)
            .get();

    return querySnapshot.docs
        .map((doc) => CommentDataModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// 사용자별 댓글 목록 조회
  Future<List<CommentDataModel>> getCommentsByUser(String userId) async {
    final querySnapshot =
        await _firestore
            .collection('comments')
            .where('userId', isEqualTo: userId)
            .where(
              'status',
              whereIn: [CommentStatus.active.name, CommentStatus.hidden.name],
            )
            .orderBy('createdAt', descending: true)
            .get();

    return querySnapshot.docs
        .map((doc) => CommentDataModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// 사진별 댓글 스트림
  Stream<List<CommentDataModel>> getCommentsByPhotoStream(
    String categoryId,
    String photoId,
  ) {
    return _firestore
        .collection('comments')
        .where('categoryId', isEqualTo: categoryId)
        .where('photoId', isEqualTo: photoId)
        .where('status', isEqualTo: CommentStatus.active.name)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => CommentDataModel.fromFirestore(doc.data(), doc.id),
                  )
                  .toList(),
        );
  }

  /// 댓글 좋아요 추가
  Future<void> addLike(String commentId, String userId) async {
    await _firestore.collection('comments').doc(commentId).update({
      'likedBy': FieldValue.arrayUnion([userId]),
      'likeCount': FieldValue.increment(1),
    });
  }

  /// 댓글 좋아요 제거
  Future<void> removeLike(String commentId, String userId) async {
    await _firestore.collection('comments').doc(commentId).update({
      'likedBy': FieldValue.arrayRemove([userId]),
      'likeCount': FieldValue.increment(-1),
    });
  }

  /// 댓글 신고
  Future<void> reportComment(
    String commentId,
    String reporterId,
    String reason,
  ) async {
    // 신고 컬렉션에 저장
    await _firestore.collection('reports').add({
      'commentId': commentId,
      'reporterId': reporterId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    // 댓글 상태를 신고됨으로 변경
    await _firestore.collection('comments').doc(commentId).update({
      'status': CommentStatus.reported.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 사진의 닉네임 조회 (기존 호환성)
  Future<String> getNickNameFromPhoto(String categoryId, String photoId) async {
    try {
      final doc =
          await _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('photos')
              .doc(photoId)
              .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!['nickName'] ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // ==================== Firebase Storage 관리 (네이티브 연동) ====================

  /// 네이티브에서 처리된 오디오 파일 업로드
  Future<String> uploadAudioFile(String filePath, String nickName) async {
    try {
      // 1. 네이티브로 파일 압축 (품질 0.7로 압축)
      final compressedPath = await CommentRepository.compressAudio(
        filePath,
        0.7,
      );
      final uploadFilePath = compressedPath ?? filePath;

      // 2. 네이티브로 오디오 길이 확인
      final duration = await CommentRepository.getAudioDuration(uploadFilePath);
      debugPrint('📁 업로드할 파일 길이: ${duration}초');

      // 3. Firebase Storage에 업로드
      final file = File(uploadFilePath);
      final fileName =
          'comment_${nickName}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = _storage
          .ref()
          .child('comments')
          .child(nickName)
          .child(fileName);

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() => null);

      // 4. 압축된 임시 파일 삭제 (원본과 다른 경우에만)
      if (compressedPath != null && compressedPath != filePath) {
        await deleteLocalFile(compressedPath);
      }

      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('☁️ 오디오 파일 업로드 완료: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ 오디오 파일 업로드 실패: $e');
      rethrow;
    }
  }

  /// 네이티브 파일 정보와 함께 업로드 진행률 스트림
  Stream<Map<String, dynamic>> getUploadProgressStreamWithInfo(
    String filePath,
    String nickName,
  ) async* {
    try {
      // 네이티브로 파일 정보 수집
      final fileSize = await CommentRepository.getFileSize(filePath);
      final duration = await CommentRepository.getAudioDuration(filePath);

      final file = File(filePath);
      final fileName =
          'comment_${nickName}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = _storage
          .ref()
          .child('comments')
          .child(nickName)
          .child(fileName);

      await for (final snapshot in ref.putFile(file).snapshotEvents) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        yield {
          'progress': progress,
          'bytesTransferred': snapshot.bytesTransferred,
          'totalBytes': snapshot.totalBytes,
          'fileSize': fileSize,
          'duration': duration,
          'state': snapshot.state.toString(),
        };
      }
    } catch (e) {
      debugPrint('❌ 업로드 진행률 스트림 오류: $e');
      yield {'progress': 0.0, 'error': e.toString()};
    }
  }

  /// 오디오 파일 삭제 (네이티브 연동)
  Future<void> deleteAudioFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      debugPrint('☁️ Firebase Storage 오디오 파일 삭제 완료: $downloadUrl');
    } catch (e) {
      debugPrint('❌ Firebase Storage 오디오 파일 삭제 실패: $e');
    }
  }

  // ==================== 네이티브 오디오 품질 관리 ====================

  /// 네이티브로 오디오 품질 분석
  static Future<Map<String, dynamic>> analyzeAudioQuality(
    String filePath,
  ) async {
    try {
      final Map<String, dynamic> args = {'filePath': filePath};
      final Map<String, dynamic> analysis = await _channel.invokeMethod(
        'analyzeAudioQuality',
        args,
      );
      return analysis;
    } catch (e) {
      debugPrint('❌ 네이티브 오디오 품질 분석 오류: $e');
      return {
        'sampleRate': 44100,
        'bitRate': 128000,
        'channels': 1,
        'format': 'unknown',
        'quality': 'medium',
      };
    }
  }

  /// 네이티브로 노이즈 제거
  static Future<String?> removeNoise(String inputPath) async {
    try {
      final Map<String, dynamic> args = {'inputPath': inputPath};
      final String? outputPath = await _channel.invokeMethod(
        'removeNoise',
        args,
      );
      debugPrint('🔇 네이티브 노이즈 제거 완료: $outputPath');
      return outputPath;
    } catch (e) {
      debugPrint('❌ 네이티브 노이즈 제거 오류: $e');
      return null;
    }
  }

  /// 네이티브로 오디오 볼륨 정규화
  static Future<String?> normalizeVolume(String inputPath) async {
    try {
      final Map<String, dynamic> args = {'inputPath': inputPath};
      final String? outputPath = await _channel.invokeMethod(
        'normalizeVolume',
        args,
      );
      debugPrint('🔊 네이티브 볼륨 정규화 완료: $outputPath');
      return outputPath;
    } catch (e) {
      debugPrint('❌ 네이티브 볼륨 정규화 오류: $e');
      return null;
    }
  }
}
