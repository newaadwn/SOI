import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/category_controller.dart';
import '../../../controllers/photo_controller.dart';
import '../../../models/category_data_model.dart';
import '../../../models/photo_data_model.dart';
import '../managers/feed_data_manager.dart';

/// 📡 피드 데이터 로딩을 담당하는 서비스 클래스
/// 카테고리, 사진, 프로필 정보 로딩 및 무한 스크롤 처리
class FeedLoadingService {
  /// 🚀 초기 피드 데이터 로드 (카테고리 + 사진)
  static Future<void> loadInitialFeedData(
    BuildContext context,
    FeedDataManager dataManager,
  ) async {
    try {
      dataManager.setLoading(true);

      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );
      final photoController = Provider.of<PhotoController>(
        context,
        listen: false,
      );

      final currentUserId = authController.getUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('로그인된 사용자를 찾을 수 없습니다.');
      }

      debugPrint('🔍 [FEED_LOADING] 현재 사용자 ID: "$currentUserId"');

      // 현재 사용자 프로필 로드
      await _loadCurrentUserProfile(authController, currentUserId, dataManager);

      // 카테고리와 사진들을 무한 스크롤로 로드
      await _loadCategoriesAndPhotosWithPagination(
        context,
        categoryController,
        photoController,
        currentUserId,
        dataManager,
      );
    } catch (e) {
      debugPrint('❌ 초기 피드 데이터 로드 실패: $e');
      dataManager.setLoading(false);
    }
  }

  /// 📷 카테고리에서 사진 로드 (백그라운드 로딩 감지용)
  static Future<void> loadPhotosFromCategories(
    BuildContext context,
    FeedDataManager dataManager,
  ) async {
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    try {
      final photoController = Provider.of<PhotoController>(
        context,
        listen: false,
      );
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final currentUserId = authController.getUserId;

      if (currentUserId == null) return;

      // 이미 로드된 카테고리 정보를 사용하여 사진만 로드
      final userCategories = categoryController.userCategories;
      if (userCategories.isNotEmpty) {
        final categoryIds =
            userCategories.map((category) => category.id).toList();
        await photoController.loadPhotosFromAllCategoriesInitial(categoryIds);
        _updatePhotosFromController(
          photoController,
          userCategories,
          currentUserId,
          dataManager,
        );
      }
    } catch (e) {
      debugPrint('❌ 백그라운드 사진 로드 실패: $e');
    }
  }

  /// ♾️ 추가 사진 로드 (무한 스크롤)
  static Future<void> loadMorePhotos(
    BuildContext context,
    FeedDataManager dataManager,
  ) async {
    final photoController = Provider.of<PhotoController>(
      context,
      listen: false,
    );
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    final authController = Provider.of<AuthController>(context, listen: false);

    final userCategories = categoryController.userCategories;
    if (userCategories.isEmpty) return;

    final categoryIds = userCategories.map((category) => category.id).toList();
    await photoController.loadMorePhotos(categoryIds);

    // 새로 로드된 데이터를 UI에 반영
    final currentUserId = authController.getUserId;
    if (currentUserId != null) {
      _updatePhotosFromController(
        photoController,
        userCategories,
        currentUserId,
        dataManager,
      );

      // 새로 로드된 사진들의 사용자 정보 로드
      await loadUserProfileForPhoto(context, currentUserId, dataManager);
    }
  }

  /// 👤 특정 사용자의 프로필 정보 로드
  static Future<void> loadUserProfileForPhoto(
    BuildContext context,
    String userId,
    FeedDataManager dataManager,
  ) async {
    if (dataManager.profileLoadingStates[userId] == true ||
        dataManager.userIds.containsKey(userId)) {
      return;
    }

    dataManager.setProfileLoadingState(userId, true);

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(userId);
      final userInfo = await authController.getUserInfo(userId);

      dataManager.updateUserProfileImage(userId, profileImageUrl);
      dataManager.updateUserName(
        userId,
        userInfo?.id ?? userInfo?.name ?? userId,
      );
      dataManager.setProfileLoadingState(userId, false);
    } catch (e) {
      debugPrint('프로필 정보 로드 실패 (userId: $userId): $e');
      dataManager.updateUserName(userId, userId);
      dataManager.setProfileLoadingState(userId, false);
    }
  }

  /// 🔄 사용자 프로필 이미지 강제 리프레시
  static Future<void> refreshUserProfileImage(
    BuildContext context,
    String userId,
    FeedDataManager dataManager,
  ) async {
    final authController = Provider.of<AuthController>(context, listen: false);
    try {
      dataManager.setProfileLoadingState(userId, true);
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(userId);
      dataManager.updateUserProfileImage(userId, profileImageUrl);
      dataManager.setProfileLoadingState(userId, false);
    } catch (e) {
      dataManager.setProfileLoadingState(userId, false);
    }
  }

  // ==================== Private Methods ====================

  /// 현재 사용자 프로필 로드
  static Future<void> _loadCurrentUserProfile(
    AuthController authController,
    String currentUserId,
    FeedDataManager dataManager,
  ) async {
    if (!dataManager.userProfileImages.containsKey(currentUserId)) {
      try {
        final currentUserProfileImage = await authController
            .getUserProfileImageUrlWithCache(currentUserId);
        dataManager.updateUserProfileImage(
          currentUserId,
          currentUserProfileImage,
        );
        debugPrint(
          '[PROFILE] 현재 사용자 프로필 이미지 로드됨: $currentUserId -> $currentUserProfileImage',
        );
      } catch (e) {
        debugPrint('[ERROR] 현재 사용자 프로필 이미지 로드 실패: $e');
      }
    }
  }

  /// 카테고리와 사진들을 무한 스크롤로 로드
  static Future<void> _loadCategoriesAndPhotosWithPagination(
    BuildContext context,
    CategoryController categoryController,
    PhotoController photoController,
    String currentUserId,
    FeedDataManager dataManager,
  ) async {
    // 카테고리 로드 (첫 로드만 force로, 이후는 캐시 사용)
    await categoryController.loadUserCategories(
      currentUserId,
      forceReload: false, // 캐시 활용하여 불필요한 재로딩 방지
    );

    // 카테고리 로딩 대기 (최대 5초로 제한)
    int attempts = 0;
    const maxAttempts = 50;
    while (categoryController.isLoading && attempts < maxAttempts) {
      debugPrint('🔄 카테고리 로딩 대기 중... ($attempts/$maxAttempts)');
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (categoryController.isLoading) {
      debugPrint('⚠️ 카테고리 로딩 타임아웃 - 현재 상태로 진행');
      return; // 타임아웃 시 더 이상 진행하지 않음
    }

    final userCategories = categoryController.userCategories;
    debugPrint('[INFINITE_SCROLL] 사용자가 속한 카테고리 수: ${userCategories.length}');

    if (userCategories.isEmpty) {
      dataManager.updateAllPhotos([]);
      dataManager.setLoading(false);
      return;
    }

    // 카테고리 ID 목록 생성
    final categoryIds = userCategories.map((category) => category.id).toList();

    // PhotoController로 무한 스크롤 초기 로드
    await photoController.loadPhotosFromAllCategoriesInitial(categoryIds);

    // PhotoController의 사진을 UI 형태로 변환
    _updatePhotosFromController(
      photoController,
      userCategories,
      currentUserId,
      dataManager,
    );

    await loadUserProfileForPhoto(context, currentUserId, dataManager);

    dataManager.setLoading(false);
  }

  /// PhotoController의 데이터를 UI 형태로 변환하고 업데이트
  static void _updatePhotosFromController(
    PhotoController photoController,
    List<CategoryDataModel> userCategories,
    String currentUserId,
    FeedDataManager dataManager,
  ) {
    final photos = photoController.photos;
    final List<Map<String, dynamic>> allPhotos = [];

    for (PhotoDataModel photo in photos) {
      // 해당 사진의 카테고리 정보 찾기
      final category =
          userCategories.where((cat) => cat.id == photo.categoryId).firstOrNull;

      if (category != null) {
        allPhotos.add({
          'photo': photo,
          'categoryName': category.name,
          'categoryId': category.id,
        });
      }
    }

    debugPrint('[INFINITE_SCROLL] UI 업데이트: ${allPhotos.length}개 사진');
    dataManager.updateAllPhotos(allPhotos);
  }
}
