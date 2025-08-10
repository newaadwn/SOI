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
// 전체 아카이브, 나의 아카이브, 공유 아카이브 화면으로 구성
// 전체 아카이브: 모든 사용자의 아카이브 목록 표시
// 나의 아카이브: 현재 사용자의 아카이브 목록 표시
// 공유 아카이브: 다른 사용자와 공유된 아카이브 목록 표시
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

  // Provider 참조를 미리 저장 (dispose에서 안전하게 사용하기 위함)
  CategoryController? _categoryController;

  // 탭 화면 목록
  final List<Widget> _screens = const [
    AllArchivesScreen(),
    MyArchivesScreen(),
    SharedArchivesScreen(),
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
    _categoryController?.searchCategories(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        centerTitle: true,
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
        toolbarHeight: 55.h,
        leading: Consumer<AuthController>(
          builder: (context, authController, _) {
            return FutureBuilder(
              future: authController.getUserProfileImageUrl(),
              builder: (context, imageSnapshot) {
                String profileImageUrl = imageSnapshot.data ?? '';

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
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
                                      width: 34,
                                      height: 34,
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
        actions: [
          IconButton(
            onPressed: _showCategoryBottomSheet,
            icon: SizedBox(
              child: Icon(Icons.add, color: Colors.white, size: 33.sp),
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
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14.sp,
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
                          height: 35.h,
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
    // 검색 리스너만 제거 (Controller는 Provider에서 관리되므로 건드리지 않음)
    _categoryNameController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}
