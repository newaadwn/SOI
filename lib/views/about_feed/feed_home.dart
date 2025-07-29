import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';
import '../../models/photo_data_model.dart';
import 'managers/feed_data_manager.dart';
import 'services/feed_loading_service.dart';
import 'widgets/feed_photo_card.dart';
import 'widgets/feed_empty_state.dart';

/// 📱 피드 홈 스크린 - 전면 리팩토링된 버전
/// 기존 1328줄에서 200줄로 단순화
class FeedHomeScreen extends StatefulWidget {
  const FeedHomeScreen({super.key});

  @override
  State<FeedHomeScreen> createState() => _FeedHomeScreenState();
}

class _FeedHomeScreenState extends State<FeedHomeScreen> {
  final PageController _pageController = PageController();
  late FeedDataManager _dataManager;

  @override
  void initState() {
    super.initState();
    _dataManager = FeedDataManager();
    _initializeFeed();
    _setupInfiniteScroll();
  }

  @override
  void dispose() {
    _dataManager.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// 피드 초기화
  void _initializeFeed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      // 카테고리 자동 업데이트 리스너 제거 - 수동 새로고침만 지원
      // _setupCategoryListener();
    });
  }

  /// 초기 데이터 로드
  Future<void> _loadInitialData() async {
    if (!mounted) return;

    await FeedLoadingService.loadInitialFeedData(context, _dataManager);

    if (mounted) {
      setState(() {});
    }
  }

  // 카테고리 자동 업데이트 관련 메서드들 주석 처리
  /*
  /// 카테고리 변경 리스너 설정
  void _setupCategoryListener() {
    if (_isCategoryListenerActive) return;
    _isCategoryListenerActive = true;

    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    categoryController.addListener(_onCategoryChanged);
  }

  /// 카테고리 변경 핸들러
  void _onCategoryChanged() {
    debugPrint('🔄 카테고리 변경 감지됨');
    _loadInitialData();
  }
  */

  /// 무한 스크롤 설정
  void _setupInfiniteScroll() {
    _pageController.addListener(() {
      if (_pageController.position.pixels >=
          _pageController.position.maxScrollExtent - 200) {
        _loadMorePhotos();
      }
    });
  }

  /// 추가 사진 로드
  Future<void> _loadMorePhotos() async {
    if (!mounted) return;

    await FeedLoadingService.loadMorePhotos(context, _dataManager);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: SafeArea(child: _buildFeedContent()),
    );
  }

  /// 피드 콘텐츠 빌드
  Widget _buildFeedContent() {
    // 로딩 상태
    if (_dataManager.isLoading) {
      return const FeedEmptyState(isLoading: true);
    }

    // 빈 상태
    if (_dataManager.allPhotos.isEmpty) {
      return FeedEmptyState(isLoading: false, onRetry: _loadInitialData);
    }

    // 피드 리스트 (Pull-to-Refresh 포함)
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: Colors.black,
      onRefresh: _handleRefresh,
      child: _buildPhotoFeed(),
    );
  }

  /// 🔄 Pull-to-Refresh 핸들러
  Future<void> _handleRefresh() async {
    debugPrint('🔄 Pull-to-Refresh 시작');

    // 데이터 새로고침
    await _loadInitialData();

    // 새로고침 완료 후 첫 번째 페이지로 이동
    if (_pageController.hasClients && _dataManager.allPhotos.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 100)); // 데이터 반영 대기
      if (_pageController.page != 0) {
        await _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    debugPrint('✅ Pull-to-Refresh 완료');
  }

  /// 사진 피드 빌드
  Widget _buildPhotoFeed() {
    return Consumer3<CategoryController, PhotoController, AuthController>(
      builder: (
        context,
        categoryController,
        photoController,
        authController,
        child,
      ) {
        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount:
              _dataManager.allPhotos.length +
              (photoController.hasMore ? 1 : 0), // 더 있으면 로딩 인디케이터 추가
          itemBuilder: (context, index) {
            // 로딩 인디케이터
            if (index >= _dataManager.allPhotos.length) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            // 사진 카드
            return _buildPhotoCardItem(index);
          },
        );
      },
    );
  }

  /// 개별 사진 카드 아이템 빌드
  Widget _buildPhotoCardItem(int index) {
    final photoData = _dataManager.allPhotos[index];
    final photo = photoData['photo'] as PhotoDataModel;
    final categoryName = photoData['categoryName'] as String;

    return FeedPhotoCard(
      photo: photo,
      categoryName: categoryName,
      dataManager: _dataManager,
      index: index,
    );
  }
}
