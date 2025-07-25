import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/category_data_model.dart';

/// Firebase에서 category 관련 데이터를 가져오고, 저장하고, 업데이트하고 삭제하는 등의 로직들
class CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ==================== Firestore 관련 ====================

  /// 사용자의 카테고리 목록을 스트림으로 가져오기
  Stream<List<CategoryDataModel>> getUserCategoriesStream(String userId) {
    return _firestore
        .collection('categories')
        .where('mates', arrayContains: userId)
        .snapshots()
        .asyncMap((querySnapshot) async {
          final categories = <CategoryDataModel>[];

          for (final doc in querySnapshot.docs) {
            final data = doc.data();

            // 첫 번째 사진 URL과 사진 개수를 가져오기
            final photosSnapshot =
                await _firestore
                    .collection('categories')
                    .doc(doc.id)
                    .collection('photos')
                    .orderBy('createdAt', descending: true)
                    .limit(1)
                    .get();

            final photoCountSnapshot =
                await _firestore
                    .collection('categories')
                    .doc(doc.id)
                    .collection('photos')
                    .count()
                    .get();

            String? firstPhotoUrl;
            if (photosSnapshot.docs.isNotEmpty) {
              firstPhotoUrl =
                  photosSnapshot.docs.first.data()['imageUrl'] as String?;
            }

            final category = CategoryDataModel.fromFirestore(
              data,
              doc.id,
            ).copyWith(
              firstPhotoUrl: firstPhotoUrl,
              photoCount: photoCountSnapshot.count ?? 0,
            );

            categories.add(category);
          }

          return categories;
        });
  }

  /// 사용자의 카테고리 목록을 한 번만 가져오기
  Future<List<CategoryDataModel>> getUserCategories(String userId) async {
    debugPrint('🔍 CategoryRepository: Firestore 쿼리 시작... userId=$userId');
    debugPrint('🔍 사용자 ID 길이: ${userId.length}, 비어있음: ${userId.isEmpty}');

    // 먼저 Firebase Auth UID로 검색
    debugPrint('🔍 1단계: UID로 카테고리 검색 시작...');
    var querySnapshot =
        await _firestore
            .collection('categories')
            .where('mates', arrayContains: userId)
            .get();

    debugPrint('🔍 1단계 결과: UID로 검색된 문서 수: ${querySnapshot.docs.length}');

    // 쿼리 결과가 있으면 각 문서의 mates 배열을 확인
    if (querySnapshot.docs.isNotEmpty) {
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        debugPrint('🔍 문서 ${doc.id}의 mates: ${data['mates']}');
      }
    }

    // 만약 UID로 찾은 결과가 없다면, 사용자 닉네임으로도 검색해보기
    if (querySnapshot.docs.isEmpty) {
      try {
        debugPrint('🔍 2단계: 닉네임으로 추가 검색 시작...');
        // 사용자 문서에서 닉네임 가져오기
        final userDoc = await _firestore.collection('users').doc(userId).get();
        debugPrint('🔍 사용자 문서 존재 여부: ${userDoc.exists}');

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          debugPrint('🔍 사용자 문서 데이터: $userData');
          final nickName = userData['id'] as String?; // 'id' 필드에 닉네임이 저장됨

          if (nickName != null && nickName.isNotEmpty) {
            debugPrint('🔍 닉네임으로 추가 검색... nickName=$nickName');

            querySnapshot =
                await _firestore
                    .collection('categories')
                    .where('mates', arrayContains: nickName)
                    .get();

            debugPrint(
              '🔍 2단계 결과: 닉네임으로 검색된 문서 수: ${querySnapshot.docs.length}',
            );

            // 닉네임 검색 결과도 확인
            if (querySnapshot.docs.isNotEmpty) {
              for (var doc in querySnapshot.docs) {
                final data = doc.data();
                debugPrint('🔍 문서 ${doc.id}의 mates: ${data['mates']}');
              }
            }
          } else {
            debugPrint('🔍 사용자 문서에서 닉네임을 찾을 수 없음');
          }
        }
      } catch (e) {
        debugPrint('🔍 닉네임 검색 중 오류: $e');
      }
    } else {
      debugPrint('🔍 UID 검색에서 결과를 찾았으므로 닉네임 검색 생략');
    }

    final categories = <CategoryDataModel>[];

    for (final doc in querySnapshot.docs) {
      debugPrint('CategoryRepository: 문서 처리 중... docId=${doc.id}');
      final data = doc.data();
      debugPrint('CategoryRepository: 문서 데이터: $data');

      // 첫 번째 사진 URL과 사진 개수를 가져오기
      final photosSnapshot =
          await _firestore
              .collection('categories')
              .doc(doc.id)
              .collection('photos')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

      final photoCountSnapshot =
          await _firestore
              .collection('categories')
              .doc(doc.id)
              .collection('photos')
              .count()
              .get();

      String? firstPhotoUrl;
      if (photosSnapshot.docs.isNotEmpty) {
        firstPhotoUrl = photosSnapshot.docs.first.data()['imageUrl'] as String?;
      }

      final category = CategoryDataModel.fromFirestore(data, doc.id).copyWith(
        firstPhotoUrl: firstPhotoUrl,
        photoCount: photoCountSnapshot.count ?? 0,
      );

      categories.add(category);
    }

    return categories;
  }

  /// 카테고리 생성
  Future<String> createCategory(CategoryDataModel category) async {
    final docRef = await _firestore
        .collection('categories')
        .add(category.toFirestore());
    return docRef.id;
  }

  /// 카테고리 업데이트
  Future<void> updateCategory(
    String categoryId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('categories').doc(categoryId).update(data);
  }

  /// 카테고리 삭제
  Future<void> deleteCategory(String categoryId) async {
    // 카테고리와 관련된 모든 사진도 삭제
    final photosSnapshot =
        await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('photos')
            .get();

    final batch = _firestore.batch();

    // 사진 문서들 삭제
    for (final doc in photosSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // 카테고리 문서 삭제
    batch.delete(_firestore.collection('categories').doc(categoryId));

    await batch.commit();
  }

  /// 특정 카테고리 정보 가져오기
  Future<CategoryDataModel?> getCategory(String categoryId) async {
    final doc = await _firestore.collection('categories').doc(categoryId).get();

    if (!doc.exists || doc.data() == null) return null;

    // 첫 번째 사진 URL과 사진 개수를 가져오기
    final photosSnapshot =
        await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('photos')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

    final photoCountSnapshot =
        await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('photos')
            .count()
            .get();

    String? firstPhotoUrl;
    if (photosSnapshot.docs.isNotEmpty) {
      firstPhotoUrl = photosSnapshot.docs.first.data()['imageUrl'] as String?;
    }

    return CategoryDataModel.fromFirestore(doc.data()!, doc.id).copyWith(
      firstPhotoUrl: firstPhotoUrl,
      photoCount: photoCountSnapshot.count ?? 0,
    );
  }

  /// 카테고리에게 사진 추가
  Future<String> addPhotoToCategory(
    String categoryId,
    Map<String, dynamic> photoData,
  ) async {
    final docRef = await _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .add(photoData);
    return docRef.id;
  }

  /// 카테고리에서 사진 삭제
  Future<void> removePhotoFromCategory(
    String categoryId,
    String photoId,
  ) async {
    await _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .doc(photoId)
        .delete();
  }

  /// 카테고리의 사진들 가져오기
  Future<List<Map<String, dynamic>>> getCategoryPhotos(
    String categoryId,
  ) async {
    final querySnapshot =
        await _firestore
            .collection('categories')
            .doc(categoryId)
            .collection('photos')
            .orderBy('createdAt', descending: true)
            .get();

    return querySnapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();
  }

  // ==================== Storage 관련 ====================

  /// 이미지 업로드
  Future<String> uploadImage(String categoryId, File imageFile) async {
    final fileName =
        'category_${categoryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage
        .ref()
        .child('categories')
        .child(categoryId)
        .child(fileName);

    final uploadTask = ref.putFile(imageFile);
    final snapshot = await uploadTask.whenComplete(() => null);

    return await snapshot.ref.getDownloadURL();
  }

  /// 이미지 삭제
  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // 이미지가 이미 삭제되었거나 존재하지 않는 경우 무시
      print('이미지 삭제 실패: $e');
    }
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 카테고리 사진 스트림 (Map 형태로 반환)
  Stream<List<Map<String, dynamic>>> getCategoryPhotosStream(
    String categoryId,
  ) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              }).toList(),
        );
  }

  /// 카테고리에 사용자 추가 (닉네임으로)
  Future<void> addUserToCategory({
    required String categoryId,
    required String nickName,
  }) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'mates': FieldValue.arrayUnion([nickName]),
    });
  }

  /// 카테고리에 사용자 추가 (UID로)
  Future<void> addUidToCategory({
    required String categoryId,
    required String uid,
  }) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'userIds': FieldValue.arrayUnion([uid]),
    });
  }
}
