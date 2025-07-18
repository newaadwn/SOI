import 'dart:io';
import 'package:flutter/material.dart';
import '../services/category_service.dart';
import '../models/category_data_model.dart';

/// 카테고리 관련 UI와 비즈니스 로직 사이의 중개 역할을 합니다.
class CategoryController extends ChangeNotifier {
  // 상태 변수들
  final List<String> _selectedNames = [];
  List<CategoryDataModel> _userCategories = [];
  bool _isLoading = false;
  String? _error;
  String? _lastLoadedUserId; // 마지막으로 로드한 사용자 ID
  DateTime? _lastLoadTime; // 마지막 로드 시간
  static const Duration _cacheTimeout = Duration(seconds: 30); // 캐시 유효 시간

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final CategoryService _categoryService = CategoryService();

  // Getters
  List<String> get selectedNames => _selectedNames;
  List<CategoryDataModel> get userCategories => _userCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==================== 카테고리 관리 ====================

  // 사용자의 카테고리 목록을 가져오는 메소드
  Future<void> loadUserCategories(
    String userId, {
    bool forceReload = false,
  }) async {
    if (userId.isEmpty) {
      debugPrint('loadUserCategories: userId가 비어있습니다.');
      return;
    }

    debugPrint(
      'loadUserCategories 시작: userId=$userId, forceReload=$forceReload',
    );

    // 캐시가 유효한지 확인
    final now = DateTime.now();
    final isCacheValid =
        _lastLoadTime != null && now.difference(_lastLoadTime!) < _cacheTimeout;

    debugPrint(
      '캐시 상태: isLoading=$_isLoading, lastLoadedUserId=$_lastLoadedUserId, isCacheValid=$isCacheValid',
    );

    // 이미 로딩 중이거나 같은 사용자의 데이터가 이미 로드되고 캐시가 유효한 경우 스킵 (forceReload가 true가 아닌 경우)
    if (!forceReload &&
        (_isLoading || (_lastLoadedUserId == userId && isCacheValid))) {
      debugPrint('캐시에서 스킵됨');
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('CategoryService.getUserCategories 호출 중...');
      _userCategories = await _categoryService.getUserCategories(userId);
      debugPrint('CategoryService에서 반환된 카테고리 수: ${_userCategories.length}');

      _lastLoadedUserId = userId;
      _lastLoadTime = DateTime.now(); // 로드 시간 업데이트

      _isLoading = false;
      notifyListeners();

      debugPrint('loadUserCategories 완료: ${_userCategories.length}개 카테고리 로드됨');
    } catch (e) {
      debugPrint('사용자 카테고리 로드 오류: $e');
      _error = '카테고리를 불러오는 중 오류가 발생했습니다.';
      _userCategories = [];
      _isLoading = false;
      notifyListeners();

      // ✅ UI 피드백
      debugPrint('카테고리를 불러오는 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  /// 카테고리 데이터를 스트림으로 가져오는 함수
  Stream<List<CategoryDataModel>> streamUserCategories(String userId) {
    return _categoryService.getUserCategoriesStream(userId);
  }

  /// 카테고리 생성
  Future<void> createCategory({
    required String name,
    required List<String> mates,
  }) async {
    try {
      debugPrint('CategoryController: 카테고리 생성 시작... name=$name, mates=$mates');

      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _categoryService.createCategory(
        name: name,
        mates: mates,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        debugPrint('CategoryController: 카테고리 생성 성공');

        // 캐시 무효화 후 카테고리 목록 새로고침 (첫 번째 mate의 ID 사용)
        invalidateCache();
        if (mates.isNotEmpty) {
          debugPrint(
            'CategoryController: 카테고리 목록 새로고침... userId=${mates.first}',
          );
          await loadUserCategories(mates.first, forceReload: true);
        }
      } else {
        debugPrint('CategoryController: 카테고리 생성 실패 - ${result.error}');
        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '카테고리 생성에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('카테고리 생성 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('카테고리 생성 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  /// 카테고리 수정
  Future<void> updateCategory({
    required String categoryId,
    String? name,
    List<String>? mates,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _categoryService.updateCategory(
        categoryId: categoryId,
        name: name,
        mates: mates,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백
        debugPrint('카테고리가 수정되었습니다.');
        // 현재 사용자의 카테고리 목록 새로고침
        if (_userCategories.isNotEmpty) {
          final firstMate = _userCategories.first.mates.first;
          await loadUserCategories(firstMate);
        }
      } else {
        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '카테고리 수정에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('카테고리 수정 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('카테고리 수정 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  /// 카테고리 삭제
  Future<void> deleteCategory(String categoryId, String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _categoryService.deleteCategory(categoryId);

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백
        debugPrint('카테고리가 삭제되었습니다.');
        // 카테고리 목록 새로고침
        await loadUserCategories(userId);
      } else {
        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '카테고리 삭제에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('카테고리 삭제 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('카테고리 삭제 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  /// 특정 카테고리 정보 가져오기
  Future<CategoryDataModel?> getCategory(String categoryId) async {
    return await _categoryService.getCategory(categoryId);
  }

  // ==================== 사진 관리 ====================

  /// 카테고리의 사진들 가져오기
  Future<List<Map<String, dynamic>>> getCategoryPhotos(
    String categoryId,
  ) async {
    return await _categoryService.getCategoryPhotos(categoryId);
  }

  // ==================== UI 상태 관리 ====================

  /// 선택된 이름들 관리
  void addSelectedName(String name) {
    if (!_selectedNames.contains(name)) {
      _selectedNames.add(name);
      notifyListeners();
    }
  }

  void removeSelectedName(String name) {
    _selectedNames.remove(name);
    notifyListeners();
  }

  void toggleSelectedName(String name) {
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

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 사용자 카테고리 스트림 (Map 형태로 반환)
  Stream<List<Map<String, dynamic>>> streamUserCategoriesAsMap(String userId) {
    return streamUserCategories(userId).map(
      (categories) =>
          categories
              .map((category) => category.toFirestore()..['id'] = category.id)
              .toList(),
    );
  }

  /// 카테고리 이름 조회 (기존 호환성)
  Future<String> getCategoryName(String categoryId) async {
    try {
      final category = await getCategory(categoryId);
      return category?.name ?? '알 수 없는 카테고리';
    } catch (e) {
      debugPrint('카테고리 이름 조회 오류: $e');
      return '오류 발생';
    }
  }

  /// 카테고리 사진 스트림 (기존 호환성)
  Stream<List<Map<String, dynamic>>> getPhotosStream(String categoryId) {
    return _categoryService.getCategoryPhotosStream(categoryId);
  }

  /// 사진 문서 ID 조회 (기존 호환성)
  Future<String?> getPhotoDocumentId(String categoryId, String imageUrl) async {
    try {
      final photos = await getCategoryPhotos(categoryId);
      for (final photo in photos) {
        if (photo['imageUrl'] == imageUrl) {
          return photo['id'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('사진 문서 ID 조회 오류: $e');
      return null;
    }
  }

  /// 카테고리 프로필 이미지들 조회 (기존 호환성)
  Future<List<String>> getCategoryProfileImages(
    List<String> mates,
    dynamic authController,
  ) async {
    try {
      List<String> profileImages = [];

      for (String mate in mates) {
        try {
          // AuthController를 통해 사용자 프로필 이미지 URL 가져오기
          final profileUrl = await authController.getUserProfileImageUrl();
          if (profileUrl != null && profileUrl.isNotEmpty) {
            profileImages.add(profileUrl);
          }
        } catch (e) {
          debugPrint('프로필 이미지 로딩 오류 ($mate): $e');
        }
      }

      return profileImages;
    } catch (e) {
      debugPrint('카테고리 프로필 이미지 조회 오류: $e');
      return [];
    }
  }

  /// 첫 번째 사진 URL 스트림 (기존 호환성)
  Stream<String?> getFirstPhotoUrlStream(String categoryId) {
    return getPhotosStream(categoryId).map((photos) {
      if (photos.isNotEmpty) {
        return photos.first['imageUrl'] as String?;
      }
      return null;
    });
  }

  /// 사용자 카테고리 스트림 (상세 정보 포함)
  Stream<List<Map<String, dynamic>>> streamUserCategoriesWithDetails(
    String userId,
    dynamic authController,
  ) {
    return streamUserCategories(userId).asyncMap((categories) async {
      List<Map<String, dynamic>> categoriesWithDetails = [];

      for (final category in categories) {
        final categoryMap = category.toFirestore();
        categoryMap['id'] = category.id;

        // 추가 상세 정보들을 여기서 로드할 수 있습니다
        // 예: 첫 번째 사진, 사진 개수 등
        categoriesWithDetails.add(categoryMap);
      }

      return categoriesWithDetails;
    });
  }

  /// 카테고리에 사용자 추가 (닉네임으로)
  Future<void> addUserToCategory(String categoryId, String nickName) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _categoryService.addUserToCategory(
        categoryId: categoryId,
        nickName: nickName,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백 없음 (호출하는 곳에서 처리)
      } else {
        _error = result.error;
        throw Exception(result.error);
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  /// 카테고리에 사용자 추가 (UID로)
  Future<void> addUidToCategory(String categoryId, String uid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _categoryService.addUidToCategory(
        categoryId: categoryId,
        uid: uid,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백 없음 (호출하는 곳에서 처리)
      } else {
        _error = result.error;
        throw Exception(result.error);
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      throw e;
    }
  }

  /// 카테고리 캐시를 무효화합니다.
  void invalidateCache() {
    _lastLoadTime = null;
    _lastLoadedUserId = null;
  }
}
