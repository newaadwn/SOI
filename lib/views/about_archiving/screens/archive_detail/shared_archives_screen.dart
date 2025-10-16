import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/category_controller.dart';
import '../../../../controllers/category_search_controller.dart';
import '../../../../theme/theme.dart';
import '../../models/archive_layout_mode.dart';
import '../../widgets/archive_card_widget/archive_card_widget.dart';

class SharedArchivesScreen extends StatefulWidget {
  final bool isEditMode;
  final String? editingCategoryId;
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;
  final ArchiveLayoutMode layoutMode;

  const SharedArchivesScreen({
    super.key,
    this.isEditMode = false,
    this.editingCategoryId,
    this.editingController,
    this.onStartEdit,
    this.layoutMode = ArchiveLayoutMode.grid,
  });

  @override
  State<SharedArchivesScreen> createState() => _SharedArchivesScreenState();
}

class _SharedArchivesScreenState extends State<SharedArchivesScreen>
    with AutomaticKeepAliveClientMixin {
  String? nickName;
  // 카테고리별 프로필 이미지 캐시
  final Map<String, List<String>> _categoryProfileImages = {};
  bool _isInitialLoad = true;
  int _previousCategoryCount = 0; // 이전 카테고리 개수 저장

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    final authController = Provider.of<AuthController>(context, listen: false);
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    authController.getIdFromFirestore().then((value) {
      if (mounted) {
        setState(() {
          nickName = value;
        });
        // 닉네임을 얻었을 때 카테고리 로드
        categoryController.loadUserCategories(value);
      }
    });
  }

  // 카테고리에 대한 프로필 이미지를 가져오는 함수
  Future<void> _loadProfileImages(String categoryId, List<String> mates) async {
    // Skip if already loaded
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
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: Consumer2<CategorySearchController, CategoryController>(
        builder: (context, searchController, categoryController, child) {
          // ✅ Stream 사용으로 실시간 업데이트
          return StreamBuilder<List<dynamic>>(
            stream: categoryController.streamUserCategories(nickName!),
            builder: (context, snapshot) {
              // 로딩 중일 때 - Shimmer 표시 (이전 개수만큼)
              if (snapshot.connectionState == ConnectionState.waiting ||
                  !snapshot.hasData) {
                return _buildShimmerGrid(_previousCategoryCount);
              }

              // 에러가 있을 때
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.h),
                    child: Text(
                      '오류가 발생했습니다.',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final allCategories = snapshot.data ?? [];

              // 공유 카테고리만 필터링합니다.
              final sharedCategories =
                  allCategories
                      .where(
                        (category) =>
                            category.mates.contains(nickName) &&
                            category.mates.length != 1,
                      )
                      .toList();

              // ✅ 카테고리 개수 저장 (다음 로딩 시 사용)
              if (sharedCategories.isNotEmpty &&
                  _previousCategoryCount != sharedCategories.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _previousCategoryCount = sharedCategories.length;
                    });
                  }
                });
              }

              // 데이터 없으면
              if (sharedCategories.isEmpty) {
                // 초기 로딩 완료 표시
                if (_isInitialLoad) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _isInitialLoad = false;
                        _previousCategoryCount = 0; // 빈 상태도 저장
                      });
                    }
                  });
                }

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
                      '공유된 카테고리가 없습니다.',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              // 모든 카테고리에 대해 프로필 이미지 로드 요청
              for (var category in sharedCategories) {
                final categoryId = category.id;
                final mates = category.mates;
                _loadProfileImages(categoryId, mates);
              }

              // 초기 로딩 완료 표시
              if (_isInitialLoad) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _isInitialLoad = false;
                    });
                  }
                });
              }

              // ✅ FadeIn 애니메이션으로 부드럽게 표시
              return AnimatedOpacity(
                opacity: _isInitialLoad ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
                child:
                    widget.layoutMode == ArchiveLayoutMode.grid
                        ? _buildGridView(searchController, sharedCategories)
                        : _buildListView(searchController, sharedCategories),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildShimmerGrid(int itemCount) {
    // 최소 2개, 최대 6개의 Shimmer 표시
    final shimmerCount = itemCount == 0 ? 6 : itemCount.clamp(1, 6);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(left: 22.w, right: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: (168.w / 229.h),
                mainAxisSpacing: 15.h,
                crossAxisSpacing: 15.w,
              ),
              itemCount: shimmerCount,
              itemBuilder: (context, index) {
                return Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(
    CategorySearchController searchController,
    List sharedCategories,
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
                'shared_grid_${sharedCategories.length}_${searchController.searchQuery}',
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: (168.w / 229.h),
                mainAxisSpacing: 15.h,
                crossAxisSpacing: 15.w,
              ),
              itemCount: sharedCategories.length,
              itemBuilder: (context, index) {
                final category = sharedCategories[index];
                final categoryId = category.id;

                return ArchiveCardWidget(
                  key: ValueKey('shared_archive_card_$categoryId'),
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
    List sharedCategories,
  ) {
    return ListView.separated(
      key: ValueKey(
        'shared_list_${sharedCategories.length}_${searchController.searchQuery}',
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(left: 22.w, right: 20.w, top: 8.h, bottom: 20.h),
      itemBuilder: (context, index) {
        final category = sharedCategories[index];
        final categoryId = category.id;

        return ArchiveCardWidget(
          key: ValueKey('shared_archive_list_card_$categoryId'),
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
      itemCount: sharedCategories.length,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
