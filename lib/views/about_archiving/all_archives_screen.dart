import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../theme/theme.dart';
import 'widgets/archive_card_widget.dart';
import 'widgets/archive_responsive_helper.dart';

// 전체 아카이브 화면
// 모든 사용자의 아카이브 목록을 표시
// 아카이브를 클릭하면 아카이브 상세 화면으로 이동
class AllArchivesScreen extends StatefulWidget {
  const AllArchivesScreen({super.key});

  @override
  State<AllArchivesScreen> createState() => _AllArchivesScreenState();
}

class _AllArchivesScreenState extends State<AllArchivesScreen> {
  String? nickName;
  final Map<String, List<String>> _categoryProfileImages = {};

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    final authController = Provider.of<AuthController>(context, listen: false);
    authController.getIdFromFirestore().then((value) {
      setState(() {
        nickName = value;
      });
    });

    // AuthController의 변경사항을 감지하여 프로필 이미지 캐시 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      authController.addListener(_onAuthControllerChanged);
    });
  }

  @override
  void dispose() {
    final authController = Provider.of<AuthController>(context, listen: false);
    authController.removeListener(_onAuthControllerChanged);
    super.dispose();
  }

  /// AuthController 변경 감지 시 프로필 이미지 캐시 무효화
  void _onAuthControllerChanged() {
    debugPrint('🔄 AuthController 변경 감지 - 아카이브 프로필 이미지 캐시 무효화');
    setState(() {
      _categoryProfileImages.clear(); // 모든 프로필 이미지 캐시 무효화
    });
  }

  // 카테고리에 대한 프로필 이미지를 가져오는 함수
  Future<void> _loadProfileImages(String categoryId, List<String> mates) async {
    // 이미 로드된 경우에도 AuthController 변경에 의해 캐시가 무효화되면 다시 로드
    if (_categoryProfileImages.containsKey(categoryId)) {
      return;
    }

    final authController = Provider.of<AuthController>(context, listen: false);
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    try {
      debugPrint('🔄 카테고리 $categoryId의 프로필 이미지 로드 시작');
      final profileImages = await categoryController.getCategoryProfileImages(
        mates,
        authController,
      );
      setState(() {
        _categoryProfileImages[categoryId] = profileImages;
      });
      debugPrint('✅ 카테고리 $categoryId의 프로필 이미지 로드 완료: ${profileImages.length}개');
    } catch (e) {
      debugPrint('❌ 프로필 이미지 로딩 오류: $e');
      setState(() {
        _categoryProfileImages[categoryId] = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 값들 계산 (헬퍼 클래스 사용)
    final crossAxisCount = ArchiveResponsiveHelper.getGridCrossAxisCount(
      context,
    );
    final aspectRatio = ArchiveResponsiveHelper.getGridAspectRatio();
    final cardDimensions = ArchiveResponsiveHelper.getCardDimensions(context);

    // 만약 닉네임을 아직 못 가져왔다면 로딩 중이에요.
    if (nickName == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 카테고리 정보를 가져오는 스트림을 구독해요.
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // 기존의 streamUserCategoriesWithDetails 대신 streamUserCategories 함수 사용
        stream: categoryController.streamUserCategoriesAsMap(nickName!),
        builder: (context, snapshot) {
          // 데이터가 불러오는 중일때
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          // 에러가 생겼을 때
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                '카테고리 로딩 중 오류가 발생했습니다.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          // 데이터 없으면
          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return const Center(
              child: Text(
                '등록된 카테고리가 없습니다.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // 모든 카테고리에 대해 프로필 이미지 로드 요청
          for (var category in categories) {
            final categoryId = category['id'] as String;
            final mates = (category['mates'] as List).cast<String>();
            _loadProfileImages(categoryId, mates);
          }

          // 데이터가 있으면 화면을 스크롤할 수 있도록 만듭니다.
          return Padding(
            padding: ArchiveResponsiveHelper.getGridPadding(context),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height:
                        ArchiveResponsiveHelper.getResponsiveHeight(context) *
                        0.01,
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: aspectRatio, // Figma 비율 사용
                      mainAxisSpacing:
                          ArchiveResponsiveHelper.getMainAxisSpacing(context),
                      crossAxisSpacing:
                          ArchiveResponsiveHelper.getCrossAxisSpacing(context),
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final categoryId = category['id'] as String;
                      final profileImages =
                          _categoryProfileImages[categoryId] ?? [];
                      final imageSize = cardDimensions['imageSize']!;

                      return ArchiveCardWidget(
                        category: category,
                        profileImages: profileImages,
                        imageSize: imageSize,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
