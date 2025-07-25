import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../theme/theme.dart';
import 'widgets/archive_card_widget.dart';
import 'widgets/archive_responsive_helper.dart';

// 나의 아카이브 화면
// 현재 사용자의 아카이브 목록을 표시
// 아카이브를 클릭하면 아카이브 상세 화면으로 이동
class MyArchivesScreen extends StatefulWidget {
  const MyArchivesScreen({super.key});

  @override
  State<MyArchivesScreen> createState() => _MyArchivesScreenState();
}

class _MyArchivesScreenState extends State<MyArchivesScreen> {
  String? uID;
  // 카테고리별 프로필 이미지 캐시
  final Map<String, List<String>> _categoryProfileImages = {};

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    final authController = Provider.of<AuthController>(context, listen: false);
    authController.getIdFromFirestore().then((value) {
      setState(() {
        uID = value;
      });
    });
  }

  // 카테고리에 대한 프로필 이미지를 가져오는 함수
  Future<void> _loadProfileImages(String categoryId, List<String> mates) async {
    // Skip if already loaded
    if (_categoryProfileImages.containsKey(categoryId)) {
      return;
    }

    final authController = Provider.of<AuthController>(context, listen: false);
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    try {
      final profileImages = await categoryController.getCategoryProfileImages(
        mates,
        authController,
      );
      setState(() {
        _categoryProfileImages[categoryId] = profileImages;
      });
    } catch (e) {
      debugPrint('프로필 이미지 로딩 오류: $e');
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
    if (uID == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: Consumer<CategoryController>(
        builder: (context, categoryController, child) {
          // 사용자 카테고리 로드 (한 번만 로드)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            categoryController.loadUserCategories(uID!);
          });

          // 로딩 중일 때
          if (categoryController.isLoading &&
              categoryController.userCategories.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          // 에러가 생겼을 때
          if (categoryController.error != null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          // 필터링된 카테고리 가져오기
          final allCategories = categoryController.userCategories;

          // 사용자 카테고리만 필터링합니다.
          final userCategories =
              allCategories
                  .where(
                    (category) =>
                        category.mates.every((element) => element == uID),
                  )
                  .toList();

          if (userCategories.isEmpty) {
            return Center(
              child: Text(
                categoryController.searchQuery.isNotEmpty
                    ? '검색 결과가 없습니다.'
                    : '등록된 카테고리가 없습니다.',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          // 모든 카테고리에 대해 프로필 이미지 로드 요청
          for (var category in userCategories) {
            final categoryId = category.id;
            final mates = category.mates;
            _loadProfileImages(categoryId, mates);
          }

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
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: aspectRatio,
                      mainAxisSpacing:
                          ArchiveResponsiveHelper.getMainAxisSpacing(context),
                      crossAxisSpacing:
                          ArchiveResponsiveHelper.getCrossAxisSpacing(context),
                    ),
                    itemCount: userCategories.length,
                    itemBuilder: (context, index) {
                      final category = userCategories[index];
                      final categoryMap =
                          category.toFirestore()..['id'] = category.id;
                      final categoryId = category.id;
                      final profileImages =
                          _categoryProfileImages[categoryId] ?? [];
                      final imageSize = cardDimensions['imageSize']!;

                      return ArchiveCardWidget(
                        category: categoryMap,
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
