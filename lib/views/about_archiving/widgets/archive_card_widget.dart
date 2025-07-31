import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/category_controller.dart';
import '../../../models/category_data_model.dart';
import '../category_photos_screen.dart';
import 'archive_profile_row_widget.dart';
import 'archive_responsive_helper.dart';
import 'archive_popup_menu_widget.dart';

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
            // 스트림 연결 상태 확인
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingCard(context);
            }

            // 에러가 있거나 카테고리가 삭제된 경우
            if (snapshot.hasError ||
                snapshot.connectionState == ConnectionState.done ||
                snapshot.hasData == false ||
                snapshot.data == null) {
              // 카드를 완전히 숨김 (삭제됨)
              return const SizedBox.shrink();
            }

            final category = snapshot.data!;
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

    // 카테고리 사진 URL 확인

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
                child: Stack(
                  children: [
                    // 메인 이미지
                    ClipRRect(
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
                                width: imageSize,
                                height: imageSize,
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
                                width: imageSize,
                                height: imageSize,
                                child: Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                  size: iconSize,
                                ),
                              ),
                    ),

                    // 📌 고정 아이콘 (고정된 경우에만 표시)
                    if (category.isPinned)
                      Positioned(
                        top: 8.0,
                        left: 8.0,
                        child: Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Icon(
                            Icons.push_pin,
                            color: Colors.white,
                            size: isSmallScreen ? 12.0 : 14.0,
                          ),
                        ),
                      ),
                  ],
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
                  Builder(
                    builder: (buttonContext) {
                      return InkWell(
                        onTap: () {
                          ArchivePopupMenuWidget.showArchivePopupMenu(
                            buttonContext,
                            category,
                          );
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
                      );
                    },
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

  /// 로딩 카드
  Widget _buildLoadingCard(BuildContext context) {
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
