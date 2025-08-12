import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/category_data_model.dart';
import '../../models/auth_model.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/auth_controller.dart';
import '../about_friends/friend_list_screen.dart';
import 'category_cover_photo_selector_screen.dart';
import 'widgets/category_edit/category_cover_section.dart';
import 'widgets/category_edit/category_info_section.dart';
import 'widgets/category_edit/notification_setting_section.dart';
import 'widgets/category_edit/friends_list_widget.dart';
import 'widgets/category_edit/add_friend_button.dart';
import 'widgets/category_edit/exit_button.dart';

class CategoryEditorScreen extends StatefulWidget {
  final CategoryDataModel category;

  const CategoryEditorScreen({super.key, required this.category});

  @override
  State<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<CategoryEditorScreen> {
  bool _notificationEnabled = true;
  bool _isExpanded = false;

  // 친구 정보 캐시
  Map<String, AuthModel> _friendsInfo = {};
  bool _isLoadingFriends = false;

  @override
  void initState() {
    super.initState();
    _loadFriendsInfo();
  }

  @override
  void didUpdateWidget(CategoryEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 카테고리가 변경되었거나 mates가 변경된 경우 친구 정보 다시 로드
    if (oldWidget.category.id != widget.category.id ||
        oldWidget.category.mates.length != widget.category.mates.length) {
      _loadFriendsInfo();
    }
  }

  // 친구 정보 로드
  Future<void> _loadFriendsInfo() async {
    if (widget.category.mates.isEmpty) return;

    setState(() {
      _isLoadingFriends = true;
    });

    try {
      final authController = context.read<AuthController>();
      final Map<String, AuthModel> friendsInfo = {};

      for (String mateUid in widget.category.mates) {
        final userInfo = await authController.getUserInfo(mateUid);
        if (userInfo != null) {
          friendsInfo[mateUid] = userInfo;
        }
      }

      if (mounted) {
        setState(() {
          _friendsInfo = friendsInfo;
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
      debugPrint('친구 정보 로드 실패: $e');
    }
  }

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
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 표지사진 수정 섹션
                  CategoryCoverSection(
                    category: currentCategory,
                    onTap: () => _showCoverPhotoBottomSheet(context),
                  ),

                  SizedBox(height: 24.h),

                  // 카테고리 이름 섹션
                  CategoryInfoSection(category: currentCategory),

                  SizedBox(height: 12),

                  // 알림설정 섹션
                  NotificationSettingSection(
                    enabled: _notificationEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationEnabled = value;
                      });
                    },
                  ),
                  SizedBox(height: 24.h),

                  // 친구 추가 섹션
                  currentCategory.mates.length >= 2
                      ? FriendsListWidget(
                        category: currentCategory,
                        friendsInfo: _friendsInfo,
                        isLoadingFriends: _isLoadingFriends,
                        isExpanded: _isExpanded,
                        onExpandToggle: () {
                          setState(() {
                            _isExpanded = true;
                          });
                        },
                        onCollapseToggle: () {
                          setState(() {
                            _isExpanded = false;
                          });
                        },
                      )
                      : AddFriendButton(
                        category: currentCategory,
                        onPressed: () {
                          // Navigator 호출을 안전하게 처리
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => FriendListScreen(
                                        categoryId: currentCategory.id,
                                      ),
                                ),
                              );
                            }
                          });
                        },
                      ),
                  SizedBox(height: 24.h),

                  // 나가기 버튼
                  ExitButton(category: currentCategory),

                  SizedBox(height: 20.h),
                ],
              ),
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

    if (result != null && mounted) {
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

    if (success && mounted) {
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

    if (success && mounted) {
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
}
