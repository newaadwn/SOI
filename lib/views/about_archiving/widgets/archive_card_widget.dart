import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/category_controller.dart';
import '../../../models/category_data_model.dart';
import '../category_photos_screen.dart';
import 'archive_responsive_helper.dart';

/// 🎨 아카이브 카드 공통 위젯 (반응형 디자인 + 실시간 업데이트)
/// 168x229 비율의 카드 UI를 제공하며, 화면 크기에 따라 적응합니다.
class ArchiveCardWidget extends StatelessWidget {
  final String categoryId;
  final List<String> profileImages;
  final double imageSize;

  const ArchiveCardWidget({
    super.key,
    required this.categoryId,
    required this.profileImages,
    required this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryController>(
      builder: (context, categoryController, child) {
        return StreamBuilder<CategoryDataModel?>(
          stream: categoryController.streamSingleCategory(categoryId),
          builder: (context, snapshot) {
            final category = snapshot.data;
            if (category == null) {
              return _buildErrorCard(context);
            }

            return _buildCategoryCard(context, category);
          },
        );
      },
    );
  }

  /// 실제 카테고리 카드 빌드
  Widget _buildCategoryCard(BuildContext context, CategoryDataModel category) {
    // 반응형 값들 계산
    final isSmallScreen = ArchiveResponsiveHelper.isSmallScreen(context);
    final isLargeScreen = ArchiveResponsiveHelper.isLargeScreen(context);

    debugPrint('category.categoryPhotoUrl: ${category.categoryPhotoUrl}');

    // 화면 크기별 조정값들
    final borderRadius =
        isSmallScreen
            ? 5.0
            : isLargeScreen
            ? 8.0
            : 6.61;
    final topPadding =
        isSmallScreen
            ? 8.0
            : isLargeScreen
            ? 12.0
            : 10.57;
    final bottomPadding =
        isSmallScreen
            ? 8.0
            : isLargeScreen
            ? 12.0
            : 10.0;
    final horizontalPadding =
        isSmallScreen
            ? 8.0
            : isLargeScreen
            ? 12.0
            : 10.65;
    final iconSize =
        isSmallScreen
            ? 30.0
            : isLargeScreen
            ? 50.0
            : 40.0;
    final strokeWidth = isSmallScreen ? 1.5 : 2.0;

    return Container(
      decoration: ShapeDecoration(
        color: const Color(0xFF1C1C1C), // Figma 배경색
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryPhotosScreen(category: category),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.only(
            top: topPadding,
            bottom: bottomPadding,
            left: horizontalPadding,
            right: horizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🖼️ 메인 이미지 (실시간 업데이트)
              Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: Colors.grey[300],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child:
                      (category.categoryPhotoUrl != null &&
                              category.categoryPhotoUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                            key: ValueKey(
                              '${category.id}_${category.categoryPhotoUrl}',
                            ), // 카테고리ID + URL로 고유 키 생성
                            imageUrl: category.categoryPhotoUrl!,
                            cacheKey:
                                '${category.id}_${category.categoryPhotoUrl}', // 캐시 키도 동일하게 설정
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: strokeWidth,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Container(
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.error,
                                    color: Colors.grey,
                                    size: iconSize * 0.6,
                                  ),
                                ),
                          )
                          : Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: iconSize,
                            ),
                          ),
                ),
              ),

              const Spacer(),

              // 📝 카테고리 이름과 더보기 버튼 행
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 카테고리 이름 (반응형 폰트 크기)
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        color: const Color(0xFFF9F9F9), // Figma 텍스트 색상
                        fontSize:
                            isSmallScreen
                                ? 12.0
                                : isLargeScreen
                                ? 16.0
                                : 14.0,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.4, // Figma letter spacing
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 더보기 버튼 (반응형 크기)
                  InkWell(
                    onTap: () {
                      debugPrint('더보기 버튼 클릭됨');
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size:
                            isSmallScreen
                                ? 14.0
                                : isLargeScreen
                                ? 22.0
                                : 22.0,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: isSmallScreen ? 6.0 : 8.0),

              // 👥 프로필 이미지들 (반응형으로 업데이트)
              ArchiveProfileRowWidget(
                profileImages: profileImages,
                isSmallScreen: isSmallScreen,
                isLargeScreen: isLargeScreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 에러 카드
  Widget _buildErrorCard(BuildContext context) {
    final isSmallScreen = ArchiveResponsiveHelper.isSmallScreen(context);
    final isLargeScreen = ArchiveResponsiveHelper.isLargeScreen(context);

    final borderRadius =
        isSmallScreen
            ? 5.0
            : isLargeScreen
            ? 8.0
            : 6.61;

    return Container(
      decoration: ShapeDecoration(
        color: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: isSmallScreen ? 1.5 : 2.0,
        ),
      ),
    );
  }
}

/// 🧑‍🤝‍🧑 프로필 이미지 행 위젯 (Figma 디자인 기준)
class ArchiveProfileRowWidget extends StatelessWidget {
  final List<String> profileImages;
  final bool isSmallScreen;
  final bool isLargeScreen;

  const ArchiveProfileRowWidget({
    super.key,
    required this.profileImages,
    required this.isSmallScreen,
    required this.isLargeScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        // 반응형 프로필 이미지 크기
        final profileSize =
            isSmallScreen
                ? 16.0
                : isLargeScreen
                ? 22.0
                : 19.0;
        final iconSize =
            isSmallScreen
                ? 10.0
                : isLargeScreen
                ? 14.0
                : 12.0;
        final borderWidth = isSmallScreen ? 0.3 : 0.5;
        final margin = isSmallScreen ? 3.0 : 4.0;

        // 이미지가 없거나 비어있으면 기본 이미지 하나만 표시
        if (profileImages.isEmpty) {
          return SizedBox(
            width: profileSize,
            height: profileSize,
            child: CircleAvatar(
              radius: profileSize / 2,
              backgroundColor: Colors.grey[400],
              child: Icon(Icons.person, color: Colors.white, size: iconSize),
            ),
          );
        }

        // 최대 3개까지만 표시하도록 제한
        final displayImages = profileImages.take(3).toList();

        return SizedBox(
          height: profileSize,
          child: Row(
            children:
                displayImages.asMap().entries.map<Widget>((entry) {
                  final index = entry.key;
                  final imageUrl = entry.value;

                  return Container(
                    margin: EdgeInsets.only(
                      right: index < displayImages.length - 1 ? margin : 0.0,
                    ),
                    child: Container(
                      width: profileSize,
                      height: profileSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: borderWidth,
                        ),
                      ),
                      child: ClipOval(
                        child:
                            imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) => Container(
                                        color: Colors.grey[400],
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: iconSize,
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Container(
                                        color: Colors.grey[400],
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: iconSize,
                                        ),
                                      ),
                                )
                                : Container(
                                  color: Colors.grey[400],
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: iconSize,
                                  ),
                                ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}
