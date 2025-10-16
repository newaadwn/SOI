import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 카테고리 아이템 위젯
/// 각 카테고리를 표현하는 UI 요소입니다.
/// 아이콘이나 이미지 URL을 함께 표시할 수 있습니다.
class CategoryItemWidget extends StatefulWidget {
  final String? imageUrl;
  final String? image;
  final String label;
  final VoidCallback onTap;
  final String? categoryId;
  final String? selectedCategoryId;

  const CategoryItemWidget({
    super.key,
    this.imageUrl,
    this.image,
    required this.label,
    required this.onTap,
    this.categoryId,
    this.selectedCategoryId,
  });

  @override
  State<CategoryItemWidget> createState() => _CategoryItemWidgetState();
}

class _CategoryItemWidgetState extends State<CategoryItemWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false; // 메모리 절약을 위해 keepAlive 비활성화

  @override
  void dispose() {
    // 이미지 캐시에서 해당 이미지 제거
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      try {
        PaintingBinding.instance.imageCache.evict(
          NetworkImage(widget.imageUrl!),
        );
      } catch (e) {
        // 캐시 제거 실패해도 계속 진행
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 때문에 필요
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSelected = _isSelectedCategory();
    final dimensions = _calculateDimensions(screenWidth);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200), // ✅ 선택 시 부드러운 애니메이션
        width: dimensions.itemWidth,
        // margin 제거 - GridView의 spacing이 이미 간격을 관리하고 있음
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCircularContainer(dimensions, isSelected),
            SizedBox(height: 12.h),
            _buildCategoryLabel(dimensions),
          ],
        ),
      ),
    );
  }

  /// 선택된 카테고리인지 확인
  bool _isSelectedCategory() {
    return widget.categoryId != null &&
        widget.categoryId == widget.selectedCategoryId;
  }

  /// 화면 크기에 따른 반응형 치수 계산
  _CategoryDimensions _calculateDimensions(double screenWidth) {
    // GridView가 4열이고 패딩과 간격을 고려한 실제 아이템 너비 계산
    final totalPadding = (screenWidth * 0.08).clamp(24.0, 36.0); // 좌우 패딩 총합
    final totalSpacing = 8.0 * 3; // crossAxisSpacing * (열 수 - 1)
    final availableWidth = screenWidth - totalPadding - totalSpacing;
    final itemWidth = availableWidth / 4;

    return _CategoryDimensions(
      itemWidth: itemWidth,
      containerSize: (itemWidth * 0.75).clamp(50.0, 65.0), // 아이템 너비의 75%
      margin: 0, // margin 제거

      borderWidth: (screenWidth * 0.005).clamp(2.0, 3.0),
      iconSize: (itemWidth * 0.4).clamp(25.0, 32.0), // 컨테이너 크기에 비례
      smallIconSize: (itemWidth * 0.3).clamp(20.0, 26.0),
      strokeWidth: (screenWidth * 0.005).clamp(1.5, 2.5),
      fontSize: (screenWidth * 0.032).clamp(11.0, 14.0), // 텍스트 크기 약간 증가
    );
  }

  /// 원형 컨테이너 빌드
  Widget _buildCircularContainer(
    _CategoryDimensions dimensions,
    bool isSelected,
  ) {
    return Container(
      width: dimensions.containerSize,
      height: dimensions.containerSize,
      decoration: BoxDecoration(
        color: (widget.image != null) ? Colors.white : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Stack(
          children: [
            // 배경 이미지/아이콘
            Center(child: _buildContainerChild(dimensions)),

            // 선택된 상태일 때 오버레이와 전송 아이콘
            if (isSelected) _buildSelectionOverlay(dimensions),
          ],
        ),
      ),
    );
  }

  /// 컨테이너 내부 위젯 빌드
  Widget _buildContainerChild(_CategoryDimensions dimensions) {
    // 기본 아이콘이 있는 경우 (추가하기 버튼)
    if (widget.image != null) {
      return Image.asset(
        widget.image!,
        color: Colors.black,
        width: 27.w,
        height: 27.h,
        fit: BoxFit.cover,
      );
    }

    // 이미지 URL이 있는 경우
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return SizedBox(
        width: dimensions.containerSize, // 컨테이너 크기와 일치
        height: dimensions.containerSize, // 컨테이너 크기와 일치
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl!,
          fit: BoxFit.cover,
          width: dimensions.containerSize,
          height: dimensions.containerSize,
          // 메모리 최적화: 카테고리 이미지 크기 엄격 제한 (1.9GB 급증 문제 해결)
          memCacheWidth:
              (dimensions.containerSize * 1.5).round(), // 1.5배로 감소 (기존 2배에서)
          memCacheHeight: (dimensions.containerSize * 1.5).round(),
          maxWidthDiskCache: 150, // 디스크 캐시 더 제한 (기존 200에서)
          maxHeightDiskCache: 150, // 디스크 캐시 더 제한
          filterQuality: FilterQuality.low, // 품질 낮춤으로 메모리 절약
          // 추가 최적화: 이미지 압축 레벨 설정
          cacheManager: null, // 기본 캐시 매니저 사용하여 자동 정리
          placeholder: (context, url) => _buildLoadingIndicator(dimensions),
          errorWidget: (context, url, error) => _buildErrorIcon(dimensions),
        ),
      );
    }

    // 기본 이미지 아이콘
    return Container(
      decoration: BoxDecoration(color: Color(0xff4a4a4a)),
      width: dimensions.containerSize, // 컨테이너 크기와 일치
      height: dimensions.containerSize, // 컨테이너 크기와 일치
      child: Icon(
        Icons.image_outlined,
        size: dimensions.iconSize,
        color: Color(0xffcecece),
      ),
    );
  }

  /// 선택된 상태의 오버레이 빌드 (피그마 디자인 반영)
  Widget _buildSelectionOverlay(_CategoryDimensions dimensions) {
    return Container(
      width: dimensions.containerSize,
      height: dimensions.containerSize,
      decoration: BoxDecoration(
        color: Color(0xff404040).withValues(alpha: 0.7), // 피그마와 동일한 투명도
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: 3.h, left: 3.w),
        child: Center(
          child: SizedBox(
            width: 45.4.w,
            height: 45.4.h,
            child: Center(child: Image.asset('assets/send_imoji.png')),
          ),
        ),
      ),
    );
  }

  /// 로딩 인디케이터 빌드
  Widget _buildLoadingIndicator(_CategoryDimensions dimensions) {
    return Center(
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }

  /// 에러 아이콘 빌드
  Widget _buildErrorIcon(_CategoryDimensions dimensions) {
    return Container(
      decoration: BoxDecoration(color: Color(0xff4a4a4a)),
      width: dimensions.containerSize, // 컨테이너 크기와 일치
      height: dimensions.containerSize, // 컨테이너 크기와 일치
      child: Icon(
        Icons.image_outlined,
        size: dimensions.iconSize,
        color: Color(0xffcecece),
      ),
    );
  }

  /// 카테고리 라벨 빌드
  Widget _buildCategoryLabel(_CategoryDimensions dimensions) {
    return Text(
      widget.label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        fontFamily: 'Pretendard',
        color: Colors.white,
        height: 1.0,
        letterSpacing: -0.4,
      ),
    );
  }
}

/// 카테고리 아이템의 반응형 치수를 관리하는 클래스
class _CategoryDimensions {
  final double itemWidth;
  final double containerSize;
  final double margin;

  final double borderWidth;
  final double iconSize;
  final double smallIconSize;
  final double strokeWidth;
  final double fontSize;

  const _CategoryDimensions({
    required this.itemWidth,
    required this.containerSize,
    required this.margin,

    required this.borderWidth,
    required this.iconSize,
    required this.smallIconSize,
    required this.strokeWidth,
    required this.fontSize,
  });
}
