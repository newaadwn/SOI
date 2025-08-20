import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../controllers/category_controller.dart';
import 'category_item_widget.dart';

/// 카테고리 목록을 표시하는 위젯
///
/// 사용자의 카테고리들을 그리드 형태로 표시하고,
/// 새 카테고리 추가 버튼도 함께 제공합니다.
class CategoryListWidget extends StatelessWidget {
  final ScrollController scrollController;
  final String? selectedCategoryId;
  final Function(String categoryId) onCategorySelected;
  final VoidCallback addCategoryPressed;
  final bool isLoading;

  const CategoryListWidget({
    super.key,
    required this.scrollController,
    this.selectedCategoryId,
    required this.onCategorySelected,
    required this.addCategoryPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<CategoryController>(
      builder: (context, viewModel, child) {
        final categories = viewModel.userCategoryList;

        return GridView.builder(
          key: const ValueKey('category_list'),
          controller: scrollController,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.85, // 높이를 조금 더 줘서 텍스트 공간 확보
            crossAxisSpacing: 8.w, // 아이템 간 좌우 간격 추가
            mainAxisSpacing: 15.h, // 세로 간격만 유지
          ),
          padding: EdgeInsets.symmetric(horizontal: 18.w),

          itemCount: categories.isEmpty ? 1 : categories.length + 1,
          itemBuilder: (context, index) {
            // 첫 번째 아이템은 항상 '추가하기' 버튼
            if (index == 0) {
              return CategoryItemWidget(
                image: "assets/plus_icon.png",
                label: '추가하기',
                onTap: addCategoryPressed,
              );
            }
            // 카테고리 아이템 표시
            else {
              final category = categories[index - 1];
              final categoryId = category.id;

              return CategoryItemWidget(
                imageUrl: category.categoryPhotoUrl,
                label: category.name,
                categoryId: categoryId,
                selectedCategoryId: selectedCategoryId,
                onTap: () => onCategorySelected(categoryId),
              );
            }
          },
        );
      },
    );
  }
}
