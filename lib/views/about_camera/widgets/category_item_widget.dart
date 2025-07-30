import 'package:flutter/material.dart';
import 'package:iconoir_flutter/iconoir_flutter.dart' hide Text;
import 'package:cached_network_image/cached_network_image.dart';

/// 카테고리 아이템 위젯
/// 각 카테고리를 표현하는 UI 요소입니다.
/// 아이콘이나 이미지 URL을 함께 표시할 수 있습니다.
class CategoryItemWidget extends StatelessWidget {
  final String? imageUrl;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final String? categoryId;
  final String? selectedCategoryId;

  const CategoryItemWidget({
    super.key,
    this.imageUrl,
    this.icon,
    required this.label,
    required this.onTap,
    this.categoryId,
    this.selectedCategoryId,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSelected = _isSelectedCategory();
    final dimensions = _calculateDimensions(screenWidth);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200), // ✅ 선택 시 부드러운 애니메이션
        width: dimensions.itemWidth,
        margin: EdgeInsets.symmetric(horizontal: dimensions.margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCircularContainer(dimensions, isSelected),
            SizedBox(height: dimensions.spacing),
            _buildCategoryLabel(dimensions),
          ],
        ),
      ),
    );
  }

  /// 선택된 카테고리인지 확인
  bool _isSelectedCategory() {
    return categoryId != null && categoryId == selectedCategoryId;
  }

  /// 화면 크기에 따른 반응형 치수 계산
  _CategoryDimensions _calculateDimensions(double screenWidth) {
    return _CategoryDimensions(
      itemWidth: (screenWidth * 0.204).clamp(70.0, 90.0),
      containerSize: (screenWidth * 0.153).clamp(55.0, 70.0),
      margin: (screenWidth * 0.020).clamp(6.0, 10.0),
      spacing: (screenWidth * 0.020).clamp(6.0, 10.0),
      borderWidth: (screenWidth * 0.005).clamp(2.0, 3.0),
      iconSize: (screenWidth * 0.102).clamp(35.0, 45.0),
      smallIconSize: (screenWidth * 0.076).clamp(26.0, 34.0),
      strokeWidth: (screenWidth * 0.005).clamp(1.5, 2.5),
      fontSize: (screenWidth * 0.031).clamp(10.0, 14.0),
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
        color: (icon != null) ? Colors.grey.shade200 : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white),
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
    // 기본 아이콘이 있는 경우
    if (icon != null) {
      return Icon(icon!, size: dimensions.iconSize, color: Colors.black);
    }

    // 이미지 URL이 있는 경우
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildLoadingIndicator(dimensions),
        errorWidget: (context, url, error) => _buildErrorIcon(dimensions),
      );
    }

    // 기본 이미지 아이콘
    return Icon(
      Icons.image,
      size: dimensions.smallIconSize,
      color: Colors.grey.shade400,
    );
  }

  /// 선택된 상태의 오버레이 빌드 (피그마 디자인 반영)
  Widget _buildSelectionOverlay(_CategoryDimensions dimensions) {
    return Container(
      width: dimensions.containerSize,
      height: dimensions.containerSize,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78), // 피그마와 동일한 투명도
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: dimensions.containerSize * 0.71, // 44.89/63.14 ≈ 0.71
          height: dimensions.containerSize * 0.71,
          child: Center(
            child: SendDiagonalSolid(
              width: dimensions.containerSize * 0.565, // 35.69/63.14 ≈ 0.565
              height: dimensions.containerSize * 0.56, // 35.38/63.14 ≈ 0.56
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  /// 로딩 인디케이터 빌드
  Widget _buildLoadingIndicator(_CategoryDimensions dimensions) {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: dimensions.strokeWidth,
        color: Colors.white,
      ),
    );
  }

  /// 에러 아이콘 빌드
  Widget _buildErrorIcon(_CategoryDimensions dimensions) {
    return Icon(
      Icons.image,
      size: dimensions.smallIconSize,
      color: Colors.grey.shade400,
    );
  }

  /// 카테고리 라벨 빌드
  Widget _buildCategoryLabel(_CategoryDimensions dimensions) {
    return Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: dimensions.fontSize,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
    );
  }
}

/// 카테고리 아이템의 반응형 치수를 관리하는 클래스
class _CategoryDimensions {
  final double itemWidth;
  final double containerSize;
  final double margin;
  final double spacing;
  final double borderWidth;
  final double iconSize;
  final double smallIconSize;
  final double strokeWidth;
  final double fontSize;

  const _CategoryDimensions({
    required this.itemWidth,
    required this.containerSize,
    required this.margin,
    required this.spacing,
    required this.borderWidth,
    required this.iconSize,
    required this.smallIconSize,
    required this.strokeWidth,
    required this.fontSize,
  });
}
