import 'package:flutter/material.dart';
import 'package:flutter_swift_camera/models/category_data_model.dart';
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
  final VoidCallback onAddCategoryPressed;
  final bool isLoading;

  const CategoryListWidget({
    super.key,
    required this.scrollController,
    this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onAddCategoryPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<CategoryController>(
      builder: (context, viewModel, child) {
        final categories = viewModel.userCategories;

        return GridView.builder(
          key: const ValueKey('category_list'),
          controller: scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          padding: const EdgeInsets.all(16),
          itemCount: categories.isEmpty ? 1 : categories.length + 1,
          itemBuilder: (context, index) {
            // 첫 번째 아이템은 항상 '추가하기' 버튼
            if (index == 0) {
              return CategoryItemWidget(
                icon: Icons.add,
                label: '추가하기',
                onTap: onAddCategoryPressed,
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
              final categoryId = category['id'];

              return StreamBuilder<String?>(
                stream: viewModel.getFirstPhotoUrlStream(categoryId),
                builder: (context, asyncSnapshot) {
                  return CategoryItemWidget(
                    imageUrl: asyncSnapshot.data,
                    label: category['name'],
                    categoryId: categoryId,
                    selectedCategoryId: selectedCategoryId,
                    onTap: () => onCategorySelected(categoryId),
                  );
                },
              );
            }
          },
        );
      },
    );
  }
}

extension on CategoryDataModel {
  operator [](String other) {}
}
