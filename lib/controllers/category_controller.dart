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
  List<CategoryDataModel> get userCategoryList => _userCategories;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ==================== 카테고리 관리 ====================

  /// 사용자의 카테고리 목록을 로드합니다
  Future<void> loadUserCategories(
    String userId, {
    bool forceReload = false,
  }) async {
    // 유효성 검사
    if (userId.isEmpty) {
      debugPrint('[CategoryController] userId가 비어있음 - 로드 중단');
      return;
    }

    // 캐시 유효성 검사
    final now = DateTime.now();
    final isCacheValid =
        _lastLoadTime != null && now.difference(_lastLoadTime!) < _cacheTimeout;

    // 캐시된 데이터 사용 가능 여부 확인
    if (!forceReload && _lastLoadedUserId == userId && isCacheValid) {
      debugPrint(
        '[CategoryController] 캐시된 데이터 사용 - userId: $userId, 카테고리 수: ${_userCategories.length}',
      );
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 서비스에서 카테고리 목록 가져오기
      final categories = await _categoryService.getUserCategories(userId);

      _userCategories = categories;

      // 사용자별 고정 상태에 따라 정렬
      _sortCategoriesForUser(userId);

      // 캐시 정보 업데이트
      _lastLoadedUserId = userId;
      _lastLoadTime = DateTime.now();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[CategoryController] 카테고리 로드 오류: $e');
      _error = '카테고리를 불러오는 중 오류가 발생했습니다.';
      _userCategories = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 카테고리 데이터를 스트림으로 가져오는 함수
  Stream<List<CategoryDataModel>> streamUserCategories(String userId) {
    return _categoryService.getUserCategoriesStream(userId).map((categories) {
      // 스트림에서도 사용자별 정렬 적용 (공통 비교 함수 사용)
      categories.sort((a, b) => _compareCategoriesForUser(a, b, userId));
      return categories;
    });
  }

  /// 단일 카테고리 실시간 스트림
  Stream<CategoryDataModel?> streamSingleCategory(String categoryId) {
    return _categoryService.getCategoryStream(categoryId);
  }

  /// 새 카테고리를 생성합니다
  Future<void> createCategory({
    required String name,
    required List<String> mates,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 카테고리 생성 요청
      final result = await _categoryService.createCategory(
        name: name,
        mates: mates,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 성공 시 캐시 무효화 후 새로고침
        invalidateCache();
        if (mates.isNotEmpty) {
          await loadUserCategories(mates.first, forceReload: true);
        }
      } else {
        _error = result.error;
      }
    } catch (e) {
      _isLoading = false;
      _error = '카테고리 생성 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// 카테고리 정보를 수정합니다
  Future<void> updateCategory({
    required String categoryId,
    String? name,
    List<String>? mates,
    bool? isPinned,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 카테고리 업데이트 요청
      final result = await _categoryService.updateCategory(
        categoryId: categoryId,
        name: name,
        mates: mates,
        isPinned: isPinned,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 성공 시 현재 사용자의 카테고리 목록 새로고침
        if (_userCategories.isNotEmpty) {
          final firstMate = _userCategories.first.mates.first;
          await loadUserCategories(firstMate);
        }
      } else {
        _error = result.error;
      }
    } catch (e) {
      _isLoading = false;
      _error = '카테고리 수정 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// 카테고리 이름만 업데이트하는 편의 메서드
  Future<void> updateCategoryName(String categoryId, String newName) async {
    await updateCategory(categoryId: categoryId, name: newName);
  }

  /// 사용자별 카테고리 커스텀 이름 업데이트
  Future<void> updateCustomCategoryName({
    required String categoryId,
    required String userId,
    required String customName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 서비스를 통해 커스텀 이름 업데이트
      final result = await _categoryService.updateCustomCategoryName(
        categoryId: categoryId,
        userId: userId,
        customName: customName,
      );

      _isLoading = false;

      if (result.isSuccess) {
        // 성공 시 카테고리 목록 새로고침
        await loadUserCategories(userId, forceReload: true);
      } else {
        _error = result.error;
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = '커스텀 이름 설정 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// 현재 사용자를 위한 카테고리 표시 이름 가져오기
  String getCategoryDisplayName(CategoryDataModel category, String userId) {
    return category.getDisplayName(userId);
  }

  /// 카테고리 고정/해제를 토글합니다 (사용자별)
  Future<void> togglePinCategory(
    String categoryId,
    String userId,
    bool currentPinStatus,
  ) async {
    try {
      final newPinStatus = !currentPinStatus;

      // 즉시 UI 업데이트를 위한 로컬 상태 변경
      final categoryIndex = _userCategories.indexWhere(
        (cat) => cat.id == categoryId,
      );

      if (categoryIndex != -1) {
        // 사용자별 고정 상태 업데이트
        final currentUserPinnedStatus = Map<String, bool>.from(
          _userCategories[categoryIndex].userPinnedStatus ?? {},
        );
        currentUserPinnedStatus[userId] = newPinStatus;

        // 카테고리 상태 업데이트
        _userCategories[categoryIndex] = _userCategories[categoryIndex]
            .copyWith(userPinnedStatus: currentUserPinnedStatus);

        // 사용자별 고정 상태에 따라 재정렬 (고정된 카테고리가 상단에)
        _userCategories.sort((a, b) {
          final aIsPinned = a.isPinnedForUser(userId);
          final bIsPinned = b.isPinnedForUser(userId);

          if (aIsPinned && !bIsPinned) return -1;
          if (!aIsPinned && bIsPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        notifyListeners();
      }

      _isLoading = true;

      // 서버에 변경사항 저장 (사용자별 고정 상태 저장)
      final result = await _categoryService.updateUserPinStatus(
        categoryId: categoryId,
        userId: userId,
        isPinned: newPinStatus,
      );

      _isLoading = false;

      if (!result.isSuccess) {
        // 실패 시 이전 상태로 롤백
        if (categoryIndex != -1) {
          final rollbackUserPinnedStatus = Map<String, bool>.from(
            _userCategories[categoryIndex].userPinnedStatus ?? {},
          );
          rollbackUserPinnedStatus[userId] = currentPinStatus;

          _userCategories[categoryIndex] = _userCategories[categoryIndex]
              .copyWith(userPinnedStatus: rollbackUserPinnedStatus);

          // 원래 상태로 재정렬
          _userCategories.sort((a, b) {
            final aIsPinned = a.isPinnedForUser(userId);
            final bIsPinned = b.isPinnedForUser(userId);

            if (aIsPinned && !bIsPinned) return -1;
            if (!aIsPinned && bIsPinned) return 1;
            return b.createdAt.compareTo(a.createdAt);
          });

          notifyListeners();
        }
      }
    } catch (e) {
      _isLoading = false;

      // 에러 발생 시에도 이전 상태로 롤백
      final categoryIndex = _userCategories.indexWhere(
        (cat) => cat.id == categoryId,
      );

      if (categoryIndex != -1) {
        final rollbackUserPinnedStatus = Map<String, bool>.from(
          _userCategories[categoryIndex].userPinnedStatus ?? {},
        );
        rollbackUserPinnedStatus[userId] = currentPinStatus;

        _userCategories[categoryIndex] = _userCategories[categoryIndex]
            .copyWith(userPinnedStatus: rollbackUserPinnedStatus);

        notifyListeners();
      }
    }
  }

  /// 카테고리에서 나가기를 처리합니다
  Future<void> leaveCategoryByUid(String categoryId, String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 카테고리 나가기 요청
      final result = await _categoryService.removeUidFromCategory(
        categoryId: categoryId,
        uid: userId,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 성공 시 캐시 무효화 후 강제 새로고침
        invalidateCache();
        await loadUserCategories(userId, forceReload: true);
      } else {
        _error = result.error;
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _error = '카테고리 나가기 중 오류가 발생했습니다: $e';
      notifyListeners();
    }
  }

  /// 카테고리를 삭제합니다
  Future<void> deleteCategory(String categoryId, String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 카테고리 삭제 요청
      final result = await _categoryService.deleteCategory(categoryId);

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 성공 시 카테고리 목록 새로고침
        await loadUserCategories(userId);
      } else {
        _error = result.error;
      }
    } catch (e) {
      _isLoading = false;
      _error = '카테고리 삭제 중 오류가 발생했습니다.';
      notifyListeners();
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

  // ==================== 표지사진 관리 ====================

  /// 갤러리에서 선택한 이미지로 표지사진을 업데이트합니다
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
        invalidateCache();
        return true;
      } else {
        _error = result.error;
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = '표지사진 업데이트 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 카테고리 내 사진으로 표지사진을 업데이트합니다
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
        invalidateCache();
        return true;
      } else {
        _error = result.error;
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _error = '표지사진 업데이트 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 표지사진을 삭제합니다
  Future<bool> deleteCoverPhoto(String categoryId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _categoryService.deleteCoverPhoto(categoryId);

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        invalidateCache();
        return true;
      } else {
        _error = result.error;
        return false;
      }
    } catch (e) {
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

  /// 카테고리 이름을 조회합니다 (기존 호환성)
  Future<String> getCategoryName(String categoryId) async {
    try {
      final category = await getCategory(categoryId);
      return category?.name ?? '알 수 없는 카테고리';
    } catch (e) {
      return '오류 발생';
    }
  }

  /// 카테고리 사진 스트림 (기존 호환성)
  Stream<List<Map<String, dynamic>>> getPhotosStream(String categoryId) {
    return _categoryService.getCategoryPhotosStream(categoryId);
  }

  /// 사진 문서 ID를 조회합니다 (기존 호환성)
  Future<String?> getPhotoDocumentId(String categoryId, String imageUrl) async {
    try {
      final photos = await getCategoryPhotos(categoryId);
      for (final photo in photos) {
        if (photo['imageUrl'] == imageUrl) {
          return photo['id'] as String?;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 카테고리 프로필 이미지들을 조회합니다 (기존 호환성)
  Future<List<String>> getCategoryProfileImages(
    List<String> mates,
    dynamic authController,
  ) async {
    try {
      final profileImages = <String>[];

      for (final mateUid in mates) {
        try {
          // 각 mate의 UID로 해당 사용자의 프로필 이미지 URL을 가져옴
          final profileUrl = await authController.getUserProfileImageUrlById(
            mateUid,
          );
          if (profileUrl != null && profileUrl.isNotEmpty) {
            profileImages.add(profileUrl);
          }
        } catch (e) {
          // 개별 프로필 이미지 로딩 실패는 무시하고 계속 진행
          debugPrint('사용자 $mateUid의 프로필 이미지 로딩 실패: $e');
          continue;
        }
      }

      return profileImages;
    } catch (e) {
      debugPrint('카테고리 프로필 이미지 로딩 전체 실패: $e');
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
        categoriesWithDetails.add(categoryMap);
      }

      return categoriesWithDetails;
    });
  }

  // ==================== 카테고리 멤버 관리 ====================

  /// 카테고리에 사용자를 추가합니다 (닉네임으로)
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

      if (!result.isSuccess) {
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

  /// 카테고리에 사용자를 추가합니다 (UID로)
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

      if (!result.isSuccess) {
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

  /// 카테고리 초대 수락
  Future<String?> acceptCategoryInvite({
    required String inviteId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _categoryService.acceptPendingInvite(
        inviteId: inviteId,
        userId: userId,
      );

      _isLoading = false;

      if (!result.isSuccess) {
        _error = result.error;
        notifyListeners();
        return null;
      }

      // 캐시 무효화하여 최신 데이터 로드
      invalidateCache();
      notifyListeners();

      return result.data as String?;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// 카테고리 초대 거절
  Future<bool> declineCategoryInvite({
    required String inviteId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _categoryService.declinePendingInvite(
        inviteId: inviteId,
        userId: userId,
      );

      _isLoading = false;
      notifyListeners();

      if (!result.isSuccess) {
        _error = result.error;
        return false;
      }

      return true;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 카테고리 캐시를 무효화합니다.
  void invalidateCache() {
    _lastLoadTime = null;
    _lastLoadedUserId = null;
  }

  /// 사용자별 고정 상태와 새로운 사진 여부에 따라 카테고리 정렬
  void _sortCategoriesForUser(String userId) {
    _userCategories.sort((a, b) => _compareCategoriesForUser(a, b, userId));
  }

  /// 카테고리 비교 로직 (정렬용)
  int _compareCategoriesForUser(
    CategoryDataModel a,
    CategoryDataModel b,
    String userId,
  ) {
    final aIsPinned = a.isPinnedForUser(userId);
    final bIsPinned = b.isPinnedForUser(userId);
    final aHasNewPhoto = a.hasNewPhotoForUser(userId);
    final bHasNewPhoto = b.hasNewPhotoForUser(userId);

    // 1순위: 고정된 카테고리를 상단에
    if (aIsPinned && !bIsPinned) return -1;
    if (!aIsPinned && bIsPinned) return 1;

    // 2순위: 같은 고정 상태 내에서는 새로운 사진이 있는 카테고리를 우선
    if (aIsPinned == bIsPinned) {
      if (aHasNewPhoto && !bHasNewPhoto) return -1;
      if (!aHasNewPhoto && bHasNewPhoto) return 1;
    }

    // 3순위: 같은 조건 내에서는 최신 사진 업로드 시간순 (없으면 생성일시순)
    if (aIsPinned == bIsPinned && aHasNewPhoto == bHasNewPhoto) {
      // 최신 사진 업로드 시간이 있으면 그것을 우선 사용
      if (a.lastPhotoUploadedAt != null && b.lastPhotoUploadedAt != null) {
        return b.lastPhotoUploadedAt!.compareTo(a.lastPhotoUploadedAt!);
      } else if (a.lastPhotoUploadedAt != null) {
        return -1; // a에만 사진 업로드 시간이 있으면 a를 앞으로
      } else if (b.lastPhotoUploadedAt != null) {
        return 1; // b에만 사진 업로드 시간이 있으면 b를 앞으로
      } else {
        // 둘 다 사진 업로드 시간이 없으면 생성일시 최신순
        return b.createdAt.compareTo(a.createdAt);
      }
    }

    return 0;
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
  void clearSearch({bool notify = true}) {
    _searchQuery = '';
    _filteredCategories = [];
    if (notify) {
      notifyListeners();
    }
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

  /// 외부에서도 검색어 매칭 여부를 재사용할 수 있도록 공개 메서드 제공
  bool matchesSearchQuery(
    CategoryDataModel category,
    String query, {
    String? currentUserId,
  }) {
    if (query.isEmpty) {
      return true;
    }

    final displayName =
        currentUserId != null
            ? category.getDisplayName(currentUserId)
            : category.name;
    return _matchesSearch(displayName, query);
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

  /// 사용자의 카테고리 조회 시간을 업데이트합니다

  Future<void> updateUserViewTime({
    required String categoryId,
    required String userId,
  }) async {
    try {
      await _categoryService.updateUserViewTime(
        categoryId: categoryId,
        userId: userId,
      );
    } catch (e) {
      debugPrint('[CategoryController] updateUserViewTime 오류: $e');
    }
  }
}
