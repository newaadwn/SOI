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
  ///
  /// [userId] 카테고리를 로드할 사용자 ID
  /// [forceReload] 캐시를 무시하고 강제로 새로고침할지 여부
  Future<void> loadUserCategories(
    String userId, {
    bool forceReload = false,
  }) async {
    // 유효성 검사
    if (userId.isEmpty) {
      // debugPrint('[CategoryController] userId가 비어있음 - 로드 중단');
      return;
    }

    // 캐시 유효성 검사
    final now = DateTime.now();
    final isCacheValid =
        _lastLoadTime != null && now.difference(_lastLoadTime!) < _cacheTimeout;

    // 중복 로딩 방지 제거 - 동시 로딩 허용
    // 여러 화면에서 동시에 호출할 수 있으므로 제한하지 않음
    // debugPrint('[CategoryController] 로딩 상태: $_isLoading');

    // 캐시된 데이터 사용 가능 여부 확인
    if (!forceReload && _lastLoadedUserId == userId && isCacheValid) {
      // debugPrint('[CategoryController] 캐시된 데이터 사용 - userId: $userId, 카테고리 수: ${_userCategories.length}');
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // debugPrint('[CategoryController] 카테고리 로드 시작 - userId: $userId');
      // debugPrint('[CategoryController] 현재 _userCategories 수: ${_userCategories.length}');
      // debugPrint('[CategoryController] _isLoading 상태: $_isLoading');

      // 서비스에서 카테고리 목록 가져오기
      final categories = await _categoryService.getUserCategories(userId);
      // debugPrint('[CategoryController] 서비스에서 받은 카테고리 수: ${categories.length}');

      _userCategories = categories;
      // debugPrint('[CategoryController] _userCategories에 할당 후: ${_userCategories.length}');

      // 캐시 정보 업데이트
      _lastLoadedUserId = userId;
      _lastLoadTime = DateTime.now();

      _isLoading = false;
      notifyListeners();

      // debugPrint('[CategoryController] 카테고리 로드 완료 - 최종 개수: ${_userCategories.length}');
      // debugPrint('[CategoryController] _isLoading 최종 상태: $_isLoading');
    } catch (e) {
      // 에러 처리
      // debugPrint('[CategoryController] 카테고리 로드 오류: $e');
      _error = '카테고리를 불러오는 중 오류가 발생했습니다.';
      _userCategories = [];
      _isLoading = false;
      notifyListeners();
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

  /// 새 카테고리를 생성합니다
  ///
  /// [name] 카테고리 이름
  /// [mates] 멤버 목록 (UID 리스트)
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
  ///
  /// [categoryId] 수정할 카테고리 ID
  /// [name] 새로운 카테고리 이름 (선택사항)
  /// [mates] 새로운 멤버 목록 (선택사항)
  /// [isPinned] 고정 상태 (선택사항)
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

  /// 카테고리 고정/해제를 토글합니다
  ///
  /// [categoryId] 토글할 카테고리 ID
  /// [currentPinStatus] 현재 고정 상태
  Future<void> togglePinCategory(
    String categoryId,
    bool currentPinStatus,
  ) async {
    try {
      final newPinStatus = !currentPinStatus;

      // 즉시 UI 업데이트를 위한 로컬 상태 변경
      final categoryIndex = _userCategories.indexWhere(
        (cat) => cat.id == categoryId,
      );

      if (categoryIndex != -1) {
        // 카테고리 상태 업데이트
        _userCategories[categoryIndex] = CategoryDataModel(
          id: _userCategories[categoryIndex].id,
          name: _userCategories[categoryIndex].name,
          mates: _userCategories[categoryIndex].mates,
          createdAt: _userCategories[categoryIndex].createdAt,
          categoryPhotoUrl: _userCategories[categoryIndex].categoryPhotoUrl,
          isPinned: newPinStatus,
        );

        // 고정 상태에 따라 재정렬 (고정된 카테고리가 상단에)
        _userCategories.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        notifyListeners();
      }

      _isLoading = true;

      // 서버에 변경사항 저장
      final result = await _categoryService.updateCategory(
        categoryId: categoryId,
        isPinned: newPinStatus,
      );

      _isLoading = false;

      if (!result.isSuccess) {
        // 실패 시 이전 상태로 롤백
        if (categoryIndex != -1) {
          _userCategories[categoryIndex] = CategoryDataModel(
            id: _userCategories[categoryIndex].id,
            name: _userCategories[categoryIndex].name,
            mates: _userCategories[categoryIndex].mates,
            createdAt: _userCategories[categoryIndex].createdAt,
            categoryPhotoUrl: _userCategories[categoryIndex].categoryPhotoUrl,
            isPinned: currentPinStatus,
          );

          // 원래 상태로 재정렬
          _userCategories.sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
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
        _userCategories[categoryIndex] = CategoryDataModel(
          id: _userCategories[categoryIndex].id,
          name: _userCategories[categoryIndex].name,
          mates: _userCategories[categoryIndex].mates,
          createdAt: _userCategories[categoryIndex].createdAt,
          categoryPhotoUrl: _userCategories[categoryIndex].categoryPhotoUrl,
          isPinned: currentPinStatus,
        );

        _userCategories.sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });

        notifyListeners();
      }
    }
  }

  /// 카테고리에서 나가기를 처리합니다
  /// 마지막 멤버인 경우 카테고리가 자동으로 삭제됩니다
  ///
  /// [categoryId] 나갈 카테고리 ID
  /// [userId] 나가는 사용자 ID
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
  ///
  /// [categoryId] 삭제할 카테고리 ID
  /// [userId] 요청하는 사용자 ID
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
  ///
  /// [categoryId] 카테고리 ID
  /// [imageFile] 업로드할 이미지 파일
  /// Returns: 성공 여부
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
  ///
  /// [categoryId] 카테고리 ID
  /// [photoUrl] 사용할 사진 URL
  /// Returns: 성공 여부
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
  ///
  /// [categoryId] 카테고리 ID
  /// Returns: 성공 여부
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
  ///
  /// [categoryId] 카테고리 ID
  /// Returns: 카테고리 이름 또는 기본값
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
  ///
  /// [categoryId] 카테고리 ID
  /// [imageUrl] 이미지 URL
  /// Returns: 매칭되는 사진의 문서 ID
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
  ///
  /// [mates] 멤버 목록
  /// [authController] 인증 컨트롤러
  /// Returns: 프로필 이미지 URL 목록
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
        // 예: 첫 번째 사진, 사진 개수 등
        categoriesWithDetails.add(categoryMap);
      }

      return categoriesWithDetails;
    });
  }

  // ==================== 카테고리 멤버 관리 ====================

  /// 카테고리에 사용자를 추가합니다 (닉네임으로)
  ///
  /// [categoryId] 카테고리 ID
  /// [nickName] 추가할 사용자 닉네임
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
  ///
  /// [categoryId] 카테고리 ID
  /// [uid] 추가할 사용자 UID
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
