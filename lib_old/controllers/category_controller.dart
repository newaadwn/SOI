import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'auth_controller.dart';
import '../models/category_model.dart';
import '../models/auth_model.dart';

/// 카테고리 관련 UI와 비즈니스 로직 사이의 중개 역할을 합니다.
class CategoryController extends ChangeNotifier {
  // 상태 변수들
  final List<String> _selectedNames = [];
  List<Map<String, dynamic>> _userCategories = [];
  String audioUrl = '';

  // 모델 인스턴스들
  final CategoryModel _categoryModel = CategoryModel();
  final AuthModel _authModel = AuthModel();

  // Getters
  List<String> get selectedNames => _selectedNames;
  List<Map<String, dynamic>> get userCategories => _userCategories;

  // 현재 로그인한 유저의 카테고리 정보를 가져오는 메소드
  Future<void> loadUserCategories(String uid) async {
    try {
      _userCategories = await _categoryModel.loadUserCategories(uid);
      notifyListeners();
    } catch (e) {
      debugPrint('사용자 카테고리 로드 오류: $e');
      _userCategories = []; // 오류 시 빈 리스트로 초기화
      notifyListeners();
    }
  }

  /// 카테고리 데이터를 가져오는 함수
  Stream<List<Map<String, dynamic>>> streamUserCategories(String id) {
    return _categoryModel.streamUserCategories(id);
  }

  /// 특정 카테고리 내의 photos 서브컬렉션에서
  /// 가장 이전(오래된) 사진의 URL을 가져오는 함수.
  Stream<String?> getFirstPhotoUrlStream(String categoryId) {
    return _categoryModel.getFirstPhotoUrlStream(categoryId);
  }

  /// 카테고리에 속한 mates들의 프로필 이미지를 가져오는 함수
  Future<List<String>> getCategoryProfileImages(
    List<String> mates,
    AuthController authViewModel,
  ) async {
    final completer = Completer<List<String>>();
    final subscription = _authModel
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
    AuthController authViewModel,
  ) {
    return _categoryModel.streamUserCategoriesWithDetails(
      id,
      _authModel.getprofileImages,
    );
  }

  // 이름 선택/해제 토글
  void toggleName(String name) {
    if (_selectedNames.contains(name)) {
      _selectedNames.remove(name);
    } else {
      _selectedNames.add(name);
    }
    notifyListeners();
  }

  // 선택된 이름 모두 지우기
  void clearSelectedNames() {
    _selectedNames.clear();
    notifyListeners();
  }

  /// 이미지 업로드 (Storage)
  Future<String?> uploadPhotoStorage(File imageFile) async {
    return await _categoryModel.uploadPhotoStorage(imageFile);
  }

  /// 사진 업로드 (Firestore)
  Future<void> uploadPhoto(
    String categoryId,
    String userId,
    String filePath,
    String audioUrl, {
    String? imageUrl,
  }) async {
    await _categoryModel.uploadPhoto(
      categoryId,
      userId,
      filePath,
      audioUrl,
      imageUrl: imageUrl,
    );
    notifyListeners();
  }

  /// 새 카테고리 생성
  Future<void> createCategory(String name, List mates, String userId) async {
    await _categoryModel.createCategory(name, mates, userId);
    notifyListeners();
  }

  /// 카테고리에 사용자 닉네임 추가
  Future<void> addUserToCategory(String categoryId, String id) async {
    await _categoryModel.addUserToCategory(categoryId, id);
    notifyListeners();
  }

  /// 카테고리에 사용자 UID 추가
  Future<void> addUidToCategory(String categoryId, String uid) async {
    await _categoryModel.addUidToCategory(categoryId, uid);
    notifyListeners();
  }

  /// 특정 사진의 오디오 URL 가져오기
  Future<String?> getPhotoAudioUrl(String categoryId, String photoId) async {
    return await _categoryModel.getPhotoAudioUrl(categoryId, photoId);
  }

  /// 모든 카테고리의 사진 통계를 가져오기
  Future<Map<String, int>> fetchCategoryStatistics() async {
    return await _categoryModel.fetchCategoryStatistics();
  }

  /// 저장된 사진이 가장 적은 카테고리의 'name' 가져오기
  Future<String?> getLeastSavedCategory() async {
    return await _categoryModel.getLeastSavedCategory();
  }

  /// 특정 카테고리의 이름 가져오기
  Future<String> getCategoryName(String categoryId) async {
    return await _categoryModel.getCategoryName(categoryId);
  }

  /// 특정 카테고리의 사진 목록(스트림) 가져오기
  Stream<List<Map<String, dynamic>>> getPhotosStream(String categoryId) {
    return _categoryModel.getPhotosStream(categoryId);
  }

  // 카테고리 리스트에 카테고리 추가
  void addCategory(Map<String, dynamic> category) {
    _userCategories.add(category);
    notifyListeners();
  }

  /// 특정 사진 문서의 ID 가져오기
  Future<String?> getPhotoDocumentId(String categoryId, String imageUrl) async {
    return await _categoryModel.getPhotoDocumentId(categoryId, imageUrl);
  }
}
