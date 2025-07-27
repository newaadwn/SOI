import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 375;
    final isLargeScreen = screenWidth > 414;

    // 화면 크기에 따른 조정값들
    final toolbarHeight =
        isSmallScreen
            ? 60 / 852 * screenHeight
            : isLargeScreen
            ? 80 / 852 * screenHeight
            : 70 / 852 * screenHeight;

    final profileImageSize =
        isSmallScreen
            ? 28.0
            : isLargeScreen
            ? 40.0
            : 34.0;
    final profileIconSize =
        isSmallScreen
            ? 20.0
            : isLargeScreen
            ? 28.0
            : 24.0;
    final addIconSize =
        isSmallScreen
            ? 20.0
            : isLargeScreen
            ? 28.0
            : 24.0;
    final titleFontSize =
        isSmallScreen
            ? 18.0
            : isLargeScreen
            ? 24.0
            : 20.0;
    final appBarPadding = isSmallScreen ? 6.0 : 8.0;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'SOI',
          style: TextStyle(
            color: AppTheme.lightTheme.colorScheme.secondary,
            fontSize: titleFontSize,
          ),
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        toolbarHeight: toolbarHeight,
        leading: Consumer<AuthController>(
          builder: (context, authController, _) {
            return FutureBuilder(
              future: authController.getUserProfileImageUrl(),
              builder: (context, imageSnapshot) {
                String profileImageUrl = imageSnapshot.data ?? '';

                return Padding(
                  padding: EdgeInsets.all(appBarPadding),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
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
                                      width: profileImageSize,
                                      height: profileImageSize,
                                      child: CircleAvatar(
                                        backgroundImage:
                                            CachedNetworkImageProvider(
                                              profileImageUrl,
                                            ),
                                        onBackgroundImageError: (
                                          exception,
                                          stackTrace,
                                        ) {
                                          debugPrint(
                                            '프로필 이미지 로드 오류: $exception',
                                          );
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
                                                  size: profileIconSize,
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
                                    child: CircleAvatar(
                                      backgroundColor: Colors.grey,
                                      radius: profileImageSize / 2,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: profileIconSize,
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
            icon: Icon(Icons.add, color: Colors.white, size: addIconSize),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isSmallScreen ? 50 : 60),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12.0 : 16.0,
              vertical: isSmallScreen ? 6.0 : 8.0,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildChip('전체', 0, screenWidth, isSmallScreen),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    _buildChip('나의 기록', 1, screenWidth, isSmallScreen),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    _buildChip('공유 기록', 2, screenWidth, isSmallScreen),
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
              left: 20,
              right: 20,
              top: 15.0,
              bottom: 15.0,
            ),
            child: Container(
              height: 41,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(16.6),
              ),
              child: Row(
                children: [
                  SizedBox(width: 10),
                  Icon(Icons.search, color: const Color(0xFFCCCCCC), size: 34),
                  SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _searchController,
                        textAlignVertical: TextAlignVertical.center,
                        cursorColor: const Color(0xFFCCCCCC),
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 8.0 : 10.0,
                          ),
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
  Widget _buildChip(
    String label,
    int index,
    double screenWidth,
    bool isSmallScreen,
  ) {
    final isSelected = _selectedIndex == index;
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    final verticalPadding = isSmallScreen ? 6.0 : 8.0;
    final fontSize = isSmallScreen ? 13.0 : 14.0;
    final borderRadius = isSmallScreen ? 16.0 : 20.0;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xff292929) : Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: fontSize,
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
    final isSmallScreen = screenWidth < 375;
    final isLargeScreen = screenWidth > 414;

    // 반응형 값들
    final bottomSheetHeight =
        isSmallScreen
            ? 0.25
            : isLargeScreen
            ? 0.35
            : 0.3;
    final headerPadding =
        isSmallScreen
            ? const EdgeInsets.fromLTRB(10, 14, 16, 6)
            : const EdgeInsets.fromLTRB(12, 17, 20, 8);
    final backButtonSize =
        isSmallScreen ? const Size(28, 32) : const Size(34, 38);
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;
    final saveButtonSize =
        isSmallScreen ? const Size(45, 22) : const Size(51, 25);
    final saveFontSize = isSmallScreen ? 12.0 : 14.0;
    final addButtonSize =
        isSmallScreen ? const Size(105, 26) : const Size(117, 30);
    final addButtonFontSize = isSmallScreen ? 12.0 : 14.0;
    final addIconSize = isSmallScreen ? 15.0 : 17.0;
    final textFieldPadding = isSmallScreen ? 18.0 : 22.0;
    final textFieldFontSize = isSmallScreen ? 12.0 : 14.0;
    final counterFontSize = isSmallScreen ? 10.0 : 12.0;

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
              height: MediaQuery.of(context).size.height * bottomSheetHeight,
              decoration: const BoxDecoration(
                color: Color(0xFF171717),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더 영역
                  Padding(
                    padding: headerPadding,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 뒤로가기 버튼
                        SizedBox(
                          width: backButtonSize.width,
                          height: backButtonSize.height,
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _categoryNameController.clear();
                            },
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: const Color(0xFFD9D9D9),
                              size: isSmallScreen ? 12 : 15,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),

                        // 제목
                        Text(
                          '새 카테고리 만들기',
                          style: TextStyle(
                            color: const Color(0xFFFFFFFF),
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Pretendard Variable',
                            letterSpacing: -0.5 * titleFontSize / 100,
                          ),
                        ),

                        // 저장 버튼
                        Container(
                          width: saveButtonSize.width,
                          height: saveButtonSize.height,
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
                                fontSize: saveFontSize,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Pretendard Variable',
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
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                  ),

                  // 친구 추가 섹션
                  Padding(
                    padding: EdgeInsets.only(
                      top: isSmallScreen ? 8 : 10,
                      left: isSmallScreen ? 10 : 12,
                    ),
                    child: Container(
                      width: addButtonSize.width,
                      height: addButtonSize.height,
                      decoration: BoxDecoration(
                        color: const Color(0xFF323232),
                        borderRadius: BorderRadius.circular(16.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add,
                            color: const Color(0xFFE2E2E2),
                            size: addIconSize,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '친구 추가하기',
                            style: TextStyle(
                              color: const Color(0xFFE2E2E2),
                              fontSize: addButtonFontSize,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Pretendard Variable',
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 입력 필드 영역
                  Padding(
                    padding: EdgeInsets.only(left: textFieldPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _categoryNameController,
                          maxLength: 20,
                          style: TextStyle(
                            color: const Color(0xFFFFFFFF),
                            fontSize: textFieldFontSize,
                            fontFamily: 'Pretendard Variable',
                          ),
                          decoration: InputDecoration(
                            hintText: '카테고리의 이름을 입력해 주세요.',
                            hintStyle: TextStyle(
                              color: const Color(0xFFCCCCCC),
                              fontSize: textFieldFontSize,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Pretendard Variable',
                              letterSpacing: -0.4,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                        ),

                        // 커스텀 글자 수 표시
                        Padding(
                          padding: const EdgeInsets.only(right: 11),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _categoryNameController,
                              builder: (context, value, child) {
                                return Text(
                                  '${value.text.length}/20자',
                                  style: TextStyle(
                                    color: const Color(0xFFCCCCCC),
                                    fontSize: counterFontSize,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Pretendard Variable',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리 이름을 입력해주세요')));
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
        ).showSnackBar(SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해주세요.')));
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

      // 성공 메시지
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리가 생성되었습니다!')));
    } catch (e) {
      debugPrint('카테고리 생성 중 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카테고리 생성 중 오류가 발생했습니다')));
    }
  }

  @override
  void dispose() {
    // 검색 상태 초기화 (저장된 참조 사용)
    _categoryController?.clearSearch();

    _categoryNameController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}
