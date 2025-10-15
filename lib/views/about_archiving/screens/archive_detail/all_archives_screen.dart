import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/controllers/category_search_controller.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/category_controller.dart';
import '../../../../theme/theme.dart';
import '../../models/archive_layout_mode.dart';
import '../../widgets/archive_card_widget/archive_card_widget.dart';

// 전체 아카이브 화면
// 모든 사용자의 아카이브 목록을 표시
// 아카이브를 클릭하면 아카이브 상세 화면으로 이동
class AllArchivesScreen extends StatefulWidget {
  final bool isEditMode;
  final String? editingCategoryId;
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;
  final ArchiveLayoutMode layoutMode;

  const AllArchivesScreen({
    super.key,
    this.isEditMode = false,
    this.editingCategoryId,
    this.editingController,
    this.onStartEdit,
    this.layoutMode = ArchiveLayoutMode.grid,
  });

  @override
  State<AllArchivesScreen> createState() => _AllArchivesScreenState();
}

class _AllArchivesScreenState extends State<AllArchivesScreen>
    with AutomaticKeepAliveClientMixin {
  String? nickName;
  final Map<String, List<String>> _categoryProfileImages = {};
  AuthController? _authController; // AuthController 참조 저장

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController = Provider.of<AuthController>(context, listen: false);
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      _authController!.getIdFromFirestore().then((value) {
        if (mounted) {
          setState(() {
            nickName = value;
          });
          // 닉네임을 얻었을 때 카테고리 로드
          categoryController.loadUserCategories(value);
        }
      });

      // AuthController의 변경사항을 감지하여 프로필 이미지 캐시 업데이트
      _authController!.addListener(_onAuthControllerChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AuthController 참조를 안전하게 저장
    _authController ??= Provider.of<AuthController>(context, listen: false);
  }

  @override
  void dispose() {
    // 저장된 참조를 사용하여 리스너 제거
    _authController?.removeListener(_onAuthControllerChanged);
    super.dispose();
  }

  /// AuthController 변경 감지 시 프로필 이미지 캐시 무효화
  void _onAuthControllerChanged() {
    if (mounted) {
      setState(() {
        _categoryProfileImages.clear(); // 모든 프로필 이미지 캐시 무효화
      });
    }
  }

  // 카테고리에 대한 프로필 이미지를 가져오는 함수
  Future<void> _loadProfileImages(String categoryId, List<String> mates) async {
    // 이미 로드된 경우에도 AuthController 변경에 의해 캐시가 무효화되면 다시 로드
    if (_categoryProfileImages.containsKey(categoryId)) {
      return;
    }

    final authController = Provider.of<AuthController>(context, listen: false);
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    try {
      final profileImages = await categoryController.getCategoryProfileImages(
        mates,
        authController,
      );
      if (mounted) {
        setState(() {
          _categoryProfileImages[categoryId] = profileImages;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categoryProfileImages[categoryId] = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 만약 닉네임을 아직 못 가져왔다면 로딩 중이에요.
    if (nickName == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3.0,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: Consumer2<CategorySearchController, CategoryController>(
        builder: (context, searchController, categoryController, child) {
          // 카테고리 목록 가져오기 (검색 결과 포함)
          final categories = categoryController.userCategories;

          // 로딩 중일 때
          if (categoryController.isLoading && categories.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3.0,
              ),
            );
          }

          // 에러가 있을 때
          if (categoryController.error != null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Text(
                  categoryController.error!,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // 데이터 없으면
          if (categories.isEmpty) {
            // 검색 중인데 결과가 없는 경우
            if (searchController.searchQuery.isNotEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.h),
                  child: Text(
                    '검색 결과가 없습니다.',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Text(
                  '등록된 카테고리가 없습니다.',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // 모든 카테고리에 대해 프로필 이미지 로드 요청
          for (var category in categories) {
            final categoryId = category.id;
            final mates = category.mates;
            _loadProfileImages(categoryId, mates);
          }

          // 데이터가 있으면 화면을 스크롤할 수 있도록 만듭니다.
          return widget.layoutMode == ArchiveLayoutMode.grid
              ? _buildGridView(searchController, categories)
              : _buildListView(searchController, categories);
        },
      ),
    );
  }

  Widget _buildGridView(
    CategorySearchController searchController,
    List categories,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(left: 22.w, right: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              key: ValueKey(
                'grid_${categories.length}_${searchController.searchQuery}',
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: (168.w / 229.h),
                mainAxisSpacing: 15.h,
                crossAxisSpacing: 15.w,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final categoryId = category.id;

                return ArchiveCardWidget(
                  key: ValueKey('archive_card_$categoryId'),
                  categoryId: categoryId,
                  layoutMode: ArchiveLayoutMode.grid,
                  isEditMode: widget.isEditMode,
                  isEditing:
                      widget.isEditMode &&
                      widget.editingCategoryId == categoryId,
                  editingController:
                      widget.isEditMode &&
                              widget.editingCategoryId == categoryId
                          ? widget.editingController
                          : null,
                  onStartEdit: () {
                    if (widget.onStartEdit != null) {
                      widget.onStartEdit!(categoryId, category.name);
                    }
                  },
                );
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(
    CategorySearchController searchController,
    List categories,
  ) {
    return ListView.separated(
      key: ValueKey(
        'list_${categories.length}_${searchController.searchQuery}',
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(left: 22.w, right: 20.w, top: 8.h, bottom: 20.h),
      itemBuilder: (context, index) {
        final category = categories[index];
        final categoryId = category.id;

        return ArchiveCardWidget(
          key: ValueKey('archive_list_card_$categoryId'),
          categoryId: categoryId,
          layoutMode: ArchiveLayoutMode.list,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode && widget.editingCategoryId == categoryId,
          editingController:
              widget.isEditMode && widget.editingCategoryId == categoryId
                  ? widget.editingController
                  : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              widget.onStartEdit!(categoryId, category.name);
            }
          },
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemCount: categories.length,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
