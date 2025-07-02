import 'dart:io';
import 'package:flutter/material.dart';
import '../repositories/category_repository.dart';
import '../models/category_data_model.dart';
import '../models/auth_result.dart';

/// 비즈니스 로직을 처리하는 Service
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class CategoryService {
  final CategoryRepository _repository = CategoryRepository();

  // ==================== 비즈니스 로직 ====================

  /// 카테고리 이름 검증
  String? _validateCategoryName(String name) {
    if (name.trim().isEmpty) {
      return '카테고리 이름을 입력해주세요.';
    }
    if (name.trim().length < 2) {
      return '카테고리 이름은 2글자 이상이어야 합니다.';
    }
    if (name.trim().length > 20) {
      return '카테고리 이름은 20글자 이하여야 합니다.';
    }
    return null;
  }

  /// 카테고리 이름 정규화
  String _normalizeCategoryName(String name) {
    return name.trim();
  }

  // ==================== 카테고리 관리 ====================

  /// 사용자의 카테고리 목록을 스트림으로 가져오기
  Stream<List<CategoryDataModel>> getUserCategoriesStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }
    return _repository.getUserCategoriesStream(userId);
  }

  /// 사용자의 카테고리 목록을 한 번만 가져오기
  Future<List<CategoryDataModel>> getUserCategories(String userId) async {
    if (userId.isEmpty) {
      debugPrint('CategoryService: userId가 비어있습니다.');
      return [];
    }

    try {
      debugPrint(
        'CategoryService: Repository.getUserCategories 호출 중... userId=$userId',
      );
      final categories = await _repository.getUserCategories(userId);
      debugPrint(
        'CategoryService: Repository에서 반환된 카테고리 수: ${categories.length}',
      );
      return categories;
    } catch (e) {
      debugPrint('카테고리 목록 조회 오류: $e');
      return [];
    }
  }

  /// 카테고리 생성
  Future<AuthResult> createCategory({
    required String name,
    required List<String> mates,
  }) async {
    try {
      // 1. 카테고리 이름 검증
      final validationError = _validateCategoryName(name);
      if (validationError != null) {
        return AuthResult.failure(validationError);
      }

      // 2. 메이트 검증
      if (mates.isEmpty) {
        return AuthResult.failure('최소 1명의 멤버가 필요합니다.');
      }

      // 3. 카테고리 이름 정규화
      final normalizedName = _normalizeCategoryName(name);

      // 4. 카테고리 생성
      final category = CategoryDataModel(
        id: '', // Repository에서 생성됨
        name: normalizedName,
        mates: mates,
        createdAt: DateTime.now(),
      );

      final categoryId = await _repository.createCategory(category);

      return AuthResult.success(categoryId);
    } catch (e) {
      debugPrint('카테고리 생성 오류: $e');
      return AuthResult.failure('카테고리 생성 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 수정
  Future<AuthResult> updateCategory({
    required String categoryId,
    String? name,
    List<String>? mates,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      // 1. 이름 업데이트
      if (name != null) {
        final validationError = _validateCategoryName(name);
        if (validationError != null) {
          return AuthResult.failure(validationError);
        }
        updateData['name'] = _normalizeCategoryName(name);
      }

      // 2. 멤버 업데이트
      if (mates != null) {
        if (mates.isEmpty) {
          return AuthResult.failure('최소 1명의 멤버가 필요합니다.');
        }
        updateData['mates'] = mates;
      }

      if (updateData.isEmpty) {
        return AuthResult.failure('업데이트할 내용이 없습니다.');
      }

      await _repository.updateCategory(categoryId, updateData);
      return AuthResult.success();
    } catch (e) {
      debugPrint('카테고리 수정 오류: $e');
      return AuthResult.failure('카테고리 수정 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 삭제
  Future<AuthResult> deleteCategory(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      await _repository.deleteCategory(categoryId);
      return AuthResult.success();
    } catch (e) {
      debugPrint('카테고리 삭제 오류: $e');
      return AuthResult.failure('카테고리 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 특정 카테고리 정보 가져오기
  Future<CategoryDataModel?> getCategory(String categoryId) async {
    try {
      if (categoryId.isEmpty) return null;

      return await _repository.getCategory(categoryId);
    } catch (e) {
      debugPrint('카테고리 조회 오류: $e');
      return null;
    }
  }

  // ==================== 사진 관리 ====================

  /// 카테고리에 사진 추가
  Future<AuthResult> addPhotoToCategory({
    required String categoryId,
    required File imageFile,
    String? description,
  }) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      // 1. 이미지 업로드
      final imageUrl = await _repository.uploadImage(categoryId, imageFile);

      // 2. 사진 데이터 생성
      final photoData = {
        'url': imageUrl,
        'description': description ?? '',
        'createdAt': DateTime.now(),
      };

      // 3. Firestore에 사진 정보 저장
      final photoId = await _repository.addPhotoToCategory(
        categoryId,
        photoData,
      );

      return AuthResult.success(photoId);
    } catch (e) {
      debugPrint('사진 추가 오류: $e');
      return AuthResult.failure('사진 추가 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리에서 사진 삭제
  Future<AuthResult> removePhotoFromCategory({
    required String categoryId,
    required String photoId,
    required String imageUrl,
  }) async {
    try {
      if (categoryId.isEmpty || photoId.isEmpty) {
        return AuthResult.failure('유효하지 않은 정보입니다.');
      }

      // 1. Storage에서 이미지 삭제
      await _repository.deleteImage(imageUrl);

      // 2. Firestore에서 사진 정보 삭제
      await _repository.removePhotoFromCategory(categoryId, photoId);

      return AuthResult.success();
    } catch (e) {
      debugPrint('사진 삭제 오류: $e');
      return AuthResult.failure('사진 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리의 사진들 가져오기
  Future<List<Map<String, dynamic>>> getCategoryPhotos(
    String categoryId,
  ) async {
    try {
      if (categoryId.isEmpty) return [];

      return await _repository.getCategoryPhotos(categoryId);
    } catch (e) {
      debugPrint('카테고리 사진 조회 오류: $e');
      return [];
    }
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 카테고리 사진 스트림 (Map 형태로 반환)
  Stream<List<Map<String, dynamic>>> getCategoryPhotosStream(
    String categoryId,
  ) {
    return _repository.getCategoryPhotosStream(categoryId);
  }

  // ==================== 유틸리티 ====================

  /// 카테고리 이름 중복 검사 (같은 사용자의 카테고리 중에서)
  Future<bool> isDuplicateCategoryName(String userId, String name) async {
    try {
      final categories = await getUserCategories(userId);
      final normalizedName = _normalizeCategoryName(name);

      return categories.any(
        (category) =>
            category.name.toLowerCase() == normalizedName.toLowerCase(),
      );
    } catch (e) {
      debugPrint('카테고리 이름 중복 검사 오류: $e');
      return false;
    }
  }

  /// 사용자가 카테고리의 멤버인지 확인
  bool isUserMemberOfCategory(CategoryDataModel category, String userId) {
    return category.mates.contains(userId);
  }

  /// 카테고리에 사용자 추가 (닉네임으로)
  Future<AuthResult> addUserToCategory({
    required String categoryId,
    required String nickName,
  }) async {
    try {
      await _repository.addUserToCategory(
        categoryId: categoryId,
        nickName: nickName,
      );
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.failure('카테고리에 사용자 추가 실패: $e');
    }
  }

  /// 카테고리에 사용자 추가 (UID로)
  Future<AuthResult> addUidToCategory({
    required String categoryId,
    required String uid,
  }) async {
    try {
      await _repository.addUidToCategory(categoryId: categoryId, uid: uid);
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.failure('카테고리에 사용자 추가 실패: $e');
    }
  }
}
