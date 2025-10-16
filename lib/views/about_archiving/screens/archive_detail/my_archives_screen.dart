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

// 나의 아카이브 화면
// 현재 사용자의 아카이브 목록을 표시
// 아카이브를 클릭하면 아카이브 상세 화면으로 이동
class MyArchivesScreen extends StatefulWidget {
  final bool isEditMode;
  final String? editingCategoryId;
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;
  final ArchiveLayoutMode layoutMode;

  const MyArchivesScreen({
    super.key,
    this.isEditMode = false,
    this.editingCategoryId,
    this.editingController,
    this.onStartEdit,
    this.layoutMode = ArchiveLayoutMode.grid,
  });

  @override
  State<MyArchivesScreen> createState() => _MyArchivesScreenState();
}

class _MyArchivesScreenState extends State<MyArchivesScreen>
    with AutomaticKeepAliveClientMixin {
  String? uID;
  // 카테고리별 프로필 이미지 캐시
  final Map<String, List<String>> _categoryProfileImages = {};
  bool _isInitialLoad = true;
  int _previousCategoryCount = 0; // 이전 카테고리 개수 저장

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    final authController = Provider.of<AuthController>(context, listen: false);
    authController.getIdFromFirestore().then((value) {
      if (mounted) {
        setState(() {
          uID = value;
        });
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
    if (uID == null) {
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
            stream: categoryController.streamUserCategories(uID!),
            builder: (context, snapshot) {
              // 로딩 중일 때 - Shimmer 표시 (이전 개수만큼)
              if (snapshot.connectionState == ConnectionState.waiting ||
                  !snapshot.hasData) {
                return _buildShimmerGrid(_previousCategoryCount);
              }

              // 에러가 생겼을 때
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

              // 필터링된 카테고리 가져오기
              final allCategories = snapshot.data ?? [];

              // 사용자 카테고리만 필터링합니다.
              final userCategories =
                  allCategories
                      .where(
                        (category) =>
                            category.mates.every((element) => element == uID),
                      )
                      .toList();

              // ✅ 카테고리 개수 저장 (다음 로딩 시 사용)
              if (userCategories.isNotEmpty &&
                  _previousCategoryCount != userCategories.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _previousCategoryCount = userCategories.length;
                    });
                  }
                });
              }

              // 데이터 없으면
              if (userCategories.isEmpty) {
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

                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.h),
                    child: Text(
                      searchController.searchQuery.isNotEmpty
                          ? '검색 결과가 없습니다.'
                          : '등록된 카테고리가 없습니다.',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              // 모든 카테고리에 대해 프로필 이미지 로드 요청
              for (var category in userCategories) {
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
                        ? _buildGridView(searchController, userCategories)
                        : _buildListView(searchController, userCategories),
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
    List userCategories,
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
                'my_grid_${userCategories.length}_${searchController.searchQuery}',
              ),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: (168.w / 229.h),
                mainAxisSpacing: 15.h,
                crossAxisSpacing: 15.w,
              ),
              itemCount: userCategories.length,
              itemBuilder: (context, index) {
                final category = userCategories[index];
                final categoryId = category.id;

                return ArchiveCardWidget(
                  key: ValueKey('my_archive_card_$categoryId'),
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
    List userCategories,
  ) {
    return ListView.separated(
      key: ValueKey(
        'my_list_${userCategories.length}_${searchController.searchQuery}',
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(left: 22.w, right: 20.w, top: 8.h, bottom: 20.h),
      itemBuilder: (context, index) {
        final category = userCategories[index];
        final categoryId = category.id;

        return ArchiveCardWidget(
          key: ValueKey('my_archive_list_card_$categoryId'),
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
      itemCount: userCategories.length,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
