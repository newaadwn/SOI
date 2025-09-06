import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/category_controller.dart';
import '../../../../models/category_data_model.dart';
import '../../../../theme/theme.dart';
import '../../widgets/archive_card_widget/archive_card_widget.dart';

class SharedArchivesScreen extends StatefulWidget {
  final bool isEditMode;
  final String? editingCategoryId;
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;

  const SharedArchivesScreen({
    super.key,
    this.isEditMode = false,
    this.editingCategoryId,
    this.editingController,
    this.onStartEdit,
  });

  @override
  State<SharedArchivesScreen> createState() => _SharedArchivesScreenState();
}

class _SharedArchivesScreenState extends State<SharedArchivesScreen> {
  String? nickName;
  // 카테고리별 프로필 이미지 캐시
  final Map<String, List<String>> _categoryProfileImages = {};
  Stream<List<CategoryDataModel>>? _categoriesStream;
  CategoryController? _categoryController;

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    final authController = Provider.of<AuthController>(context, listen: false);
    _categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    authController.getIdFromFirestore().then((value) {
      if (mounted) {
        setState(() {
          nickName = value;
          // 닉네임을 얻었을 때 stream 생성
          _categoriesStream = _categoryController!.streamUserCategories(value);
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
    // 만약 닉네임을 아직 못 가져왔다면 로딩 중이에요.
    if (nickName == null || _categoriesStream == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
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
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          // 필터링된 카테고리 가져오기 (initialData가 있으면 바로 사용)
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

          // 데이터 없으면
          if (allCategories.isEmpty) {
            // 여전히 로딩 중이라면 로딩 표시
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
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
          for (var category in sharedCategories) {
            final categoryId = category.id;
            final mates = category.mates;
            _loadProfileImages(categoryId, mates);
          }

          // 데이터가 있으면 스크롤 가능한 화면으로 만들기
          return SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(left: 22.w, right: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(), // 이것은 유지
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
                  // 하단 여백을 더 크게 늘리기
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
