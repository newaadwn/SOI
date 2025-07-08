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
    // 선택된 카테고리인지 확인 (전송 모드)
    final bool isSelected =
        categoryId != null && categoryId == selectedCategoryId;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 이미지 또는 아이콘 원형 컨테이너
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: icon != null ? Colors.grey.shade200 : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipOval(
                child:
                    isSelected
                        ? Icon(Icons.send, size: 30, color: Colors.blue)
                        : icon != null
                        ? Icon(icon, size: 40, color: Colors.black)
                        : (imageUrl != null && imageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Icon(
                                Icons.image,
                                size: 30,
                                color: Colors.grey.shade400,
                              ),
                        )
                        : Icon(
                          Icons.image,
                          size: 30,
                          color: Colors.grey.shade400,
                        ),
              ),
            ),
            const SizedBox(height: 8),
            // 카테고리 이름
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
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
