import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/category_controller.dart';

import '../../../../models/category_data_model.dart';
import '../../category_photos_screen.dart';
import 'archive_profile_row_widget.dart';
import 'archive_popup_menu_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 🎨 아카이브 카드 공통 위젯 (반응형 디자인 + 실시간 업데이트)
/// 168x229 비율의 카드 UI를 제공하며, 화면 크기에 따라 적응합니다.
class ArchiveCardWidget extends StatefulWidget {
  final String categoryId;
  final bool isEditMode;
  final bool isEditing;
  final TextEditingController? editingController;
  final VoidCallback? onStartEdit;

  const ArchiveCardWidget({
    super.key,
    required this.categoryId,
    this.isEditMode = false,
    this.isEditing = false,
    this.editingController,
    this.onStartEdit,
  });

  @override
  State<ArchiveCardWidget> createState() => _ArchiveCardWidgetState();
}

class _ArchiveCardWidgetState extends State<ArchiveCardWidget> {
  CategoryDataModel? _cachedCategory; // 🎯 캐시된 카테고리 데이터
  bool _hasLoadedOnce = false; // 🎯 한 번이라도 로드되었는지 추적

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryController>(
      builder: (context, categoryController, child) {
        return StreamBuilder<CategoryDataModel?>(
          stream: categoryController.streamSingleCategory(widget.categoryId),
          builder: (context, snapshot) {
            // 🎯 데이터가 있으면 캐시 업데이트
            if (snapshot.hasData && snapshot.data != null) {
              _cachedCategory = snapshot.data!;
              _hasLoadedOnce = true;
            }

            // 🎯 스트림이 처음 연결 중이고 아직 한 번도 로드되지 않은 경우에만 Shimmer 표시
            if (!_hasLoadedOnce &&
                (snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.connectionState == ConnectionState.none ||
                    !snapshot.hasData ||
                    snapshot.data == null)) {
              return _buildLoadingCard(context);
            }

            // 🎯 에러가 있거나 카테고리가 삭제된 경우
            if (snapshot.hasError) {
              return const SizedBox.shrink();
            }

            // 🎯 캐시된 데이터가 있으면 사용, 없으면 현재 스냅샷 데이터 사용
            final category = _cachedCategory ?? snapshot.data;

            // 🎯 여전히 데이터가 없으면 로딩 카드 표시
            if (category == null || category.name.isEmpty) {
              return _buildLoadingCard(context);
            }

            // 🎯 AnimatedSwitcher로 부드러운 전환 효과 적용
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCategoryCard(context, category),
            );
          },
        );
      },
    );
  }

  /// 실제 카테고리 카드 빌드
  Widget _buildCategoryCard(BuildContext context, CategoryDataModel category) {
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
                            ),
                            imageUrl: category.categoryPhotoUrl!,
                            cacheKey:
                                '${category.id}_${category.categoryPhotoUrl}',
                            width: (146.7),
                            height: (146.8),
                            fit: BoxFit.cover,
                            fadeInDuration: Duration(milliseconds: 200),
                            fadeOutDuration: Duration(milliseconds: 100),
                            placeholder:
                                (context, url) => Shimmer.fromColors(
                                  baseColor: Color(0xFF2A2A2A),
                                  highlightColor: Color(0xFFffffff),
                                  child: SizedBox(
                                    width: 146.7.w,
                                    height: 146.8.h,
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Container(
                                  color: Color(
                                    0xFFcacaca,
                                  ).withValues(alpha: 0.9),
                                  width: (146.7),
                                  height: (146.8),
                                  child: Icon(
                                    Icons.image,
                                    color: Color(0xff5a5a5a),
                                    size: 51.sp,
                                  ),
                                ),
                          )
                          : Container(
                            color: Color(0xFFcacaca).withValues(alpha: 0.9),
                            width: (146.7),
                            height: (146.8),
                            child: Icon(
                              Icons.image,
                              color: Color(0xff5a5a5a),
                              size: 51.sp,
                            ),
                          ),
                ),

                // 📌 고정 아이콘 (현재 사용자에게 고정된 경우에만 표시)
                Builder(
                  builder: (context) {
                    final authController = AuthController();
                    final userId = authController.getUserId;

                    // 현재 사용자의 고정 상태 확인
                    final isPinnedForCurrentUser =
                        userId != null
                            ? category.isPinnedForUser(userId)
                            : false;

                    if (!isPinnedForCurrentUser) return SizedBox.shrink();

                    return Positioned(
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
                    );
                  },
                ),
              ],
            ),

            // 📝 카테고리 이름과 더보기 버튼 행
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 카테고리 이름 (편집 모드에 따라 TextField 또는 Text)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 14.w, right: 8.w),
                    child:
                        widget.isEditing
                            ? TextField(
                              controller: widget.editingController,
                              style: TextStyle(
                                color: const Color(0xFFF9F9F9),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.4,
                                fontFamily: 'Pretendard',
                              ),
                              cursorColor: Color(0xfff9f9f9),
                              cursorHeight: 13.h,
                              decoration: InputDecoration(
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              maxLines: 1,
                              autofocus: true,
                            )
                            : Builder(
                              builder: (context) {
                                final authController = AuthController();
                                final userId = authController.getUserId;
                                final categoryController =
                                    Provider.of<CategoryController>(
                                      context,
                                      listen: false,
                                    );

                                final displayName =
                                    userId != null
                                        ? categoryController
                                            .getCategoryDisplayName(
                                              category,
                                              userId,
                                            )
                                        : category.name;

                                return Text(
                                  displayName,
                                  style: TextStyle(
                                    color: const Color(0xFFF9F9F9),
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.4,
                                    fontFamily: 'Pretendard',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                  ),
                ),

                // 더보기 버튼 (편집 모드가 아닐 때만 표시)
                if (!widget.isEditMode)
                  Builder(
                    builder: (buttonContext) {
                      return InkWell(
                        onTap: () {
                          ArchivePopupMenuWidget.showArchivePopupMenu(
                            buttonContext,
                            category,
                            onEditName: widget.onStartEdit,
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

  /// 로딩 카드 (Shimmer 효과 적용)
  Widget _buildLoadingCard(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1C1C1C),
      highlightColor: const Color(0xFF2A2A2A),
      child: Container(
        decoration: ShapeDecoration(
          color: const Color(0xFF1C1C1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6.61),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 이미지 영역 Shimmer
            Container(
              width: 146.7.w,
              height: 146.8.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6.61),
              ),
            ),

            SizedBox(height: 8.h),

            // 텍스트 영역 Shimmer
            Row(
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 14.w),
                  child: Container(
                    width: 80.w,
                    height: 14.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 8.h),

            // 프로필 영역 Shimmer
            Padding(
              padding: EdgeInsets.only(left: 14.w),
              child: Row(
                children: List.generate(
                  3,
                  (index) => Padding(
                    padding: EdgeInsets.only(right: 4.w),
                    child: Container(
                      width: 20.w,
                      height: 20.h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
