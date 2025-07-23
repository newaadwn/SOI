/*
 * SharedArchivesScreen
 * 
 * 이 화면은 사용자가 다른 사용자와 공유한 카테고리(아카이빙)를 보여주는 화면입니다.
 * 
 * 기능:
 * 1. 사용자의 닉네임을 Firebase에서 가져옵니다.
 * 2. 현재 사용자가 다른 사용자들과 공유하고 있는 카테고리만 필터링하여 표시합니다.
 * 3. 각 카테고리는 그리드 형태로 표시되며, 각 항목에는 대표 이미지와 카테고리 이름이 표시됩니다.
 * 4. 카테고리 참여자들의 프로필 이미지가 작은 원형 아이콘으로 표시됩니다.
 * 5. 카테고리를 탭하면 해당 카테고리의 사진을 모두 볼 수 있는 CategoryPhotosScreen으로 이동합니다.
 * 
 * 데이터 흐름:
 * - AuthController을 통해 사용자의 닉네임을 가져옵니다.
 * - CategoryController을 통해 사용자가 속한 카테고리 정보를 실시간으로 스트리밍합니다.
 * - 카테고리 중 현재 사용자와 다른 사용자가 함께 있는 카테고리만 필터링합니다.
 * 
 * 주요 위젯:
 * - GridView: 공유 카테고리를 그리드 형태로 표시합니다.
 * - StreamBuilder: Firebase에서 실시간으로 카테고리 데이터를 가져옵니다.
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/category_controller.dart';
import '../../theme/theme.dart';
import '../../controllers/auth_controller.dart';
import 'widgets/archive_card_widget.dart';
import 'widgets/archive_responsive_helper.dart';

class SharedArchivesScreen extends StatefulWidget {
  const SharedArchivesScreen({super.key});

  @override
  State<SharedArchivesScreen> createState() => _SharedArchivesScreenState();
}

class _SharedArchivesScreenState extends State<SharedArchivesScreen> {
  String? nickName;
  // 카테고리별 프로필 이미지 캐시
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
    final authController = Provider.of<AuthController>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: categoryController.streamUserCategoriesWithDetails(
          nickName!,
          authController,
        ),
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
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final categories = snapshot.data ?? [];
          // 사용자 카테고리만 필터링합니다.
          final userCategories =
              categories
                  .where(
                    (category) =>
                        ((category['mates'] as List).contains(nickName) &&
                            category['mates'].length != 1),
                  )
                  .toList();

          if (userCategories.isEmpty) {
            return const Center(
              child: Text(
                '등록된 카테고리가 없습니다.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // 모든 카테고리에 대해 프로필 이미지 로드 요청
          for (var category in userCategories) {
            final categoryId = category['id'] as String;
            final mates = (category['mates'] as List).cast<String>();
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
