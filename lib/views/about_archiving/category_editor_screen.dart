import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/category_data_model.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/auth_controller.dart';
import 'category_cover_photo_selector_screen.dart';

class CategoryEditorScreen extends StatefulWidget {
  final CategoryDataModel category;

  const CategoryEditorScreen({super.key, required this.category});

  @override
  State<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<CategoryEditorScreen> {
  bool _notificationEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryController>(
      builder: (context, categoryController, child) {
        final currentCategory = categoryController.userCategories.firstWhere(
          (cat) => cat.id == widget.category.id,
          orElse: () => widget.category,
        );

        return Scaffold(
          backgroundColor: const Color(0xFF111111),
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: const Color(0xFF111111),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              '수정하기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard Variable',
              ),
            ),
          ),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 표지사진 수정 섹션
                GestureDetector(
                  onTap: () {
                    // 표지사진 수정 바텀시트 표시
                    _showCoverPhotoBottomSheet(context);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 173.h,
                    decoration: BoxDecoration(
                      // 기존 색상을 유지하면서 이미지를 배경으로 추가
                      color: const Color(0xFF5A5A5A),
                      borderRadius: BorderRadius.circular(8),
                      image:
                          currentCategory.categoryPhotoUrl != null &&
                                  currentCategory.categoryPhotoUrl!.isNotEmpty
                              ? DecorationImage(
                                image: CachedNetworkImageProvider(
                                  currentCategory.categoryPhotoUrl!,
                                ),
                                fit: BoxFit.cover,
                              )
                              : null,
                    ),
                    // child는 Container로 감싸서 opacity 적용
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, color: Colors.white, size: 51.sp),
                            SizedBox(height: 8.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '표지사진 수정',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: 'Pretendard Variable',
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Image.asset(
                                  'assets/edit.png',
                                  width: 18.w,
                                  height: 18.h,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24.h),

                // 카테고리 이름 섹션
                Container(
                  width: double.infinity,
                  height: 75.h,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 16.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1c1c1c),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '카테고리 이름',
                        style: TextStyle(
                          color: const Color(0xFFAAAAAA),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Pretendard Variable',
                        ),
                      ),

                      Flexible(
                        child: Text(
                          currentCategory.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Pretendard Variable',
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // 알림설정 섹션
                Container(
                  width: double.infinity,
                  height: 62.h,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1c1c1c),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '알림설정',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Pretendard Variable',
                          ),
                        ),
                      ),
                      Switch(
                        value: _notificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _notificationEnabled = value;
                          });
                        },
                        activeColor: Colors.black,
                        activeTrackColor: const Color(0xFFf9f9f9),
                        inactiveThumbColor: Colors.black,
                        inactiveTrackColor: const Color(0xFFf9f9f9),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),
                // 나가기 버튼
                SizedBox(
                  width: double.infinity,
                  height: 62.h,
                  child: ElevatedButton(
                    onPressed: () {
                      // 카테고리 나가기 확인 다이얼로그
                      _showExitDialog(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1c1c1c),
                      foregroundColor: Color(0xffff0000),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/log_out.png',
                          width: 24.w,
                          height: 24.h,
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          '나가기',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Pretendard Variable',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 표지사진 수정 바텀시트
  void _showCoverPhotoBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1c1c1c),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들바
              Container(
                margin: EdgeInsets.only(top: 12.w),
                width: 56.w,
                height: 3.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFcccccc),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 9.h),
              Text(
                '표지 사진 수정',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 18.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 9.h),
              Divider(color: const Color(0xFF5A5A5A)),
              SizedBox(height: 9.h),

              // 카메라로 촬영
              ListTile(
                leading: Image.asset(
                  'assets/camera_archive_edit.png',
                  width: 24.w,
                  height: 24.h,
                ),
                title: Text(
                  '사진찍기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),

              // 갤러리에서 선택
              ListTile(
                leading: Image.asset(
                  'assets/library_archive_edit.png',
                  width: 24.w,
                  height: 24.h,
                ),
                title: Text(
                  '라이브러리에서 선택',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),

              // 카테고리에서 선택
              ListTile(
                leading: Image.asset(
                  'assets/archiving_archive.png',
                  width: 24.w,
                  height: 24.h,
                ),
                title: Text(
                  '카테고리에서 선택',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _selectFromCategory();
                },
              ),

              // 표지삭제
              ListTile(
                leading: Image.asset(
                  'assets/trash_archive_edit.png',
                  width: 24.w,
                  height: 24.h,
                ),
                title: Text(
                  '표지삭제',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCoverPhoto();
                },
              ),

              //SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        );
      },
    );
  }

  /// 카메라로 사진 촬영
  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);
        await _updateCoverPhoto(imageFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카메라 촬영 중 오류가 발생했습니다.'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  /// 갤러리에서 사진 선택
  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);
        await _updateCoverPhoto(imageFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('갤러리 선택 중 오류가 발생했습니다.'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
    }
  }

  /// 카테고리에서 사진 선택
  Future<void> _selectFromCategory() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                CategoryCoverPhotoSelectorScreen(category: widget.category),
      ),
    );

    if (result != null) {
      // 선택된 사진 URL로 업데이트 성공 - 카테고리 데이터 다시 로드
      final categoryController = context.read<CategoryController>();
      final authController = context.read<AuthController>();
      final userId = authController.getUserId;
      if (userId != null) {
        await categoryController.loadUserCategories(userId, forceReload: true);
      }
    }
  }

  /// 갤러리/카메라에서 선택한 파일로 표지사진 업데이트
  Future<void> _updateCoverPhoto(File imageFile) async {
    final categoryController = context.read<CategoryController>();

    final success = await categoryController.updateCoverPhotoFromGallery(
      categoryId: widget.category.id,
      imageFile: imageFile,
    );

    if (success) {
      // 카테고리 데이터 다시 로드
      final authController = context.read<AuthController>();
      final userId = authController.getUserId;
      if (userId != null) {
        await categoryController.loadUserCategories(userId, forceReload: true);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '표지사진이 변경되었습니다.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFF1c1c1c),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(categoryController.error ?? '표지사진 변경에 실패했습니다.'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  /// 표지사진 삭제
  Future<void> _deleteCoverPhoto() async {
    final categoryController = context.read<CategoryController>();

    final success = await categoryController.deleteCoverPhoto(
      widget.category.id,
    );

    if (success) {
      // 카테고리 데이터 다시 로드
      final authController = context.read<AuthController>();
      final userId = authController.getUserId;
      if (userId != null) {
        await categoryController.loadUserCategories(userId, forceReload: true);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('표지사진이 삭제되었습니다.'),
          backgroundColor: Color(0xFF1c1c1c),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(categoryController.error ?? '표지사진 삭제에 실패했습니다.'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }

  // 나가기 확인 다이얼로그
  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1c1c1c),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '카테고리 나가기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              fontFamily: 'Pretendard Variable',
            ),
          ),
          content: Text(
            '정말로 이 카테고리에서 나가시겠습니까?\n나가면 이 카테고리의 사진들을 더 이상 볼 수 없습니다.',
            style: TextStyle(
              color: const Color(0xFFCCCCCC),
              fontSize: 14.sp,
              fontFamily: 'Pretendard Variable',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(
                  color: const Color(0xFFcccccc),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Pretendard Variable',
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                // 다이얼로그 닫기 전에 BuildContext를 저장
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                navigator.pop(); // 다이얼로그 닫기

                // 실제 카테고리 나가기 로직 수행
                final categoryController = context.read<CategoryController>();
                final authController = context.read<AuthController>();
                final userId = authController.getUserId;

                if (userId != null) {
                  await categoryController.leaveCategoryByUid(
                    widget.category.id,
                    userId,
                  );

                  debugPrint(
                    '카테고리 나가기 결과 - error: ${categoryController.error}',
                  );

                  if (categoryController.error == null) {
                    debugPrint('카테고리 나가기 성공 - 페이지 이동 시작');

                    // 성공 시 홈 화면의 아카이브 탭으로 이동

                    navigator.popUntil((route) => route.isFirst);
                    debugPrint('네비게이션 완료');
                  } else {
                    debugPrint('카테고리 나가기 실패: ${categoryController.error}');
                  }
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('사용자 정보를 확인할 수 없습니다.'),
                      backgroundColor: Color(0xFFcccccc),
                    ),
                  );
                }
              },
              child: Text(
                '나가기',
                style: TextStyle(
                  color: const Color(0xff000000),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Pretendard Variable',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
