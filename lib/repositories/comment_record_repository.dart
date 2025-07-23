import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // debugPrint를 위한 import
import 'package:flutter/painting.dart'; // Offset를 위한 import
import '../models/comment_record_model.dart';

class CommentRecordRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _collectionName = 'comment_records';
  static const String _storagePath = 'comment_records';

  /// 음성 댓글을 Firebase Storage에 업로드하고 Firestore에 저장
  Future<CommentRecordModel> createCommentRecord({
    required String audioFilePath,
    required String photoId,
    required String recorderUser,
    required List<double> waveformData,
    required int duration,
    required String profileImageUrl, // 프로필 이미지 URL 추가
    Offset? profilePosition, // 프로필 이미지 위치 (선택적)
  }) async {
    try {
      // 1. Firebase Storage에 음성 파일 업로드
      final audioUrl = await _uploadAudioFile(
        audioFilePath,
        photoId,
        recorderUser,
      );

      // 2. CommentRecord 객체 생성
      final commentRecord = CommentRecordModel(
        id: '', // Firestore에서 자동 생성됨
        audioUrl: audioUrl,
        photoId: photoId,
        recorderUser: recorderUser,
        createdAt: DateTime.now(),
        waveformData: waveformData,
        duration: duration,
        isDeleted: false,
        profileImageUrl: profileImageUrl, // 전달받은 프로필 이미지 URL 사용
        profilePosition: profilePosition, // 프로필 위치 추가
      );

      // 3. Firestore에 저장
      final docRef = await _firestore
          .collection(_collectionName)
          .add(commentRecord.toFirestore());

      // 4. ID가 포함된 객체 반환
      return commentRecord.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('음성 댓글 저장 실패: $e');
    }
  }

  /// Firebase Storage에 오디오 파일 업로드
  Future<String> _uploadAudioFile(
    String filePath,
    String photoId,
    String recorderUser,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('음성 파일이 존재하지 않습니다: $filePath');
      }

      // 고유한 파일명 생성
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${photoId}_${recorderUser}_$timestamp.aac';
      final storageRef = _storage.ref().child('$_storagePath/$fileName');

      // 메타데이터 설정
      final metadata = SettableMetadata(
        contentType: 'audio/aac',
        customMetadata: {
          'photoId': photoId,
          'recorderUser': recorderUser,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // 파일 업로드
      final uploadTask = storageRef.putFile(file, metadata);
      final snapshot = await uploadTask;

      // 다운로드 URL 반환
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('음성 파일 업로드 실패: $e');
    }
  }

  /// 특정 사진의 음성 댓글들 조회
  Future<List<CommentRecordModel>> getCommentRecordsByPhotoId(
    String photoId,
  ) async {
    try {
      debugPrint('🔍 Firestore 쿼리 시작 - photoId: $photoId');

      final querySnapshot =
          await _firestore
              .collection(_collectionName)
              .where('photoId', isEqualTo: photoId)
              .where('isDeleted', isEqualTo: false)
              .orderBy('createdAt', descending: false)
              .get();

      debugPrint('✅ Firestore 쿼리 성공 - 문서 수: ${querySnapshot.docs.length}');

      final results =
          querySnapshot.docs.map((doc) {
            try {
              debugPrint('📄 문서 파싱 중 - ID: ${doc.id}');
              return CommentRecordModel.fromFirestore(doc);
            } catch (e) {
              debugPrint('❌ 문서 파싱 실패 - ID: ${doc.id}, 오류: $e');
              rethrow;
            }
          }).toList();

      debugPrint('✅ 모든 문서 파싱 완료 - 결과 수: ${results.length}');
      return results;
    } catch (e) {
      debugPrint('❌ Firestore 쿼리 실패 - photoId: $photoId');
      debugPrint('🔍 오류 타입: ${e.runtimeType}');
      debugPrint('🔍 오류 메시지: ${e.toString()}');

      if (e.toString().contains('PERMISSION_DENIED')) {
        debugPrint('🚫 권한 거부됨 - Firestore 보안 규칙을 확인하세요');
      } else if (e.toString().contains('FAILED_PRECONDITION')) {
        debugPrint('📊 인덱스 없음 - Firestore 인덱스를 생성하세요');
      }

      throw Exception('음성 댓글 조회 실패: $e');
    }
  }

  /// 음성 댓글 삭제 (soft delete)
  Future<void> deleteCommentRecord(String commentId) async {
    try {
      await _firestore.collection(_collectionName).doc(commentId).update({
        'isDeleted': true,
      });
    } catch (e) {
      throw Exception('음성 댓글 삭제 실패: $e');
    }
  }

  /// 음성 댓글 수정
  Future<CommentRecordModel> updateCommentRecord(
    CommentRecordModel commentRecord,
  ) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(commentRecord.id)
          .update(commentRecord.toFirestore());

      return commentRecord;
    } catch (e) {
      throw Exception('음성 댓글 수정 실패: $e');
    }
  }

  /// 사용자별 음성 댓글들 조회
  Future<List<CommentRecordModel>> getCommentRecordsByUser(
    String userId,
  ) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(_collectionName)
              .where('recorderUser', isEqualTo: userId)
              .where('isDeleted', isEqualTo: false)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => CommentRecordModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('사용자 음성 댓글 조회 실패: $e');
    }
  }

  /// 실시간 음성 댓글 스트림 (특정 사진)
  Stream<List<CommentRecordModel>> getCommentRecordsStream(String photoId) {
    return _firestore
        .collection(_collectionName)
        .where('photoId', isEqualTo: photoId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => CommentRecordModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// 프로필 이미지 위치 업데이트
  Future<void> updateProfilePosition({
    required String commentId,
    required Offset profilePosition,
  }) async {
    try {
      await _firestore.collection(_collectionName).doc(commentId).update({
        'profilePosition': {'dx': profilePosition.dx, 'dy': profilePosition.dy},
      });
    } catch (e) {
      throw Exception('프로필 위치 업데이트 실패: $e');
    }
  }
}
