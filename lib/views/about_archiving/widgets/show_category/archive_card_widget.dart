import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../controllers/category_controller.dart';

import '../../../../models/category_data_model.dart';
import '../../category_photos_screen.dart';
import 'archive_profile_row_widget.dart';
import 'archive_popup_menu_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 🎨 아카이브 카드 공통 위젯 (반응형 디자인 + 실시간 업데이트)
/// 168x229 비율의 카드 UI를 제공하며, 화면 크기에 따라 적응합니다.
class ArchiveCardWidget extends StatelessWidget {
  final String categoryId;

  const ArchiveCardWidget({super.key, required this.categoryId});

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
    //final isSmallScreen = ArchiveResponsiveHelper.isSmallScreen(context);
    //final isLargeScreen = ArchiveResponsiveHelper.isLargeScreen(context);
    // GridView 가 childAspectRatio 로 셀 비율을 결정하므로 내부 고정 width/height 제거
    // (168x229) 비율을 명시적으로 유지하기 위해 AspectRatio 사용
    return Card(
      color: const Color(0xFF1C1C1C), // Figma 배경색
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.61)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CategoryPhotosScreen(category: category),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🖼️ 메인 이미지 (실시간 업데이트)
            Stack(
              children: [
                // 메인 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.61),
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
                            width: (146.7).w,
                            height: (146.8).h,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
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
                                    size: 24.sp,
                                  ),
                                ),
                          )
                          : Container(
                            color: Colors.grey[300],
                            width: (146.7).w,
                            height: (146.8).h,
                            child: Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 40.sp,
                            ),
                          ),
                ),

                // 📌 고정 아이콘 (고정된 경우에만 표시)
                if (category.isPinned)
                  Positioned(
                    top: (8.0).h,
                    left: (8.0).w,
                    child: Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Icon(
                        Icons.push_pin,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                    ),
                  ),
              ],
            ),

            // 📝 카테고리 이름과 더보기 버튼 행
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 카테고리 이름 (반응형 폰트 크기)
                Padding(
                  padding: EdgeInsets.only(left: 14.w),
                  child: Text(
                    category.name,
                    style: TextStyle(
                      color: const Color(0xFFF9F9F9), // Figma 텍스트 색상
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
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
                        width: 30.w,
                        height: 30.h,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            SizedBox(height: 8.h),

            // 👥 프로필 이미지들 (카테고리의 mates를 직접 사용)
            Padding(
              padding: EdgeInsets.only(left: 14.w),
              child: ArchiveProfileRowWidget(mates: category.mates),
            ),
          ],
        ),
      ),
    );
  }

  /// 로딩 카드
  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6.61),
        ),
      ),
      child: Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
      ),
    );
  }
}
