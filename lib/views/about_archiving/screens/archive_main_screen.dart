import 'dart:async'; // Timer 사용을 위해 추가
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/category_controller.dart';
import '../../../models/selected_friend_model.dart';
import '../../../theme/theme.dart';
import '../../about_friends/friend_list_add_screen.dart';
import '../components/overlapping_profiles_widget.dart';
import 'archive_detail/all_archives_screen.dart';
import 'archive_detail/my_archives_screen.dart';
import 'archive_detail/shared_archives_screen.dart';

// 아카이브 메인 화면
class ArchiveMainScreen extends StatefulWidget {
  const ArchiveMainScreen({super.key});

  @override
  State<ArchiveMainScreen> createState() => _ArchiveMainScreenState();
}

class _ArchiveMainScreenState extends State<ArchiveMainScreen> {
  int _selectedIndex = 0;

  // 컨트롤러들
  final _categoryNameController = TextEditingController();
  final _searchController = TextEditingController();
  final PageController _pageController = PageController(); // PageView 컨트롤러 추가

  // 검색 debounce를 위한 Timer
  Timer? _searchDebounceTimer;

  // Provider 참조를 미리 저장 (dispose에서 안전하게 사용하기 위함)
  CategoryController? _categoryController;

  // 편집 모드 상태 관리
  bool _isEditMode = false;
  String? _editingCategoryId;
  final _editingNameController = TextEditingController();
  final ValueNotifier<bool> _hasTextChangedNotifier = ValueNotifier<bool>(
    false,
  );
  String _originalText = ''; // 원본 텍스트 저장

  // 선택된 친구들 상태 관리
  List<SelectedFriendModel> _selectedFriends = [];

  // 탭 화면 목록을 동적으로 생성하는 메서드
  List<Widget> get _screens => [
    AllArchivesScreen(
      isEditMode: _isEditMode,
      editingCategoryId: _editingCategoryId,
      editingController: _editingNameController,
      onStartEdit: startEditMode,
    ),
    MyArchivesScreen(
      isEditMode: _isEditMode,
      editingCategoryId: _editingCategoryId,
      editingController: _editingNameController,
      onStartEdit: startEditMode,
    ),
    SharedArchivesScreen(
      isEditMode: _isEditMode,
      editingCategoryId: _editingCategoryId,
      editingController: _editingNameController,
      onStartEdit: startEditMode,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 검색 기능 설정
    _searchController.addListener(_onSearchChanged);

    // ✅ 최적화: 초기화 작업을 지연시켜 UI 블로킹 방지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 다음 프레임에서 실행하여 UI 렌더링을 먼저 완료
      Future.delayed(Duration.zero, () {
        _categoryController?.clearSearch(notify: false);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Provider 참조를 안전하게 저장
    _categoryController ??= Provider.of<CategoryController>(
      context,
      listen: false,
    );
  }

  void _onSearchChanged() {
    // 이전 타이머 취소
    _searchDebounceTimer?.cancel();

    // 300ms 지연 후 검색 실행 (타이핑 중 깜빡거림 방지)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _categoryController?.searchCategories(_searchController.text);
    });
  }

  // 편집 모드 관련 메서드들
  void startEditMode(String categoryId, String currentName) {
    // 현재 사용자의 커스텀 이름 가져오기
    final authController = AuthController();
    final userId = authController.getUserId;

    // 카테고리 정보 가져오기
    String displayName = currentName;
    if (userId != null && _categoryController != null) {
      // 카테고리 찾기
      final category = _categoryController!.userCategoryList.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('Category not found'),
      );
      // 사용자의 커스텀 이름 또는 기본 이름 사용
      displayName = _categoryController!.getCategoryDisplayName(
        category,
        userId,
      );
    }

    setState(() {
      _isEditMode = true;
      _editingCategoryId = categoryId;
      _originalText = displayName; // 현재 표시되는 이름 저장
      _hasTextChangedNotifier.value = false; // 초기 상태는 변경 없음

      // 컨트롤러 완전히 초기화
      _editingNameController.clear();
      _editingNameController.text = displayName;

      // 또는 선택과 커서 위치도 리셋
      _editingNameController.selection = TextSelection.fromPosition(
        TextPosition(offset: displayName.length),
      );

      // 텍스트 변경 리스너 추가
      _editingNameController.addListener(_onTextChanged);
    });
  }

  // 텍스트 변경 감지 메서드 (setState 없음!)
  void _onTextChanged() {
    // 원본 텍스트와 다르면 변경된 것으로 간주 (빈 텍스트도 허용)
    final hasChanged =
        _editingNameController.text.trim() != _originalText.trim();

    if (_hasTextChangedNotifier.value != hasChanged) {
      _hasTextChangedNotifier.value =
          hasChanged; // ValueNotifier만 업데이트 (setState 없음!)
    }
  }

  void cancelEditMode() {
    if (mounted) {
      setState(() {
        // 리스너 제거
        _editingNameController.removeListener(_onTextChanged);

        _isEditMode = false;
        _editingCategoryId = null;
        _hasTextChangedNotifier.value = false;
        _originalText = '';
        _editingNameController.clear();
      });
    }
  }

  Future<void> confirmEditMode() async {
    if (_editingCategoryId == null) return;

    final trimmedText = _editingNameController.text.trim();

    // 빈 텍스트 입력 시에만 에러 메시지 표시
    if (trimmedText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이름을 입력해주세요'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
      return;
    }

    // 사용자별 커스텀 이름 업데이트
    try {
      // 현재 사용자 ID 가져오기
      final authController = AuthController();
      final userId = authController.getUserId;

      if (userId == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      // 커스텀 이름 업데이트
      await _categoryController?.updateCustomCategoryName(
        categoryId: _editingCategoryId!,
        userId: userId,
        customName: trimmedText,
      );

      // 리스너 제거 후 모드 종료
      _editingNameController.removeListener(_onTextChanged);
      cancelEditMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('내 카테고리 이름이 수정되었습니다'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이름 수정 중 오류가 발생했습니다'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 편집 모드일 때 바깥 부분 클릭 시 편집 모드 해제
        if (_isEditMode) {
          cancelEditMode();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        resizeToAvoidBottomInset: true,

        appBar: AppBar(
          centerTitle: true,
          leadingWidth: 90.w,
          title: Column(
            children: [
              Text(
                'SOI',
                style: TextStyle(
                  color: Color(0xfff9f9f9),
                  fontSize: 20.sp,
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 30.h),
            ],
          ),
          backgroundColor: AppTheme.lightTheme.colorScheme.surface,
          toolbarHeight: 70.h,
          leading: Row(
            children: [
              SizedBox(width: 32.w),
              Consumer<AuthController>(
                builder: (context, authController, _) {
                  return FutureBuilder(
                    future: authController.getUserProfileImageUrl(),
                    builder: (context, imageSnapshot) {
                      String profileImageUrl = imageSnapshot.data ?? '';

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 8.h,
                        ),
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle),
                          child: Builder(
                            builder:
                                (context) =>
                                    profileImageUrl.isNotEmpty
                                        ? InkWell(
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/profile_screen',
                                            );
                                          },
                                          child: SizedBox(
                                            width: 34.w,
                                            height: 34.h,
                                            child: CircleAvatar(
                                              // 🔥 메모리 최적화: 프로필 이미지 캐시 크기 제한
                                              backgroundImage:
                                                  CachedNetworkImageProvider(
                                                    profileImageUrl,
                                                    maxHeight:
                                                        100, // 작은 프로필 이미지 크기 제한
                                                    maxWidth: 100,
                                                  ),
                                              onBackgroundImageError: (
                                                exception,
                                                stackTrace,
                                              ) {
                                                Future.microtask(
                                                  () =>
                                                      authController
                                                          .cleanInvalidProfileImageUrl(),
                                                );
                                              },
                                              child:
                                                  profileImageUrl.isEmpty
                                                      ? Icon(
                                                        Icons.person,
                                                        color: Colors.white,
                                                      )
                                                      : null,
                                            ),
                                          ),
                                        )
                                        : InkWell(
                                          onTap: () {
                                            Navigator.pushNamed(
                                              context,
                                              '/profile_screen',
                                            );
                                          },
                                          child: SizedBox(
                                            width: 34.w,
                                            height: 34.h,
                                            child: CircleAvatar(
                                              backgroundColor: Colors.grey,
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 32.w),
              child: IconButton(
                onPressed: _showCategoryBottomSheet,
                icon: SizedBox(
                  child: Icon(Icons.add, color: Colors.white, size: 33.sp),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(60.sp),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 8.w),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildChip('전체', 0)),
                      Expanded(child: _buildChip('개인앨범', 1)),
                      Expanded(child: _buildChip('공유앨범', 2)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // 검색 바
            Padding(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 15.h,
                bottom: 15.h,
              ),
              child: Container(
                height: 41.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(16.6),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 10.w),
                    Icon(
                      Icons.search,
                      color: const Color(0xFFCCCCCC),
                      size: 24.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: TextField(
                          controller: _searchController,
                          textAlignVertical: TextAlignVertical.center,
                          cursorColor: const Color(0xFFCCCCCC),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10.w,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                children: _screens,
              ),
            ),

            if (_isEditMode)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: confirmEditMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26.9),
                          ),
                        ),
                        child: Text('확인'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: cancelEditMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF323232),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26.9),
                          ),
                        ),
                        child: Text('취소'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 선택 가능한 Chip 위젯 생성
  Widget _buildChip(String label, int index) {
    final isSelected = _selectedIndex == index;

    return IntrinsicWidth(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          // PageView도 함께 이동 - 부드러운 애니메이션으로 변경
          _pageController.animateToPage(
            index,
            duration: Duration(milliseconds: 1),
            curve: Curves.easeInOut,
          );
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 1),
          curve: Curves.easeInOut,
          height: 43.h,
          padding: EdgeInsets.only(top: 3.h, right: 17.w, left: 17.w),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF323232) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  // 카테고리 추가 bottom sheet 표시
  void _showCategoryBottomSheet() {
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  height: 200.h,
                  decoration: const BoxDecoration(
                    color: Color(0xFF171717),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24.8),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더 영역
                      Padding(
                        padding: EdgeInsets.fromLTRB(12.w, 17.h, 20.w, 8.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 뒤로가기 버튼
                            SizedBox(
                              width: 34.w,
                              height: 38.h,
                              child: IconButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _categoryNameController.clear();
                                  setState(() {
                                    _selectedFriends = [];
                                  });
                                },
                                icon: Icon(
                                  Icons.arrow_back_ios,
                                  color: const Color(0xFFD9D9D9),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),

                            // 제목
                            Text(
                              '새 카테고리 만들기',
                              style: TextStyle(
                                color: const Color(0xFFFFFFFF),
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Pretendard',
                                letterSpacing: -0.5,
                              ),
                            ),

                            // 저장 버튼
                            Container(
                              width: 51.w,
                              height: 25.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF323232),
                                borderRadius: BorderRadius.circular(16.5),
                              ),
                              padding: EdgeInsets.only(top: 2.h),
                              child: TextButton(
                                onPressed: () {
                                  _createNewCategory();
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  '저장',
                                  style: TextStyle(
                                    color: const Color(0xFFFFFFFF),
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Pretendard',
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 구분선
                      Container(
                        width: screenWidth,
                        height: 1,
                        color: const Color(0xFF3D3D3D),
                        margin: EdgeInsets.symmetric(horizontal: 2.w),
                      ),

                      // 친구 추가 섹션
                      if (_selectedFriends.isEmpty)
                        // 친구 추가하기 버튼
                        GestureDetector(
                          onTap: () async {
                            // add_category_widget.dart와 동일한 방식으로 처리
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => FriendListAddScreen(
                                      categoryMemberUids:
                                          _selectedFriends
                                              .map((friend) => friend.uid)
                                              .toList(),
                                      allowDeselection: true,
                                    ),
                              ),
                            );

                            if (result != null) {
                              setModalState(() {
                                _selectedFriends = result;
                              });

                              for (final friend in _selectedFriends) {
                                debugPrint('- ${friend.name} (${friend.uid})');
                              }
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.only(top: 10.h, left: 12.w),
                            child: Container(
                              width: 117.w,
                              height: 35.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFF323232),
                                borderRadius: BorderRadius.circular(16.5),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/category_add.png',
                                    width: 17.sp,
                                    height: 17.sp,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    '친구 추가하기',
                                    style: TextStyle(
                                      color: const Color(0xFFE2E2E2),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w400,
                                      fontFamily: 'Pretendard',
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // 선택된 친구들 표시 (+ 버튼 포함)
                      if (_selectedFriends.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 10.h, left: 12.w),
                          child: OverlappingProfilesWidget(
                            selectedFriends: _selectedFriends,
                            onAddPressed: () async {
                              final result = await Navigator.push<
                                List<SelectedFriendModel>
                              >(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => FriendListAddScreen(
                                        categoryMemberUids:
                                            _selectedFriends
                                                .map((friend) => friend.uid)
                                                .toList(),
                                        allowDeselection: true,
                                      ),
                                ),
                              );

                              if (result != null) {
                                setModalState(() {
                                  _selectedFriends = result;
                                });

                                for (final friend in _selectedFriends) {
                                  debugPrint(
                                    '- ${friend.name} (${friend.uid})',
                                  );
                                }
                              }
                            },
                            showAddButton: true,
                          ),
                        ),

                      // 입력 필드 영역
                      Padding(
                        padding: EdgeInsets.only(left: 22.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _categoryNameController,
                              maxLength: 20,
                              cursorColor: const Color(0xFFCCCCCC),
                              style: TextStyle(
                                color: const Color(0xFFFFFFFF),
                                fontSize: 14.sp,
                                fontFamily: 'Pretendard',
                              ),
                              decoration: InputDecoration(
                                hintText: '카테고리의 이름을 입력해 주세요.',
                                hintStyle: TextStyle(
                                  color: const Color(0xFFCCCCCC),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Pretendard',
                                  letterSpacing: -0.4,
                                ),
                                border: InputBorder.none,
                                counterText: '',
                              ),
                              autofocus: true,
                            ),

                            // 커스텀 글자 수 표시
                            Padding(
                              padding: EdgeInsets.only(right: 11.w),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _categoryNameController,
                                  builder: (context, value, child) {
                                    return Text(
                                      '${value.text.length}/20자',
                                      style: TextStyle(
                                        color: const Color(0xFFCCCCCC),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Pretendard',
                                        letterSpacing: -0.4,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    ).then((_) {
      // 바텀시트가 닫힐 때 선택된 친구들 초기화
      if (mounted) {
        setState(() {
          _selectedFriends = [];
        });
      }
    });
  }

  // 카테고리 생성 처리 함수
  Future<void> _createNewCategory() async {
    if (_categoryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_snackBarComponenet('카테고리 이름을 입력해주세요'));
      return;
    }

    try {
      // Provider에서 컨트롤러들 가져오기
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      // 현재 사용자 정보 가져오기
      final String? userId = authController.getUserId;

      if (userId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(_snackBarComponenet('로그인이 필요합니다. 다시 로그인해주세요.'));
        return;
      }

      // 메이트 리스트 준비 (현재 사용자 + 선택된 친구들)
      // 중요: mates 필드에는 Firebase Auth UID를 사용해야 함
      List<String> mates = [userId];

      // 선택된 친구들의 UID 추가
      for (final friend in _selectedFriends) {
        if (!mates.contains(friend.uid)) {
          mates.add(friend.uid);
        }
      }

      // 카테고리 생성
      await categoryController.createCategory(
        name: _categoryNameController.text.trim(),
        mates: mates,
      );

      // bottom sheet 닫기
      Navigator.pop(context);
      _categoryNameController.clear();

      // 선택된 친구들 초기화
      setState(() {
        _selectedFriends = [];
      });

      // 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(_showSuccessSnackBar());
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_snackBarComponenet('카테고리 생성 중 오류가 발생했습니다'));
    }
  }

  SnackBar _showSuccessSnackBar() {
    return SnackBar(
      content: Row(
        children: [
          SvgPicture.asset(
            'assets/archive_icon.svg',
            width: 19.sp,
            height: 17.sp,
            colorFilter: ColorFilter.mode(Color(0xffc2c0c0), BlendMode.srcIn),
          ),
          SizedBox(width: 15.w),
          Text(
            '새 카테고리가 추가 되었습니다.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      backgroundColor: Color(0xFF323232),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.5)),
    );
  }

  SnackBar _snackBarComponenet(String content) {
    return SnackBar(
      content: Text(content, style: TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF5A5A5A),
    );
  }

  @override
  void dispose() {
    // 검색 debounce 타이머 정리
    _searchDebounceTimer?.cancel();

    // 편집 컨트롤러 리스너 안전하게 제거
    _editingNameController.removeListener(_onTextChanged);

    // 컨트롤러들 정리
    _categoryNameController.dispose();
    _editingNameController.dispose(); // 편집 컨트롤러 정리
    _hasTextChangedNotifier.dispose(); // ValueNotifier 정리
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _pageController.dispose(); // PageController 정리

    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }
}
