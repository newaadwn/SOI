import 'package:flutter/material.dart';
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
    final screenWidth = MediaQuery.sizeOf(context).width;

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
            childAspectRatio: 0.8,
            crossAxisSpacing: (screenWidth * 0.025).clamp(8.0, 12.0), // 반응형 간격
            mainAxisSpacing: (screenWidth * 0.025).clamp(8.0, 12.0), // 반응형 간격
          ),
          padding: EdgeInsets.all(
            (screenWidth * 0.041).clamp(14.0, 20.0),
          ), // 반응형 패딩
          itemCount: categories.isEmpty ? 1 : categories.length + 1,
          itemBuilder: (context, index) {
            // 첫 번째 아이템은 항상 '추가하기' 버튼
            if (index == 0) {
              return CategoryItemWidget(
                icon: Icons.add,
                label: '추가하기',
                onTap: addCategoryPressed,
              );
            }
            // 카테고리가 없는 경우 안내 메시지 표시
            else if (categories.isEmpty) {
              return Center(
                child: Text(
                  '카테고리가 없습니다.\n추가해 보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
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
