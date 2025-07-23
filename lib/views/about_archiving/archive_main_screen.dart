import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../widgets/custom_drawer.dart';
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

  // 탭 화면 목록
  final List<Widget> _screens = const [
    AllArchivesScreen(),
    MyArchivesScreen(),
    SharedArchivesScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    //double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      resizeToAvoidBottomInset: true, // 기본값이 true
      drawer: CustomDrawer(),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'SOI',
          style: TextStyle(color: AppTheme.lightTheme.colorScheme.secondary),
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        toolbarHeight: 70 / 852 * screenHeight,
        leading: Consumer<AuthController>(
          builder: (context, authController, _) {
            return FutureBuilder(
              future: authController.getUserProfileImageUrl(),
              builder: (context, imageSnapshot) {
                String profileImageUrl = imageSnapshot.data ?? '';

                return Padding(
                  padding: const EdgeInsets.all(8.0),
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
                                      Scaffold.of(context).openDrawer();
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
                                          debugPrint(
                                            '프로필 이미지 로드 오류: $exception',
                                          );
                                          // 유효하지 않은 이미지 URL을 정리
                                          Future.microtask(
                                            () =>
                                                authController
                                                    .cleanInvalidProfileImageUrl(),
                                          );
                                        },
                                        child:
                                            profileImageUrl.isEmpty
                                                ? const Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 24,
                                                )
                                                : null,
                                      ),
                                    ),
                                  )
                                  : InkWell(
                                    onTap: () {
                                      Scaffold.of(context).openDrawer();
                                    },
                                    child: const CircleAvatar(
                                      backgroundColor: Colors.grey,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 34,
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
            icon: Icon(Icons.add, color: Colors.white),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildChip('전체', 0),
                const SizedBox(width: 8),
                _buildChip('나의 기록', 1),
                const SizedBox(width: 8),
                _buildChip('공유 기록', 2),
              ],
            ),
          ),
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }

  // 선택 가능한 Chip 위젯 생성
  Widget _buildChip(String label, int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xff292929) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // 카테고리 추가 bottom sheet 표시
  void _showCategoryBottomSheet() {
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
              height: MediaQuery.of(context).size.height * 0.3,
              decoration: BoxDecoration(
                color: Color(0xFF171717),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더 영역
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 17, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 뒤로가기 버튼
                        SizedBox(
                          width: 34,
                          height: 38,
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _categoryNameController.clear();
                            },
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: Color(0xFFD9D9D9),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),

                        // 제목
                        Text(
                          '새 카테고리 만들기',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Pretendard Variable',
                            letterSpacing: -0.5 * 16 / 100,
                          ),
                        ),

                        // 저장 버튼
                        Container(
                          width: 51,
                          height: 25,
                          decoration: BoxDecoration(
                            color: Color(0xFF323232),
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
                                color: Color(0xFFFFFFFF),
                                fontSize: 14,
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
                    width: 390.5,
                    height: 1,
                    color: Color(0xFF3D3D3D),
                    margin: EdgeInsets.symmetric(horizontal: 2),
                  ),

                  // 친구 추가 섹션
                  Padding(
                    padding: EdgeInsets.only(top: 10, left: 12),
                    child: Container(
                      width: 117,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(0xFF323232),
                        borderRadius: BorderRadius.circular(16.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Color(0xFFE2E2E2), size: 17),
                          SizedBox(width: 6),
                          Text(
                            '친구 추가하기',
                            style: TextStyle(
                              color: Color(0xFFE2E2E2),
                              fontSize: 14,
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
                    padding: EdgeInsets.only(left: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _categoryNameController,
                          maxLength: 20,
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 14,
                            fontFamily: 'Pretendard Variable',
                          ),
                          decoration: InputDecoration(
                            hintText: '카테고리의 이름을 입력해 주세요.',
                            hintStyle: TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 14,
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
                                    color: Color(0xFFCCCCCC),
                                    fontSize: 12,
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
    _categoryNameController.dispose();
    super.dispose();
  }
}
