import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/category_controller.dart';
import '../../../../theme/theme.dart';
import '../../widgets/archive_card_widget/archive_card_widget.dart';

// 전체 아카이브 화면
// 모든 사용자의 아카이브 목록을 표시
// 아카이브를 클릭하면 아카이브 상세 화면으로 이동
class AllArchivesScreen extends StatefulWidget {
  final bool isEditMode;
  final String? editingCategoryId;
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;

  const AllArchivesScreen({
    super.key,
    this.isEditMode = false,
    this.editingCategoryId,
    this.editingController,
    this.onStartEdit,
  });

  @override
  State<AllArchivesScreen> createState() => _AllArchivesScreenState();
}

class _AllArchivesScreenState extends State<AllArchivesScreen> {
  String? nickName;
  final Map<String, List<String>> _categoryProfileImages = {};
  AuthController? _authController; // AuthController 참조 저장

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController = Provider.of<AuthController>(context, listen: false);
      _authController!.getIdFromFirestore().then((value) {
        if (mounted) {
          setState(() {
            nickName = value;
          });
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
      body: Consumer<CategoryController>(
        builder: (context, categoryController, child) {
          // 사용자 카테고리 로드 (한 번만 로드)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            categoryController.loadUserCategories(nickName!);
          });

          // 로딩 중일 때
          if (categoryController.isLoading &&
              categoryController.userCategories.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3.0,
              ),
            );
          }

          // 에러가 생겼을 때
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

          // 필터링된 카테고리 가져오기
          final categories = categoryController.userCategories;

          // 데이터 없으면
          if (categories.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Text(
                  categoryController.searchQuery.isNotEmpty
                      ? '검색 결과가 없습니다.'
                      : '등록된 카테고리가 없습니다.',
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
          return SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
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
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final categoryId = category.id;

                      return ArchiveCardWidget(
                        categoryId: categoryId,
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
                  // 하단 여백 추가 (스크롤 범위 확장)
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
