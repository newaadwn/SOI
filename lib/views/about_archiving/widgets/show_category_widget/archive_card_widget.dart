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

// 아카이브 카드 위젯
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
  CategoryDataModel? _cachedCategory; // 캐시된 카테고리 데이터
  bool _hasLoadedOnce = false; // 한 번이라도 로드되었는지 추적

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryController>(
      builder: (context, categoryController, child) {
        return StreamBuilder<CategoryDataModel?>(
          stream: categoryController.streamSingleCategory(widget.categoryId),
          builder: (context, snapshot) {
            // 데이터가 있으면 캐시 업데이트
            if (snapshot.hasData && snapshot.data != null) {
              _cachedCategory = snapshot.data!;
              _hasLoadedOnce = true;
            }

            // 스트림이 처음 연결 중이고 아직 한 번도 로드되지 않은 경우에만 Shimmer 표시
            if (!_hasLoadedOnce &&
                (snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.connectionState == ConnectionState.none ||
                    !snapshot.hasData ||
                    snapshot.data == null)) {
              return _buildLoadingCard(context);
            }

            // 에러가 있거나 카테고리가 삭제된 경우
            if (snapshot.hasError) {
              return const SizedBox.shrink();
            }

            // 캐시된 데이터가 있으면 사용, 없으면 현재 스냅샷 데이터 사용
            final category = _cachedCategory ?? snapshot.data;

            // 여전히 데이터가 없으면 로딩 카드 표시
            if (category == null || category.name.isEmpty) {
              return _buildLoadingCard(context);
            }

            // AnimatedSwitcher로 부드러운 전환 효과 적용
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
      color: const Color(0xFF1C1C1C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.61)),
      child: InkWell(
        onTap:
            widget.isEditMode
                ? null
                : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => CategoryPhotosScreen(category: category),
                    ),
                  );
                },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 메인 이미지 (실시간 업데이트)
            Stack(
              alignment: Alignment.topLeft,
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
                                  baseColor: Colors.grey.shade800,
                                  highlightColor: Colors.grey.shade700,
                                  period: const Duration(milliseconds: 1500),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6.61),
                                    child: Container(
                                      width: 146.7.w,
                                      height: 146.8.h,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade800,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.12,
                                          ),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          6.61,
                                        ),
                                      ),
                                    ),
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

                // 고정 아이콘 (현재 사용자에게 고정된 경우에만 표시)
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
                      left: (7.35).w,
                      child: Container(
                        padding: const EdgeInsets.all(4.0),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Image.asset(
                          'assets/pin_icon.png',
                          width: 9.w,
                          height: 9.h,
                        ),
                      ),
                    );
                  },
                ),
                // New 아이콘 (다른 사용자가 최근에 사진을 올린 경우에만 표시)
                Builder(
                  builder: (context) {
                    final authController = AuthController();
                    final userId = authController.getUserId;

                    // 현재 사용자에게 새로운 사진이 있는지 확인
                    final hasNewPhoto =
                        userId != null
                            ? category.hasNewPhotoForUser(userId)
                            : false;

                    if (!hasNewPhoto) return SizedBox.shrink();

                    return Positioned(
                      top: (8.0).h,
                      left: (129).w,
                      child: Image.asset(
                        'assets/new_icon.png',
                        width: 13.87.w,
                        height: 13.87.h,
                      ),
                    );
                  },
                ),
              ],
            ),

            // 카테고리 이름과 더보기 버튼 행
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
                  IgnorePointer(
                    ignoring: widget.isEditMode,
                    child: ArchivePopupMenuWidget(
                      category: category,
                      onEditName: widget.onStartEdit,
                      child: Container(
                        width: 30.w,
                        height: 30.h,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.more_vert,
                          color: widget.isEditMode ? Colors.grey : Colors.white,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 8.h),

            // 프로필 이미지들 (카테고리의 mates를 직접 사용)
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
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      period: const Duration(milliseconds: 1500),
      child: Container(
        decoration: ShapeDecoration(
          color: Colors.grey.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6.61),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 이미지 영역 Shimmer (상단 큰 블럭)
            ClipRRect(
              borderRadius: BorderRadius.circular(6.61),
              child: Container(
                width: 146.7.w,
                height: 146.8.h,
                color: Colors.grey.shade800,
              ),
            ),
            SizedBox(height: 10.h),
            // 텍스트 라인
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 14.w),
                child: Container(
                  width: 90.w,
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            // 프로필 동그라미 3개
            Padding(
              padding: EdgeInsets.only(left: 14.w),
              child: Row(
                children: List.generate(
                  3,
                  (index) => Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: Container(
                      width: 20.w,
                      height: 20.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
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
