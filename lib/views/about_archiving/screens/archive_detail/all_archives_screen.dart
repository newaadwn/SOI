import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/category_controller.dart';
import '../../../../models/category_data_model.dart';
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
  Stream<List<CategoryDataModel>>? _categoriesStream;
  CategoryController? _categoryController;

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController = Provider.of<AuthController>(context, listen: false);
      _categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      _authController!.getIdFromFirestore().then((value) {
        if (mounted) {
          setState(() {
            nickName = value;
            // 닉네임을 얻었을 때 stream 생성
            _categoriesStream = _categoryController!.streamUserCategories(
              value,
            );
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
    PaintingBinding.instance.imageCache.clear();
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
    if (nickName == null || _categoriesStream == null) {
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
      body: StreamBuilder<List<CategoryDataModel>>(
        stream: _categoriesStream!,
        initialData: _categoryController?.userCategories ?? [],
        builder: (context, snapshot) {
          // 에러가 생겼을 때만 에러 표시
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Text(
                  '카테고리를 불러오는 중 오류가 발생했습니다.',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // 카테고리 목록 가져오기 (initialData가 있으면 바로 사용)
          final categories = snapshot.data ?? [];

          // 데이터 없으면
          if (categories.isEmpty) {
            // 여전히 로딩 중이라면 로딩 표시
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3.0,
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
