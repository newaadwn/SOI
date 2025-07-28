import 'dart:io';
import 'package:flutter/material.dart';
import '../services/category_service.dart';
import '../models/category_data_model.dart';

/// 카테고리 관련 UI와 비즈니스 로직 사이의 중개 역할을 합니다.
class CategoryController extends ChangeNotifier {
  // 상태 변수들
  final List<String> _selectedNames = [];
  List<CategoryDataModel> _userCategories = [];
  List<CategoryDataModel> _filteredCategories = [];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;
  String? _lastLoadedUserId; // 마지막으로 로드한 사용자 ID
  DateTime? _lastLoadTime; // 마지막 로드 시간
  static const Duration _cacheTimeout = Duration(seconds: 30); // 캐시 유효 시간

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final CategoryService _categoryService = CategoryService();

  // Getters
  List<String> get selectedNames => _selectedNames;
  List<CategoryDataModel> get userCategories =>
      _filteredCategories.isNotEmpty || _searchQuery.isNotEmpty
          ? _filteredCategories
          : _userCategories;
  String get searchQuery => _searchQuery;
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
      '🔍 [CATEGORY_CONTROLLER] loadUserCategories 시작: userId="$userId", forceReload=$forceReload',
    );

    // 캐시가 유효한지 확인
    final now = DateTime.now();
    final isCacheValid =
        _lastLoadTime != null && now.difference(_lastLoadTime!) < _cacheTimeout;

    debugPrint(
      '🔍 [CATEGORY_CONTROLLER] 캐시 상태: isLoading=$_isLoading, lastLoadedUserId="$_lastLoadedUserId", isCacheValid=$isCacheValid',
    );

    // 이미 로딩 중이면 스킵
    if (_isLoading) {
      debugPrint('🔍 [CATEGORY_CONTROLLER] 이미 로딩 중이므로 스킵');
      return;
    }

    // forceReload가 아니고 캐시가 유효하면 스킵
    if (!forceReload && _lastLoadedUserId == userId && isCacheValid) {
      debugPrint('🔍 [CATEGORY_CONTROLLER] 캐시에서 스킵됨');
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint(
        '🔍 [CATEGORY_CONTROLLER] CategoryService.getUserCategories 호출 중...',
      );
      _userCategories = await _categoryService.getUserCategories(userId);
      debugPrint(
        '🔍 [CATEGORY_CONTROLLER] CategoryService에서 반환된 카테고리 수: ${_userCategories.length}',
      );

      if (_userCategories.isNotEmpty) {
        for (var category in _userCategories) {
          debugPrint(
            '🔍 [CATEGORY_CONTROLLER] 카테고리: ${category.name} (ID: ${category.id})',
          );
        }
      }

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

  /// 단일 카테고리 실시간 스트림
  Stream<CategoryDataModel?> streamSingleCategory(String categoryId) {
    return _categoryService.getCategoryStream(categoryId);
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
    bool? isPinned,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _categoryService.updateCategory(
        categoryId: categoryId,
        name: name,
        mates: mates,
        isPinned: isPinned,
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

  /// 📌 카테고리 고정/해제 토글
  Future<void> togglePinCategory(
    String categoryId,
    bool currentPinStatus,
  ) async {
    try {
      final newPinStatus = !currentPinStatus;

      // 🚀 즉시 UI 업데이트 - 로컬 상태 변경
      final categoryIndex = _userCategories.indexWhere(
        (cat) => cat.id == categoryId,
      );
      if (categoryIndex != -1) {
        // 카테고리 복사 후 isPinned 상태 변경
        final updatedCategory = CategoryDataModel(
          id: _userCategories[categoryIndex].id,
          name: _userCategories[categoryIndex].name,
          mates: _userCategories[categoryIndex].mates,
          createdAt: _userCategories[categoryIndex].createdAt,
          categoryPhotoUrl: _userCategories[categoryIndex].categoryPhotoUrl,

          isPinned: newPinStatus,
        );

        // 리스트에서 해당 카테고리 업데이트
        _userCategories[categoryIndex] = updatedCategory;

        // 정렬 다시 적용 (고정된 카테고리를 상단으로)
        _userCategories.sort((a, b) {
          // 고정된 카테고리를 상단으로
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          // 둘 다 고정되었거나 고정되지 않은 경우 생성일 기준 내림차순
          return b.createdAt.compareTo(a.createdAt);
        });

        // 🎯 즉시 UI 업데이트
        notifyListeners();
      }

      _isLoading = true;
      // 로딩 상태는 별도로 표시하지 않음 (이미 UI가 업데이트되었으므로)

      final result = await _categoryService.updateCategory(
        categoryId: categoryId,
        isPinned: newPinStatus,
      );

      _isLoading = false;

      if (result.isSuccess) {
        debugPrint('카테고리 고정 상태가 변경되었습니다: $newPinStatus');
        // 성공 시에는 추가적인 새로고침이 필요하지 않음 (이미 로컬에서 업데이트됨)
      } else {
        debugPrint(result.error ?? '카테고리 고정 변경에 실패했습니다.');
        // 실패 시 이전 상태로 롤백
        if (categoryIndex != -1) {
          final rollbackCategory = CategoryDataModel(
            id: _userCategories[categoryIndex].id,
            name: _userCategories[categoryIndex].name,
            mates: _userCategories[categoryIndex].mates,
            createdAt: _userCategories[categoryIndex].createdAt,
            categoryPhotoUrl: _userCategories[categoryIndex].categoryPhotoUrl,

            isPinned: currentPinStatus, // 원래 상태로 롤백
          );

          _userCategories[categoryIndex] = rollbackCategory;

          // 정렬 다시 적용
          _userCategories.sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return b.createdAt.compareTo(a.createdAt);
          });

          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('카테고리 고정 변경 오류: $e');
      _isLoading = false;

      // 실패 시 이전 상태로 롤백
      final categoryIndex = _userCategories.indexWhere(
        (cat) => cat.id == categoryId,
      );
      if (categoryIndex != -1) {
        final rollbackCategory = CategoryDataModel(
          id: _userCategories[categoryIndex].id,
          name: _userCategories[categoryIndex].name,
          mates: _userCategories[categoryIndex].mates,
          createdAt: _userCategories[categoryIndex].createdAt,
          categoryPhotoUrl: _userCategories[categoryIndex].categoryPhotoUrl,

          isPinned: currentPinStatus, // 원래 상태로 롤백
        );

        _userCategories[categoryIndex] = rollbackCategory;

        // 정렬 다시 적용
        _userCategories.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        notifyListeners();
      }
    }
  }

  /// 🚪 카테고리 나가기
  Future<void> leaveCategoryByUid(String categoryId, String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _categoryService.removeUidFromCategory(
        categoryId: categoryId,
        uid: userId,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        debugPrint('카테고리에서 나가기 성공: ${result.data}');
        // 카테고리 목록 새로고침
        await loadUserCategories(userId);
      } else {
        debugPrint(result.error ?? '카테고리 나가기에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('카테고리 나가기 오류: $e');
      _isLoading = false;
      notifyListeners();
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

  // ==================== 표지사진 관리 ====================

  /// 갤러리에서 선택한 이미지로 표지사진 업데이트
  Future<bool> updateCoverPhotoFromGallery({
    required String categoryId,
    required File imageFile,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _categoryService.updateCoverPhotoFromGallery(
        categoryId: categoryId,
        imageFile: imageFile,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 성공 시 카테고리 목록 새로고침
        invalidateCache();
        return true;
      } else {
        _error = result.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('표지사진 업데이트 오류: $e');
      _isLoading = false;
      _error = '표지사진 업데이트 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 카테고리 내 사진으로 표지사진 업데이트
  Future<bool> updateCoverPhotoFromCategory({
    required String categoryId,
    required String photoUrl,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _categoryService.updateCoverPhotoFromCategory(
        categoryId: categoryId,
        photoUrl: photoUrl,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 성공 시 카테고리 목록 새로고침
        invalidateCache();
        return true;
      } else {
        _error = result.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('표지사진 업데이트 오류: $e');
      _isLoading = false;
      _error = '표지사진 업데이트 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 표지사진 삭제
  Future<bool> deleteCoverPhoto(String categoryId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _categoryService.deleteCoverPhoto(categoryId);

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 성공 시 카테고리 목록 새로고침
        invalidateCache();
        return true;
      } else {
        _error = result.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('표지사진 삭제 오류: $e');
      _isLoading = false;
      _error = '표지사진 삭제 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

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
        return photos.first['image'] as String?;
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
      rethrow;
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
      rethrow;
    }
  }

  /// 카테고리 캐시를 무효화합니다.
  void invalidateCache() {
    _lastLoadTime = null;
    _lastLoadedUserId = null;
  }

  // ==================== 검색 기능 ====================

  /// 검색어로 카테고리 필터링
  void searchCategories(String query) {
    _searchQuery = query.trim();

    if (_searchQuery.isEmpty) {
      _filteredCategories = [];
    } else {
      _filteredCategories =
          _userCategories.where((category) {
            return _matchesSearch(category.name, _searchQuery);
          }).toList();
    }

    notifyListeners();
  }

  /// 검색 초기화
  void clearSearch() {
    _searchQuery = '';
    _filteredCategories = [];
    notifyListeners();
  }

  /// 텍스트가 검색어와 매치되는지 확인 (한글 초성 검색, 영어 약어 검색 포함)
  bool _matchesSearch(String text, String query) {
    // 대소문자 구분 없이 기본 검색
    if (text.toLowerCase().contains(query.toLowerCase())) {
      return true;
    }

    // 한글 초성 검색
    if (_matchesChosung(text, query)) {
      return true;
    }

    // 영어 약어 검색
    return _matchesAcronym(text, query);
  }

  /// 한글 초성 검색 매치
  bool _matchesChosung(String text, String query) {
    try {
      String textChosung = _extractChosung(text);
      String queryChosung = _extractChosung(query);

      return textChosung.contains(queryChosung);
    } catch (e) {
      return false;
    }
  }

  /// 한글에서 초성 추출
  String _extractChosung(String text) {
    const chosungList = [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];

    StringBuffer result = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      int charCode = text.codeUnitAt(i);

      // 한글인지 확인 (가-힣)
      if (charCode >= 0xAC00 && charCode <= 0xD7A3) {
        // 초성 추출
        int chosungIndex = ((charCode - 0xAC00) / 588).floor();
        if (chosungIndex >= 0 && chosungIndex < chosungList.length) {
          result.write(chosungList[chosungIndex]);
        }
      } else if (_isChosung(text[i])) {
        // 이미 초성인 경우
        result.write(text[i]);
      } else {
        // 한글이 아닌 경우 그대로 추가
        result.write(text[i]);
      }
    }

    return result.toString();
  }

  /// 초성인지 확인
  bool _isChosung(String char) {
    const chosungList = [
      'ㄱ',
      'ㄲ',
      'ㄴ',
      'ㄷ',
      'ㄸ',
      'ㄹ',
      'ㅁ',
      'ㅂ',
      'ㅃ',
      'ㅅ',
      'ㅆ',
      'ㅇ',
      'ㅈ',
      'ㅉ',
      'ㅊ',
      'ㅋ',
      'ㅌ',
      'ㅍ',
      'ㅎ',
    ];
    return chosungList.contains(char);
  }

  // ==================== 영어 약어 검색 ====================

  /// 영어 약어 검색 매치
  bool _matchesAcronym(String text, String query) {
    try {
      // 최소 2글자 이상의 쿼리만 약어 검색 적용
      if (query.length < 2) {
        return false;
      }

      String textAcronym = _extractAcronym(text);
      String queryLower = query.toLowerCase();

      return textAcronym.contains(queryLower);
    } catch (e) {
      return false;
    }
  }

  /// 영어 텍스트에서 약어 추출 (CamelCase 및 공백 기반)
  String _extractAcronym(String text) {
    if (text.isEmpty) return '';

    List<String> words = _splitWordsFromText(text);
    StringBuffer acronym = StringBuffer();

    for (String word in words) {
      if (word.isNotEmpty) {
        acronym.write(word[0].toLowerCase());
      }
    }

    return acronym.toString();
  }

  /// 텍스트를 단어로 분리 (공백, 특수문자, CamelCase 고려)
  List<String> _splitWordsFromText(String text) {
    List<String> words = [];
    StringBuffer currentWord = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      String char = text[i];

      // 공백이나 특수문자인 경우
      if (char == ' ' ||
          char == '-' ||
          char == '_' ||
          char == '.' ||
          char == ',') {
        if (currentWord.isNotEmpty) {
          words.add(currentWord.toString());
          currentWord.clear();
        }
      }
      // 대문자인 경우 (CamelCase 처리)
      else if (char == char.toUpperCase() && char != char.toLowerCase()) {
        // 이전 단어가 있으면 저장
        if (currentWord.isNotEmpty) {
          words.add(currentWord.toString());
          currentWord.clear();
        }
        currentWord.write(char);
      }
      // 일반 문자인 경우
      else {
        currentWord.write(char);
      }
    }

    // 마지막 단어 추가
    if (currentWord.isNotEmpty) {
      words.add(currentWord.toString());
    }

    return words;
  }
}
