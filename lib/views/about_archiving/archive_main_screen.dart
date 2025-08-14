import 'dart:async'; // 🎯 Timer 사용을 위해 추가
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import 'all_archives_screen.dart';
import 'my_archives_screen.dart';
import 'shared_archives_screen.dart';

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

  // 🎯 검색 debounce를 위한 Timer
  Timer? _searchDebounceTimer;

  // Provider 참조를 미리 저장 (dispose에서 안전하게 사용하기 위함)
  CategoryController? _categoryController;

  // 🎯 편집 모드 상태 관리
  bool _isEditMode = false;
  String? _editingCategoryId;
  final _editingNameController = TextEditingController();
  final ValueNotifier<bool> _hasTextChangedNotifier = ValueNotifier<bool>(
    false,
  ); // 🎯 ValueNotifier 사용
  String _originalText = ''; // 🎯 원본 텍스트 저장

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
    // 🎯 이전 타이머 취소
    _searchDebounceTimer?.cancel();

    // 🎯 300ms 지연 후 검색 실행 (타이핑 중 깜빡거림 방지)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _categoryController?.searchCategories(_searchController.text);
    });
  }

  // 🎯 편집 모드 관련 메서드들
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

      // 🎯 텍스트 변경 리스너 추가
      _editingNameController.addListener(_onTextChanged);
    });
  }

  // 🎯 텍스트 변경 감지 메서드 (setState 없음!)
  void _onTextChanged() {
    // 🎯 원본 텍스트와 다르면 변경된 것으로 간주 (빈 텍스트도 허용)
    final hasChanged =
        _editingNameController.text.trim() != _originalText.trim();

    if (_hasTextChangedNotifier.value != hasChanged) {
      _hasTextChangedNotifier.value =
          hasChanged; // 🎯 ValueNotifier만 업데이트 (setState 없음!)
    }
  }

  void cancelEditMode() {
    setState(() {
      // 🎯 리스너 제거
      _editingNameController.removeListener(_onTextChanged);

      _isEditMode = false;
      _editingCategoryId = null;
      _hasTextChangedNotifier.value = false;
      _originalText = '';
      _editingNameController.clear();
    });
  }

  Future<void> confirmEditMode() async {
    if (_editingCategoryId == null) return;

    final trimmedText = _editingNameController.text.trim();

    // 🎯 빈 텍스트 입력 시에만 에러 메시지 표시
    if (trimmedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이름을 입력해주세요'),
          backgroundColor: Color(0xff1c1c1c),
        ),
      );
      return;
    }

    // 🎯 사용자별 커스텀 이름 업데이트
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

      // 🎯 리스너 제거 후 모드 종료
      _editingNameController.removeListener(_onTextChanged);
      cancelEditMode();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('내 카테고리 이름이 수정되었습니다'),
          backgroundColor: Color(0xff1c1c1c),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이름 수정 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                color: AppTheme.lightTheme.colorScheme.secondary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                fontFamily: GoogleFonts.inter().fontFamily,
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
                                            backgroundImage:
                                                CachedNetworkImageProvider(
                                                  profileImageUrl,
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildChip('전체', 0),
                    SizedBox(width: 8.w),
                    _buildChip('개인앨범', 1),
                    SizedBox(width: 8.w),
                    _buildChip('공유앨범', 2),
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
                        style: TextStyle(color: Colors.white, fontSize: 14.sp),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10.w),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _screens[_selectedIndex]),

          if (_isEditMode)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
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
                  SizedBox(width: 12.w),
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 선택 가능한 Chip 위젯 생성
  Widget _buildChip(String label, int index) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff292929) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
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
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: 200.h,
              decoration: const BoxDecoration(
                color: Color(0xFF171717),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.8)),
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
                          decoration: BoxDecoration(
                            color: const Color(0xFF323232),
                            borderRadius: BorderRadius.circular(16.5),
                          ),
                          child: TextButton(
                            onPressed: () {
                              _createNewCategory();
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                  Padding(
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
          ),
    );
  }

  // 카테고리 생성 처리 함수
  Future<void> _createNewCategory() async {
    if (_categoryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '카테고리 이름을 입력해주세요',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xff1c1c1c),
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '로그인이 필요합니다. 다시 로그인해주세요.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xff1c1c1c),
          ),
        );
        return;
      }

      // 메이트 리스트 준비 (현재 사용자만 포함)
      List<String> mates = [userId];

      // 카테고리 생성
      await categoryController.createCategory(
        name: _categoryNameController.text.trim(),
        mates: mates,
      );

      // bottom sheet 닫기
      Navigator.pop(context);
      _categoryNameController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '카테고리 생성 중 오류가 발생했습니다',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xff1c1c1c),
        ),
      );
    }
  }

  @override
  void dispose() {
    // 🎯 검색 debounce 타이머 정리
    _searchDebounceTimer?.cancel();

    // 검색 리스너만 제거 (Controller는 Provider에서 관리되므로 건드리지 않음)
    _categoryNameController.dispose();
    _editingNameController.dispose(); // 🎯 편집 컨트롤러 정리
    _hasTextChangedNotifier.dispose(); // 🎯 ValueNotifier 정리
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}
