import 'dart:io';
import 'dart:math' as math;
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
      debugPrint('🎵 오디오 파일 업로드 시작');
      debugPrint('  - 파일 경로: ${audioFile.path}');
      debugPrint('  - 카테고리 ID: $categoryId');
      debugPrint('  - 사용자 ID: $userId');

      // 파일 존재 확인
      if (!await audioFile.exists()) {
        debugPrint('❌ 오디오 파일이 존재하지 않습니다: ${audioFile.path}');
        return null;
      }

      // 파일 크기 확인
      final fileSize = await audioFile.length();
      debugPrint(
        '📊 오디오 파일 크기: ${fileSize} bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)',
      );

      if (fileSize == 0) {
        debugPrint('❌ 오디오 파일 크기가 0입니다');
        return null;
      }

      // 파일명 생성
      final fileName =
          customFileName ??
          '${categoryId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      debugPrint('📁 Storage 경로: audio/$categoryId/$fileName');

      // Storage 참조 생성
      final storageRef = _storage
          .ref()
          .child('audio')
          .child(categoryId)
          .child(fileName);

      debugPrint('☁️ Firebase Storage에 업로드 시작...');

      // 파일 업로드
      final uploadTask = storageRef.putFile(audioFile);

      // 업로드 진행률 모니터링
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress =
            (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint(
          '📤 업로드 진행률: ${progress.toStringAsFixed(1)}% (${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes)',
        );
      });

      final taskSnapshot = await uploadTask;
      debugPrint('✅ Firebase Storage 업로드 완료');

      // 다운로드 URL 가져오기
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      debugPrint('🔗 다운로드 URL: $downloadUrl');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('❌ 오디오 업로드 오류: $e');
      debugPrint('📍 스택 트레이스: $stackTrace');
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

      // 2. 카테고리에 사진이 처음 추가되는 경우, 자동으로 표지사진 설정
      final categoryDoc =
          await _firestore.collection('categories').doc(categoryId).get();
      if (categoryDoc.exists) {
        final categoryData = categoryDoc.data() as Map<String, dynamic>;
        if (categoryData['categoryPhotoUrl'] == null ||
            categoryData['categoryPhotoUrl'] == '') {
          await _firestore.collection('categories').doc(categoryId).update({
            'categoryPhotoUrl': photo.imageUrl,
          });
          debugPrint('✅ 첫 번째 사진을 카테고리 표지사진으로 자동 설정');
        }
      }

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
    List<double>? waveformData, // 파형 데이터 파라미터 추가
  }) async {
    try {
      debugPrint('🔄 파형 데이터와 함께 사진 저장 시작');
      debugPrint('📂 CategoryId: $categoryId');
      debugPrint('👤 UserID: $userID');
      debugPrint('🖼️ ImageUrl: $imageUrl');
      debugPrint('🎵 AudioUrl: $audioUrl');
      debugPrint('🌊 파형 데이터 상세 정보:');
      debugPrint('  - null 여부: ${waveformData == null}');
      debugPrint('  - 길이: ${waveformData?.length ?? 0}');
      if (waveformData != null && waveformData.isNotEmpty) {
        debugPrint('  - 첫 5개 값: ${waveformData.take(5).toList()}');
        debugPrint(
          '  - 마지막 5개 값: ${waveformData.length > 5 ? waveformData.sublist(waveformData.length - 5) : waveformData}',
        );
        debugPrint('  - 최대값: ${waveformData.reduce((a, b) => a > b ? a : b)}');
        debugPrint('  - 최소값: ${waveformData.reduce((a, b) => a < b ? a : b)}');
      }

      // 기본 데이터 구성
      final Map<String, dynamic> photoData = {
        'imageUrl': imageUrl,
        'audioUrl': audioUrl,
        'userID': userID,
        'userIds': userIds,
        'categoryId': categoryId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': PhotoStatus.active.name,
      };

      // 파형 데이터 처리 및 상세 로그
      if (waveformData != null && waveformData.isNotEmpty) {
        // 유효한 파형 데이터가 있는 경우
        photoData['waveformData'] = waveformData;
        debugPrint('✅ 유효한 파형 데이터를 Firestore에 저장');
        debugPrint('  - 저장할 데이터 타입: ${waveformData.runtimeType}');
        debugPrint('  - 저장할 데이터 길이: ${waveformData.length}');
      } else {
        // 파형 데이터가 없는 경우 빈 배열로 저장
        photoData['waveformData'] = [];
        debugPrint('⚠️ 파형 데이터가 없어서 빈 배열로 저장');
      }

      debugPrint('💾 Firestore에 사진 데이터 저장 시작...');
      debugPrint('  - 저장할 필드들: ${photoData.keys.toList()}');

      final docRef = await _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .add(photoData);

      debugPrint('✅ 사진 저장 완료 - PhotoId: ${docRef.id}');

      // 카테고리의 firstPhotoUrl 업데이트
      try {
        await _firestore.collection('categories').doc(categoryId).update({
          'firstPhotoUrl': imageUrl,
        });
        debugPrint('✅ 카테고리 firstPhotoUrl 업데이트 완료');
      } catch (e) {
        debugPrint('⚠️ 카테고리 firstPhotoUrl 업데이트 실패: $e');
      }

      return docRef.id;
    } catch (e, stackTrace) {
      debugPrint('❌ 사진 저장 실패: $e');
      debugPrint('📍 스택 트레이스: $stackTrace');
      rethrow;
    }
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
            debugPrint('Firestore 원본 데이터 - ID: ${doc.id}');
            debugPrint('  - UserID: ${data['userID']}');
            debugPrint(
              '  - waveformData 필드 존재: ${data.containsKey('waveformData')}',
            );
            debugPrint('  - waveformData 값: ${data['waveformData']}');
            debugPrint(
              '  - waveformData 타입: ${data['waveformData'].runtimeType}',
            );
            if (data['waveformData'] is List) {
              debugPrint(
                '  - waveformData 길이: ${(data['waveformData'] as List).length}',
              );
            }
            debugPrint(
              '  - AudioUrl 존재: ${data['audioUrl']?.isNotEmpty ?? false}',
            );

            return PhotoDataModel.fromFirestore(data, doc.id);
          }).toList();

      debugPrint('사진 조회 완료');
      return photos;
    } catch (e) {
      debugPrint('❌ 카테고리별 사진 조회 오류: $e');
      return [];
    }
  }

  /// 모든 카테고리에서 사진을 페이지네이션으로 조회 (무한 스크롤용)
  Future<({List<PhotoDataModel> photos, String? lastPhotoId, bool hasMore})>
  getPhotosFromAllCategoriesPaginated({
    required List<String> categoryIds,
    int limit = 20,
    String? startAfterPhotoId,
  }) async {
    try {
      debugPrint('🔍 페이지네이션 사진 조회 시작');
      debugPrint('  - 카테고리 개수: ${categoryIds.length}');
      debugPrint('  - 제한: $limit');
      debugPrint('  - 시작점: ${startAfterPhotoId ?? 'null'}');

      List<PhotoDataModel> allPhotos = [];

      // 모든 카테고리에서 사진을 가져와서 합치기
      for (String categoryId in categoryIds) {
        final categoryPhotos = await _getSingleCategoryPhotos(categoryId);
        allPhotos.addAll(categoryPhotos);
      }

      // 최신순으로 정렬
      allPhotos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // startAfterPhotoId가 있다면 해당 위치 이후부터 가져오기
      int startIndex = 0;
      if (startAfterPhotoId != null) {
        startIndex =
            allPhotos.indexWhere((photo) => photo.id == startAfterPhotoId) + 1;
        if (startIndex <= 0) startIndex = 0;
      }

      // 페이지네이션 적용
      final endIndex = (startIndex + limit).clamp(0, allPhotos.length);
      final paginatedPhotos = allPhotos.sublist(startIndex, endIndex);

      // 마지막 사진 ID와 더 있는지 여부 확인
      String? lastPhotoId;
      bool hasMore = endIndex < allPhotos.length;

      if (paginatedPhotos.isNotEmpty) {
        lastPhotoId = paginatedPhotos.last.id;
      }

      debugPrint('📊 페이지네이션 결과:');
      debugPrint('  - 전체 사진: ${allPhotos.length}개');
      debugPrint('  - 반환 사진: ${paginatedPhotos.length}개');
      debugPrint('  - 마지막 ID: $lastPhotoId');
      debugPrint('  - 더 있음: $hasMore');

      return (
        photos: paginatedPhotos,
        lastPhotoId: lastPhotoId,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('❌ 페이지네이션 사진 조회 오류: $e');
      return (photos: <PhotoDataModel>[], lastPhotoId: null, hasMore: false);
    }
  }

  /// 단일 카테고리에서 사진 조회 (내부 헬퍼 메서드)
  Future<List<PhotoDataModel>> _getSingleCategoryPhotos(
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
        return PhotoDataModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('❌ 카테고리 $categoryId 사진 조회 오류: $e');
      return [];
    }
  }

  /// 카테고리별 사진 목록 조회 (기존 호환성 유지)
  Future<List<PhotoDataModel>> getPhotosByCategoryLegacy(
    String categoryId,
  ) async {
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
            debugPrint('Firestore 원본 데이터 - ID: ${doc.id}');
            debugPrint('  - UserID: ${data['userID']}');
            debugPrint(
              '  - waveformData 필드 존재: ${data.containsKey('waveformData')}',
            );
            debugPrint('  - waveformData 값: ${data['waveformData']}');
            debugPrint(
              '  - waveformData 타입: ${data['waveformData'].runtimeType}',
            );
            if (data['waveformData'] is List) {
              debugPrint(
                '  - waveformData 길이: ${(data['waveformData'] as List).length}',
              );
            }
            debugPrint(
              '  - AudioUrl 존재: ${data['audioUrl']?.isNotEmpty ?? false}',
            );

            return PhotoDataModel.fromFirestore(data, doc.id);
          }).toList();

      debugPrint('사진 조회 완료');
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

  /// 파형 데이터 압축 (공개 메서드)
  List<double> compressWaveformData(
    List<double> data, {
    int targetLength = 100,
  }) {
    if (data.length <= targetLength) return data;

    final step = data.length / targetLength;
    final compressed = <double>[];

    for (int i = 0; i < targetLength; i++) {
      final startIndex = (i * step).floor();
      final endIndex = ((i + 1) * step).floor().clamp(0, data.length);

      // 구간 내 최대값 추출 (피크 보존)
      double maxValue = 0.0;
      for (int j = startIndex; j < endIndex; j++) {
        maxValue = math.max(maxValue, data[j].abs());
      }
      compressed.add(maxValue);
    }

    return compressed;
  }
}
