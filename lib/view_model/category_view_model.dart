import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../model/photo_model.dart';
import 'audio_view_model.dart';
import 'auth_view_model.dart';

class CategoryViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final List<String> _selectedNames = [];
  List<Map<String, dynamic>> _userCategories = []; // 사용자 카테고리 저장 리스트

  List<String> get selectedNames => _selectedNames;
  List<Map<String, dynamic>> get userCategories =>
      _userCategories; // 카테고리 getter 추가

  String audioUrl = '';

  // 현재 로그인한 유저의 카테고리 정보를 가져오는 메소드
  Future<void> loadUserCategories(String uid) async {
    try {
      // Firestore에서 현재 사용자의 카테고리 가져오기
      final snapshot =
          await _firestore
              .collection('categories')
              .where('userId', arrayContains: uid)
              .get();

      _userCategories =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '무제',
              'imageUrl': data['imageUrl'] ?? '',
            };
          }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('사용자 카테고리 로드 오류: $e');
      _userCategories = []; // 오류 시 빈 리스트로 초기화
      notifyListeners();
    }
  }

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

  /// 카테고리에 속한 mates들의 프로필 이미지를 가져오는 함수
  Future<List<String>> getCategoryProfileImages(
    List<String> mates,
    AuthViewModel authViewModel,
  ) async {
    if (mates.isEmpty) {
      return [];
    }

    // mates 리스트에 대한 프로필 이미지만 가져오도록 수정
    final completer = Completer<List<String>>();
    final subscription = authViewModel
        .getprofileImages(mates)
        .listen(
          (urls) {
            completer.complete(urls.cast<String>());
          },
          onError: (e) {
            completer.completeError(e);
          },
        );

    return completer.future.whenComplete(() => subscription.cancel());
  }

  /// 모든 카테고리 데이터를 가져오면서
  /// 각 카테고리의 첫번째 사진 URL과 프로필 이미지들을 함께 합친 스트림
  Stream<List<Map<String, dynamic>>> streamUserCategoriesWithDetails(
    String id,
    AuthViewModel authViewModel,
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
              final subscription = authViewModel
                  .getprofileImages(mates)
                  .listen(
                    (urls) {
                      // 가져온 프로필 이미지 중에서 mates에 속한 사용자의 이미지만 필터링
                      completer.complete(urls.cast<String>());
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

  //// filepath: /Users/mac/Documents/planner_app/lib/view_model/category_view_model.dart
  /// 특정 카테고리 내의 photos 서브컬렉션에서
  /// 가장 이전(오래된) 사진의 URL을 가져오는 함수.
  /// createdAt 필드를 기준으로 오름차순 정렬하여 첫 번째 사진의 imageUrl을 반환합니다.
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

  void toggleName(String name) {
    if (_selectedNames.contains(name)) {
      _selectedNames.remove(name);
    } else {
      _selectedNames.add(name);
    }
    notifyListeners();
  }

  void clearSelectedNames() {
    _selectedNames.clear();
    notifyListeners();
  }

  Future<void> saveEditedPhoto(
    Future<ui.Image> capturedImageFuture,
    String categoryId,
    String id,
    String? audioFilePath,
    AudioViewModel audioViewModel,
    String captionString,
  ) async {
    try {
      // 캡처된 이미지 Future 완료
      final capturedImage = await capturedImageFuture;
      final byteData = await capturedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      // 임시 디렉토리에 파일 저장
      final appDir = await getApplicationDocumentsDirectory();
      final filePath =
          '${appDir.path}/${DateTime.now().millisecondsSinceEpoch}_edited.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // 음성 파일 처리 (있다면)

      if (audioFilePath != null) {
        // 예시: AudioViewModel에 있는 업로드 함수를 사용하거나 여기서 직접 업로드
        audioUrl = await audioViewModel.uploadAudioToFirestorage();
      }

      // 사진 업로드 (context 의존성이 제거된 uploadPhoto로 처리)
      await uploadPhoto(categoryId, id, filePath, audioUrl);
    } catch (e) {
      debugPrint('Error saving edited photo: $e');
    }
  }

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

  /// uploadPhoto의 context 매개변수를 제거하여 UI와 분리한 버전
  Future<void> uploadPhoto(
    String categoryId,
    String id,
    String filePath,
    String audioUrl, {
    String? imageUrl, // 이미 있는 이미지 URL을 위한 선택적 매개변수 추가
  }) async {
    String downloadUrl;

    // 이미지 URL이 이미 제공된 경우 그것을 사용
    if (imageUrl != null && imageUrl.isNotEmpty) {
      downloadUrl = imageUrl;
    } else {
      // 파일 경로로부터 이미지 업로드
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final file = File(filePath);

      if (!file.existsSync()) {
        debugPrint('File does not exist: $filePath');
        return;
      }

      try {
        // 1) Firebase Storage 업로드
        final ref = _storage.ref().child('categories_photos/$fileName');
        await ref.putFile(file);
        downloadUrl = await ref.getDownloadURL();
      } catch (e) {
        debugPrint('Error uploading photo to storage: $e');
        rethrow;
      }
    }

    try {
      // 2) 카테고리의 'userId' 목록 가져오기
      final categoryDoc =
          await _firestore.collection('categories').doc(categoryId).get();
      final List<String> userIds = List<String>.from(
        categoryDoc['userId'] ?? [],
      );

      // 3) 기존에 받아온 닉네임과 추가 데이터로 PhotoModel 생성
      final categoryRef = _firestore.collection('categories').doc(categoryId);
      final photoRef = categoryRef.collection('photos').doc();
      final photoId = photoRef.id;

      final photo = PhotoModel(
        imageUrl: downloadUrl,
        createdAt: Timestamp.now(),
        userIds: userIds,
        userID: id, // 필요 시 현재 사용자 ID 또는 관련 값을 할당
        audioUrl: audioUrl,
        id: photoId,

        //captionString: captionString,
      );

      // 4) Firestore에 사진 정보 저장
      await photoRef.set(photo.toMap());
      notifyListeners();
    } catch (e) {
      debugPrint('Error uploading photo metadata: $e');
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
    for (final category in categoriesSnapshot.docs) {
      final photosSnapshot =
          await _firestore
              .collection('categories')
              .doc(category.id)
              .collection('photos')
              .get();
      categoryStats[category.id] = photosSnapshot.size;
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

  /// 특정 유저 닉네임을 포함하는 카테고리 목록을 스트림으로 반환
  /*Stream<List<Map<String, dynamic>>> streamUserCategories(String id) {
    // Firestore의 snapshots()를 이용해 실시간 업데이트를 감지합니다.
    return _firestore
        .collection('categories')
        .where('mates', arrayContains: id)
        .snapshots()
        .map(
          (querySnapshot) =>
              querySnapshot.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      'name': doc['name'],
                      'mates': doc['mates'],
                    },
                  )
                  .toList(),
        );
  }*/

  /// 새 카테고리 생성
  Future<void> createCategory(String name, List mates, String userId) async {
    try {
      await _firestore.collection('categories').add({
        'name': name,
        'mates': mates,
        'userId': [userId],
      });
      notifyListeners();
    } catch (e) {
      debugPrint('카테고리 생성 오류: $e');
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
      notifyListeners();
    } catch (e) {
      debugPrint('카테고리 필드 업데이트 오류: $e');
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

  /// 로컬 이미지 파일을 Firebase Storage에 업로드하고 URL 반환
  Future<String> uploadImageToFirebase(String filePath) async {
    final file = File(filePath);
    final storageRef = _storage.ref().child(
      'images/${DateTime.now().toIso8601String()}',
    );
    await storageRef.putFile(file);
    return storageRef.getDownloadURL();
  }

  /// 특정 카테고리의 사진 목록(스트림) 가져오기
  Stream<List<PhotoModel>> getPhotosStream(String categoryId) {
    return _firestore
        .collection('categories')
        .doc(categoryId)
        .collection('photos')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(PhotoModel.fromDocument).toList());
  }

  void addCategory(Map<String, dynamic> category) {
    userCategories.add(category);
    notifyListeners(); // 중요: 리스너에게 변경 알림
  }
}
