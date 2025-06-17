import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// 카테고리 관련 비즈니스 로직을 처리하는 Model 클래스
class CategoryModel {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 카테고리 데이터를 가져오는 함수
  Stream<List<Map<String, dynamic>>> streamUserCategories(String id) {
    return _firestore
        .collection('categories')
        .where('mates', arrayContains: id)
        .snapshots()
        .asyncMap((querySnapshot) async {
          final results = <Map<String, dynamic>>[];

          for (final doc in querySnapshot.docs) {
            final data = doc.data();
            final categoryId = doc.id;
            final mates = (data['mates'] as List).cast<String>();

            // 첫번째 사진 URL을 한 번만 Future로 가져오기
            final photosSnapshot =
                await _firestore
                    .collection('categories')
                    .doc(categoryId)
                    .collection('photos')
                    .orderBy('createdAt', descending: false)
                    .limit(1)
                    .get();

            String? firstPhotoUrl;
            if (photosSnapshot.docs.isNotEmpty) {
              firstPhotoUrl =
                  photosSnapshot.docs.first.data()['imageUrl'] as String?;
            }

            results.add({
              'id': categoryId,
              'name': data['name'],
              'mates': mates,
              'firstPhotoUrl': firstPhotoUrl,
            });
          }
          return results;
        });
  }

  /// 특정 카테고리 내의 photos 서브컬렉션에서
  /// 가장 이전(오래된) 사진의 URL을 가져오는 함수.
  Stream<String?> getFirstPhotoUrlStream(String categoryId) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return snapshot.docs.first.data()['imageUrl'] as String?;
          }
          return null;
        });
  }

  // 현재 로그인한 유저의 카테고리 정보를 가져오는 메소드
  Future<List<Map<String, dynamic>>> loadUserCategories(String uid) async {
    try {
      debugPrint('Loading categories for user: $uid');

      // 첫 번째 시도: userId가 배열인 경우 (새로운 방식)
      QuerySnapshot snapshot1 =
          await _firestore
              .collection('categories')
              .where('userId', arrayContains: uid)
              .get();

      // 두 번째 시도: userId가 문자열인 경우 (기존 방식)
      QuerySnapshot snapshot2 =
          await _firestore
              .collection('categories')
              .where('userId', isEqualTo: uid)
              .get();

      // 두 결과를 합치기
      List<QueryDocumentSnapshot> allDocs = [];
      allDocs.addAll(snapshot1.docs);
      allDocs.addAll(snapshot2.docs);

      // 중복 제거 (같은 document ID가 있을 수 있음)
      Map<String, QueryDocumentSnapshot> uniqueDocs = {};
      for (var doc in allDocs) {
        uniqueDocs[doc.id] = doc;
      }

      debugPrint('Found ${uniqueDocs.length} categories');

      return uniqueDocs.values.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '무제',
          'imageUrl': data['imageUrl'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('사용자 카테고리 로드 오류: $e');
      return []; // 오류 시 빈 리스트로 초기화
    }
  }

  /// 새 카테고리 생성
  Future<void> createCategory(String name, List mates, String userId) async {
    try {
      // 사용자 인증 상태 확인
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('사용자가 인증되지 않았습니다. 로그인이 필요합니다.');
      }

      debugPrint('Creating category with user: ${currentUser.uid}');

      await _firestore.collection('categories').add({
        'name': name,
        'mates': mates,
        'userId': [userId], // 배열로 저장하여 여러 사용자 지원
        'createdAt': Timestamp.now(),
        'photoCount': 0, // Initialize photoCount
      });

      debugPrint('Category created successfully');
    } catch (e) {
      debugPrint('Error creating category: $e');
      rethrow;
    }
  }

  /// 카테고리에 사용자 닉네임 추가
  Future<void> addUserToCategory(String categoryId, String id) async {
    await _updateCategoryField(categoryId, 'mates', id);
  }

  /// 카테고리에 사용자 UID 추가
  Future<void> addUidToCategory(String categoryId, String uid) async {
    await _updateCategoryField(categoryId, 'userId', uid);
  }

  /// 카테고리의 특정 필드에 배열 형태로 값 업데이트 (헬퍼 함수)
  Future<void> _updateCategoryField(
    String categoryId,
    String field,
    String value,
  ) async {
    try {
      final categoryRef = _firestore.collection('categories').doc(categoryId);
      await categoryRef.update({
        field: FieldValue.arrayUnion([value]),
      });
    } catch (e) {
      debugPrint('카테고리 필드 업데이트 오류: $e');
      rethrow;
    }
  }

  /// 특정 카테고리의 사진 목록(스트림) 가져오기
  Stream<List<Map<String, dynamic>>> getPhotosStream(String categoryId) {
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
                return {
                  'id': doc.id,
                  'imageUrl': data['imageUrl'] ?? '',
                  'audioUrl': data['audioUrl'] ?? '',
                  'createdAt': data['createdAt'],
                  'userId': data['userID'] ?? '',
                };
              }).toList(),
        );
  }

  /// 모든 카테고리 데이터를 가져오면서
  /// 각 카테고리의 첫번째 사진 URL과 프로필 이미지들을 함께 합친 스트림
  Stream<List<Map<String, dynamic>>> streamUserCategoriesWithDetails(
    String id,
    Stream<List<String>> Function(List<dynamic>) getProfileImagesCallback,
  ) {
    return _firestore
        .collection('categories')
        .where('mates', arrayContains: id)
        .snapshots()
        .asyncMap((querySnapshot) async {
          final results = <Map<String, dynamic>>[];

          for (final doc in querySnapshot.docs) {
            final data = doc.data();
            final categoryId = doc.id;
            final mates = (data['mates'] as List).cast<String>();

            // 첫번째 사진 URL을 한 번만 Future로 가져오기
            final photosSnapshot =
                await _firestore
                    .collection('categories')
                    .doc(categoryId)
                    .collection('photos')
                    .orderBy('createdAt', descending: false)
                    .limit(1)
                    .get();

            String? firstPhotoUrl;
            if (photosSnapshot.docs.isNotEmpty) {
              firstPhotoUrl =
                  photosSnapshot.docs.first.data()['imageUrl'] as String?;
            }

            // mates에 해당하는 프로필 이미지 목록 가져오기 (한 번만 Future로 처리)
            var profileImages = <String>[];
            if (mates.isNotEmpty) {
              // mates 리스트에 대한 프로필 이미지만 가져오도록 수정
              final completer = Completer<List<String>>();
              final subscription = getProfileImagesCallback(mates).listen(
                (urls) {
                  // 가져온 프로필 이미지 중에서 mates에 속한 사용자의 이미지만 필터링
                  completer.complete(urls);
                },
                onError: (e) {
                  completer.completeError(e);
                },
              );
              profileImages = await completer.future.whenComplete(
                () => subscription.cancel(),
              );
            }

            results.add({
              'id': categoryId,
              'name': data['name'],
              'mates': mates,
              'firstPhotoUrl': firstPhotoUrl,
              'profileImages': profileImages,
            });
          }
          return results;
        });
  }

  /// 이미지 업로드
  Future<String?> uploadPhotoStorage(File imageFile) async {
    try {
      // 파일 존재 여부 확인
      if (!await imageFile.exists()) {
        debugPrint('이미지 파일이 존재하지 않습니다: ${imageFile.path}');
        throw Exception('Image file does not exist: ${imageFile.path}');
      }

      // 이미지 읽기 가능 여부 확인
      try {
        await imageFile.readAsBytes();
      } catch (e) {
        debugPrint('이미지 파일을 읽을 수 없습니다: $e');
        throw Exception('Cannot read image file: $e');
      }

      // 이미지 색상 보정 (Flutter에서)
      final img = await decodeImageFromList(imageFile.readAsBytesSync());
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint =
          Paint()
            ..colorFilter = const ColorFilter.mode(
              Colors.transparent, // 녹색 색조 제거를 위한 설정
              BlendMode.overlay,
            );
      canvas.drawImage(img, Offset.zero, paint);

      // 처리된 이미지 저장
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = _storage.ref().child('categories_photos/$fileName');

      // 파일 업로드
      await ref.putFile(imageFile);

      // 다운로드 URL 가져오기
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("이미지 업로드 오류: $e");
      return null;
    }
  }

  /// 사진 업로드 (Firestore)
  Future<void> uploadPhoto(
    String categoryId,
    String userId,
    String filePath,
    String audioUrl, {
    String? imageUrl, // 이미 있는 이미지 URL을 위한 선택적 매개변수 추가
  }) async {
    String downloadUrl;

    // 이미지 URL이 이미 제공된 경우 그것을 사용
    if (imageUrl != null && imageUrl.isNotEmpty) {
      downloadUrl = imageUrl;
    } else {
      // filePath가 비어있지 않은 경우에만 이미지 업로드 시도
      if (filePath.isNotEmpty) {
        File imageFile = File(filePath);
        String? uploadedUrl = await uploadPhotoStorage(imageFile);
        if (uploadedUrl == null) {
          debugPrint('Failed to upload photo to storage.');
          return; // 업로드 실패 시 함수 종료
        }
        downloadUrl = uploadedUrl;
      } else {
        debugPrint('No image file path provided and no existing image URL.');
        return; // 이미지 경로도 없고 기존 URL도 없는 경우
      }
    }

    try {
      final categoryRef = _firestore.collection('categories').doc(categoryId);
      final photosCollection = categoryRef.collection('photos');

      await photosCollection.add({
        'userId': userId,
        'imageUrl': downloadUrl,
        'audioUrl': audioUrl,
        'createdAt': Timestamp.now(),
      });

      // Increment photoCount in the category document
      await categoryRef.update({'photoCount': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('Error uploading photo to Firestore: $e');
      rethrow;
    }
  }

  /// 특정 사진의 오디오 URL 가져오기
  Future<String?> getPhotoAudioUrl(String categoryId, String photoId) async {
    try {
      final doc =
          await _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('photos')
              .doc(photoId)
              .get();
      return doc['audioUrl'] as String?;
    } catch (e) {
      debugPrint('오디오 URL 가져오기 오류: $e');
      return null;
    }
  }

  /// 모든 카테고리의 사진 통계를 가져오기
  Future<Map<String, int>> fetchCategoryStatistics() async {
    final categoriesSnapshot = await _firestore.collection('categories').get();
    return _getCategoryStats(categoriesSnapshot);
  }

  /// 저장된 사진이 가장 적은 카테고리의 'name' 가져오기
  Future<String?> getLeastSavedCategory() async {
    final categoriesSnapshot = await _firestore.collection('categories').get();
    final categoryStats = await _getCategoryStats(categoriesSnapshot);
    if (categoryStats.isEmpty) return null;

    final leastSavedCategoryId =
        categoryStats.entries.reduce((a, b) => a.value < b.value ? a : b).key;

    final categoryDoc =
        await _firestore
            .collection('categories')
            .doc(leastSavedCategoryId)
            .get();
    return categoryDoc.exists ? categoryDoc.data()!['name'] as String? : null;
  }

  /// 각 카테고리의 사진 개수 계산 (헬퍼 함수)
  Future<Map<String, int>> _getCategoryStats(
    QuerySnapshot categoriesSnapshot,
  ) async {
    final Map<String, int> categoryStats = {};
    for (final categoryDoc in categoriesSnapshot.docs) {
      final data = categoryDoc.data() as Map<String, dynamic>?;
      // Read photoCount directly from the category document
      categoryStats[categoryDoc.id] = data?['photoCount'] as int? ?? 0;
    }
    return categoryStats;
  }

  /// 특정 카테고리의 이름 가져오기
  Future<String> getCategoryName(String categoryId) async {
    try {
      final doc =
          await _firestore.collection('categories').doc(categoryId).get();
      if (!doc.exists) {
        throw Exception('해당 카테고리가 존재하지 않습니다.');
      }
      return doc['name'] as String;
    } catch (e) {
      debugPrint('카테고리 이름 가져오기 오류: $e');
      rethrow;
    }
  }

  /// 특정 사진 문서의 ID 가져오기
  Future<String?> getPhotoDocumentId(String categoryId, String imageUrl) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('photos')
              .where('imageUrl', isEqualTo: imageUrl)
              .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting photo document ID: $e');
      return null;
    }
  }
}
