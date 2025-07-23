import 'package:flutter/material.dart';
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

    // 선택된 카테고리인지 확인 (전송 모드)
    final bool isSelected =
        categoryId != null && categoryId == selectedCategoryId;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (screenWidth * 0.204).clamp(70.0, 90.0), // 반응형 너비
        margin: EdgeInsets.symmetric(
          horizontal: (screenWidth * 0.020).clamp(6.0, 10.0),
        ), // 반응형 마진
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이미지 또는 아이콘 원형 컨테이너
            Container(
              width: (screenWidth * 0.153).clamp(55.0, 70.0), // 반응형 너비
              height: (screenWidth * 0.153).clamp(55.0, 70.0), // 반응형 높이
              decoration: BoxDecoration(
                color: icon != null ? Colors.grey.shade200 : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  width:
                      isSelected
                          ? (screenWidth * 0.005).clamp(2.0, 3.0)
                          : 1, // 반응형 테두리
                ),
              ),
              child: ClipOval(
                child:
                    isSelected
                        ? Icon(
                          Icons.send,
                          size: (screenWidth * 0.076).clamp(
                            26.0,
                            34.0,
                          ), // 반응형 아이콘 크기
                          color: Colors.blue,
                        )
                        : icon != null
                        ? Icon(
                          icon,
                          size: (screenWidth * 0.102).clamp(
                            35.0,
                            45.0,
                          ), // 반응형 아이콘 크기
                          color: Colors.black,
                        )
                        : (imageUrl != null && imageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: (screenWidth * 0.005).clamp(
                                    1.5,
                                    2.5,
                                  ), // 반응형 선 두께
                                  color: Colors.white,
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Icon(
                                Icons.image,
                                size: (screenWidth * 0.076).clamp(
                                  26.0,
                                  34.0,
                                ), // 반응형 아이콘 크기
                                color: Colors.grey.shade400,
                              ),
                        )
                        : Icon(
                          Icons.image,
                          size: (screenWidth * 0.076).clamp(
                            26.0,
                            34.0,
                          ), // 반응형 아이콘 크기
                          color: Colors.grey.shade400,
                        ),
              ),
            ),
            SizedBox(height: (screenWidth * 0.020).clamp(6.0, 10.0)), // 반응형 간격
            // 카테고리 이름
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: (screenWidth * 0.031).clamp(10.0, 14.0), // 반응형 폰트 크기
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
