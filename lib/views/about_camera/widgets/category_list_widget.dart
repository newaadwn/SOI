import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../controllers/category_controller.dart';
import 'category_item_widget.dart';

/// 카테고리 목록을 표시하는 위젯
///
/// 사용자의 카테고리들을 그리드 형태로 표시하고,
/// 새 카테고리 추가 버튼도 함께 제공합니다.
class CategoryListWidget extends StatefulWidget {
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
  State<CategoryListWidget> createState() => _CategoryListWidgetState();
}

class _CategoryListWidgetState extends State<CategoryListWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false; // 메모리 절약을 위해 keepAlive 비활성화

  @override
  void dispose() {
    // GridView의 캐시된 위젯들 정리
    try {
      // 스크롤 컨트롤러가 여전히 활성 상태인지 확인 후 정리
      if (widget.scrollController.hasClients) {
        // 필요시 추가 정리 작업
      }
    } catch (e) {
      // 정리 실패해도 계속 진행
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 때문에 필요
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<CategoryController>(
      builder: (context, viewModel, child) {
        final categories = viewModel.userCategoryList;

        return GridView.builder(
          key: const ValueKey('category_list'),
          controller: widget.scrollController,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.85, // 높이를 조금 더 줘서 텍스트 공간 확보
            crossAxisSpacing: 8.w, // 아이템 간 좌우 간격 추가
            mainAxisSpacing: 15.h, // 세로 간격만 유지
          ),
          padding: EdgeInsets.symmetric(horizontal: 18.w),
          // ⭐ 메모리 최적화 설정 추가
          cacheExtent: 200.0, // 캐시할 픽셀 범위 제한
          addAutomaticKeepAlives: false, // 자동 keepAlive 비활성화
          addRepaintBoundaries: false, // 불필요한 repaint boundary 제거

          itemCount: categories.isEmpty ? 1 : categories.length + 1,
          itemBuilder: (context, index) {
            // 첫 번째 아이템은 항상 '추가하기' 버튼
            if (index == 0) {
              return CategoryItemWidget(
                image: "assets/plus_icon.png",
                label: '추가하기',
                onTap: widget.addCategoryPressed,
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
                selectedCategoryId: widget.selectedCategoryId,
                onTap: () => widget.onCategorySelected(categoryId),
              );
            }
          },
        );
      },
    );
  }
}
