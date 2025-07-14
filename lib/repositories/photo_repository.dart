import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/photo_data_model.dart';

/// Photo Repository - Firebase와 관련된 모든 데이터 액세스 로직을 담당
class PhotoRepository {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==================== 사진 업로드 ====================

  /// 이미지 파일을 Firebase Storage에 업로드
  Future<String?> uploadImageToStorage({
    required File imageFile,
    required String categoryId,
    required String userId,
    String? customFileName,
  }) async {
    try {
      final fileName =
          customFileName ??
          '${categoryId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final storageRef = _storage
          .ref()
          .child('photos')
          .child(categoryId)
          .child(fileName);

      final uploadTask = await storageRef.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('이미지 업로드 오류: $e');
      return null;
    }
  }

  /// 오디오 파일을 Firebase Storage에 업로드
  Future<String?> uploadAudioToStorage({
    required File audioFile,
    required String categoryId,
    required String userId,
    String? customFileName,
  }) async {
    try {
      final fileName =
          customFileName ??
          '${categoryId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final storageRef = _storage
          .ref()
          .child('audio')
          .child(categoryId)
          .child(fileName);

      final uploadTask = await storageRef.putFile(audioFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('오디오 업로드 오류: $e');
      return null;
    }
  }

  /// 사진 메타데이터를 Firestore에 저장
  Future<String?> savePhotoToFirestore({
    required PhotoDataModel photo,
    required String categoryId,
  }) async {
    try {
      // 1. 사진 저장
      final docRef = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .add(photo.toFirestore());

      // 2. 카테고리의 firstPhotoUrl 업데이트(최신 사진으로)
      await _firestore.collection('categories').doc(categoryId).update({
        'firstPhotoUrl': photo.imageUrl,
      });

      return docRef.id;
    } catch (e) {
      debugPrint('사진 메타데이터 저장 오류: $e');
      return null;
    }
  }

  /// 사진 데이터와 파형 데이터 함께 저장
  Future<String> savePhotoWithWaveform({
    required String imageUrl,
    required String audioUrl,
    required String userID,
    required List<String> userIds,
    required String categoryId,
  }) async {
    try {
      debugPrint('💾 파형 데이터와 함께 사진 저장 시작');
      debugPrint('📂 CategoryId: $categoryId');

      final docRef = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .add({
            'imageUrl': imageUrl,
            'audioUrl': audioUrl,
            'userID': userID,
            'userIds': userIds,
            'categoryId': categoryId,
            'createdAt': FieldValue.serverTimestamp(),
            'status': PhotoStatus.active.name,
          });

      debugPrint('✅ 사진 저장 완료 - PhotoId: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ 사진 저장 실패: $e');
      rethrow;
    }
  }

  /// 기존 사진에 파형 데이터 업데이트
  Future<void> updatePhotoWaveform({
    required String photoId,
    required List<double> waveformData,
    required double audioDuration,
  }) async {
    await _firestore.collection('photos').doc(photoId).update({
      'waveformData': waveformData,
      'audioDuration': audioDuration,
    });
  }

  // ==================== 사진 조회 ====================

  /// 카테고리별 사진 목록 조회
  Future<List<PhotoDataModel>> getPhotosByCategory(String categoryId) async {
    try {
      debugPrint('🔍 카테고리별 사진 조회 시작 - CategoryId: $categoryId');

      final querySnapshot =
          await _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('photos')
              .where('status', isEqualTo: PhotoStatus.active.name)
              .orderBy('createdAt', descending: true)
              .get();

      debugPrint('📊 조회된 사진 개수: ${querySnapshot.docs.length}');

      final photos =
          querySnapshot.docs.map((doc) {
            final data = doc.data();
            debugPrint('📸 사진 데이터: ${doc.id}');
            debugPrint('  - UserID: ${data['userID']}');
            debugPrint(
              '  - WaveformData: ${data['waveformData']?.length ?? 0} samples',
            );
            debugPrint(
              '  - AudioUrl: ${data['audioUrl']?.isNotEmpty ?? false}',
            );

            return PhotoDataModel.fromFirestore(data, doc.id);
          }).toList();

      debugPrint('✅ 사진 조회 완료');
      return photos;
    } catch (e) {
      debugPrint('❌ 카테고리별 사진 조회 오류: $e');
      return [];
    }
  }

  /// 카테고리별 사진 목록 스트림
  Stream<List<PhotoDataModel>> getPhotosByCategoryStream(String categoryId) {
    debugPrint('🔄 카테고리별 사진 스트림 시작 - CategoryId: $categoryId');

    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .where('status', isEqualTo: PhotoStatus.active.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint('📺 스트림 업데이트 - 사진 개수: ${snapshot.docs.length}');

          return snapshot.docs.map((doc) {
            final data = doc.data();
            debugPrint('📸 스트림 사진: ${doc.id}');
            debugPrint('  - UserID: ${data['userID']}');
            debugPrint(
              '  - WaveformData: ${data['waveformData']?.length ?? 0} samples',
            );
            debugPrint(
              '  - AudioUrl: ${data['audioUrl']?.isNotEmpty ?? false}',
            );

            return PhotoDataModel.fromFirestore(data, doc.id);
          }).toList();
        });
  }

  /// 사용자별 사진 목록 조회
  Future<List<PhotoDataModel>> getPhotosByUser(String userId) async {
    try {
      final querySnapshot =
          await _firestore
              .collectionGroup('photos')
              .where('userID', isEqualTo: userId)
              .where('status', isEqualTo: PhotoStatus.active.name)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => PhotoDataModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('사용자별 사진 조회 오류: $e');
      return [];
    }
  }

  /// 특정 사진 조회
  Future<PhotoDataModel?> getPhotoById({
    required String categoryId,
    required String photoId,
  }) async {
    try {
      final doc =
          await _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('photos')
              .doc(photoId)
              .get();

      if (doc.exists && doc.data() != null) {
        return PhotoDataModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('사진 조회 오류: $e');
      return null;
    }
  }

  // ==================== 사진 업데이트 ====================

  /// 사진 정보 업데이트
  Future<bool> updatePhoto({
    required String categoryId,
    required String photoId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      updates['updatedAt'] = Timestamp.now();

      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId)
          .update(updates);

      return true;
    } catch (e) {
      debugPrint('사진 업데이트 오류: $e');
      return false;
    }
  }

  /// 사진 좋아요 토글
  Future<bool> togglePhotoLike({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    try {
      final docRef = _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId);

      return await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) return false;

        final data = doc.data()!;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        final currentLikeCount = data['likeCount'] ?? 0;

        if (likedBy.contains(userId)) {
          // 좋아요 취소
          likedBy.remove(userId);
          transaction.update(docRef, {
            'likedBy': likedBy,
            'likeCount': currentLikeCount - 1,
            'updatedAt': Timestamp.now(),
          });
        } else {
          // 좋아요 추가
          likedBy.add(userId);
          transaction.update(docRef, {
            'likedBy': likedBy,
            'likeCount': currentLikeCount + 1,
            'updatedAt': Timestamp.now(),
          });
        }

        return true;
      });
    } catch (e) {
      debugPrint('사진 좋아요 토글 오류: $e');
      return false;
    }
  }

  /// 사진 조회수 증가
  Future<bool> incrementPhotoViewCount({
    required String categoryId,
    required String photoId,
  }) async {
    try {
      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId)
          .update({
            'viewCount': FieldValue.increment(1),
            'updatedAt': Timestamp.now(),
          });

      return true;
    } catch (e) {
      debugPrint('사진 조회수 증가 오류: $e');
      return false;
    }
  }

  // ==================== 사진 삭제 ====================

  /// 사진 삭제 (soft delete)
  Future<bool> deletePhoto({
    required String categoryId,
    required String photoId,
  }) async {
    try {
      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId)
          .update({
            'status': PhotoStatus.deleted.name,
            'updatedAt': Timestamp.now(),
          });

      return true;
    } catch (e) {
      debugPrint('사진 삭제 오류: $e');
      return false;
    }
  }

  /// 사진 완전 삭제 (하드 삭제)
  Future<bool> permanentDeletePhoto({
    required String categoryId,
    required String photoId,
    String? imageUrl,
    String? audioUrl,
  }) async {
    try {
      // Firestore 문서 삭제
      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId)
          .delete();

      // Storage 파일 삭제
      if (imageUrl != null) {
        await _deleteStorageFile(imageUrl);
      }
      if (audioUrl != null) {
        await _deleteStorageFile(audioUrl);
      }

      return true;
    } catch (e) {
      debugPrint('사진 완전 삭제 오류: $e');
      return false;
    }
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 기존 PhotoModel과의 호환성을 위한 메서드
  Future<List<Map<String, dynamic>>> getCategoryPhotosAsMap(
    String categoryId,
  ) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('photos')
              .where('status', isEqualTo: PhotoStatus.active.name)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('카테고리 사진 맵 조회 오류: $e');
      return [];
    }
  }

  /// 기존 PhotoModel과의 호환성을 위한 스트림
  Stream<List<Map<String, dynamic>>> getCategoryPhotosStreamAsMap(
    String categoryId,
  ) {
    debugPrint('🔄 [호환성] 카테고리별 사진 Map 스트림 시작 - CategoryId: $categoryId');

    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .where('status', isEqualTo: PhotoStatus.active.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint('📺 [호환성] 스트림 업데이트 - 사진 개수: ${snapshot.docs.length}');

          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;

            debugPrint('📸 [호환성] 스트림 사진: ${doc.id}');
            debugPrint('  - UserID: ${data['userID']}');
            debugPrint(
              '  - WaveformData: ${data['waveformData']?.length ?? 0} samples',
            );
            debugPrint(
              '  - AudioUrl: ${data['audioUrl']?.isNotEmpty ?? false}',
            );

            return data;
          }).toList();
        });
  }

  // ==================== 유틸리티 메서드 ====================

  /// Storage 파일 삭제
  Future<void> _deleteStorageFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('Storage 파일 삭제 오류: $e');
    }
  }

  /// 현재 사용자 ID 가져오기
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// 사진 통계 조회
  Future<Map<String, int>> getPhotoStats(String categoryId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('photos')
              .get();

      int totalPhotos = 0;
      int activePhotos = 0;
      int deletedPhotos = 0;

      for (final doc in querySnapshot.docs) {
        totalPhotos++;
        final status = doc.data()['status'] ?? PhotoStatus.active.name;
        if (status == PhotoStatus.active.name) {
          activePhotos++;
        } else if (status == PhotoStatus.deleted.name) {
          deletedPhotos++;
        }
      }

      return {
        'total': totalPhotos,
        'active': activePhotos,
        'deleted': deletedPhotos,
      };
    } catch (e) {
      debugPrint('사진 통계 조회 오류: $e');
      return {'total': 0, 'active': 0, 'deleted': 0};
    }
  }

  /// 기존 사진들에 파형 데이터 일괄 추가 (유틸리티)
  Future<void> addWaveformDataToExistingPhotos({
    required String categoryId,
    required Function(String audioUrl) extractWaveformData,
  }) async {
    try {
      debugPrint('🔧 기존 사진들에 파형 데이터 추가 시작 - CategoryId: $categoryId');

      final querySnapshot =
          await _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('photos')
              .where('status', isEqualTo: PhotoStatus.active.name)
              .where('audioUrl', isNotEqualTo: '')
              .get();

      debugPrint('🎵 오디오가 있는 사진 개수: ${querySnapshot.docs.length}');

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final audioUrl = data['audioUrl'] as String?;
        final existingWaveform = data['waveformData'] as List?;

        // 이미 파형 데이터가 있으면 스킵
        if (existingWaveform != null && existingWaveform.isNotEmpty) {
          debugPrint('⏭️ 파형 데이터 이미 존재: ${doc.id}');
          continue;
        }

        if (audioUrl != null && audioUrl.isNotEmpty) {
          debugPrint('🌊 파형 데이터 추출 중: ${doc.id}');

          try {
            // 파형 데이터 추출 (외부에서 전달받은 함수 사용)
            final waveformData = await extractWaveformData(audioUrl);

            if (waveformData.isNotEmpty) {
              // Firestore 업데이트
              await doc.reference.update({
                'waveformData': waveformData,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              debugPrint(
                '✅ 파형 데이터 추가 완료: ${doc.id} (${waveformData.length} samples)',
              );
            } else {
              debugPrint('⚠️ 파형 데이터 추출 실패: ${doc.id}');
            }
          } catch (e) {
            debugPrint('❌ 파형 데이터 추출 오류 (${doc.id}): $e');
          }
        }
      }

      debugPrint('🎉 기존 사진들에 파형 데이터 추가 완료');
    } catch (e) {
      debugPrint('❌ 파형 데이터 일괄 추가 실패: $e');
      rethrow;
    }
  }

  /// 특정 사진에 파형 데이터 추가
  Future<bool> addWaveformDataToPhoto({
    required String categoryId,
    required String photoId,
    required List<double> waveformData,
    double? audioDuration,
  }) async {
    try {
      debugPrint('🌊 사진에 파형 데이터 추가: $photoId');

      final updateData = <String, dynamic>{
        'waveformData': waveformData,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (audioDuration != null) {
        updateData['audioDuration'] = audioDuration;
      }

      await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId)
          .update(updateData);

      debugPrint('✅ 파형 데이터 추가 완료: $photoId (${waveformData.length} samples)');
      return true;
    } catch (e) {
      debugPrint('❌ 파형 데이터 추가 실패: $e');
      return false;
    }
  }
}
