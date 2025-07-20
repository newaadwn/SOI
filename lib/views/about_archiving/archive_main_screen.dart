import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../widgets/custom_drawer.dart';
import '../about_camera/widgets/add_category_widget.dart';
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

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
        toolbarHeight: screenHeight * 0.082, // 70/852 비율을 반응형으로
        leading: Consumer<AuthController>(
          builder: (context, authController, _) {
            return FutureBuilder(
              future: authController.getUserProfileImageUrl(),
              builder: (context, imageSnapshot) {
                String profileImageUrl = imageSnapshot.data ?? '';
                final profileSize = (screenWidth * 0.087).clamp(
                  30.0,
                  40.0,
                ); // 반응형 프로필 크기

                return Padding(
                  padding: EdgeInsets.all(screenWidth * 0.02), // 반응형 패딩
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
                                      width: profileSize,
                                      height: profileSize,
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
                                                ? Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size:
                                                      profileSize *
                                                      0.7, // 반응형 아이콘 크기
                                                )
                                                : null,
                                      ),
                                    ),
                                  )
                                  : InkWell(
                                    onTap: () {
                                      Scaffold.of(context).openDrawer();
                                    },
                                    child: CircleAvatar(
                                      backgroundColor: Colors.grey,
                                      radius: profileSize / 2,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: profileSize * 0.7, // 반응형 아이콘 크기
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
            icon: Icon(
              Icons.add,
              color: Colors.white,
              size: (screenWidth * 0.064).clamp(20.0, 28.0), // 반응형 아이콘 크기
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            (screenHeight * 0.074).clamp(50.0, 70.0),
          ), // 반응형 높이
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.043, // 반응형 패딩
              vertical: screenHeight * 0.01, // 반응형 패딩
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildChip('전체', 0),
                SizedBox(width: screenWidth * 0.021), // 반응형 간격
                _buildChip('나의 기록', 1),
                SizedBox(width: screenWidth * 0.021), // 반응형 간격
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
    bool isSelected = _selectedIndex == index;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.043, // 반응형 패딩
          vertical: screenHeight * 0.01, // 반응형 패딩
        ),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xff292929) : Colors.transparent,
          borderRadius: BorderRadius.circular(screenWidth * 0.053), // 반응형 반지름
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: (screenWidth * 0.037).clamp(12.0, 16.0), // 반응형 폰트 크기
          ),
        ),
      ),
    );
  }

  // 카테고리 추가 bottom sheet 표시
  void _showCategoryBottomSheet() {
    final screenHeight = MediaQuery.sizeOf(context).height;

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
              height: screenHeight * 0.5, // 반응형 높이
              decoration: BoxDecoration(
                color: Color(0xff171717),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(
                    (screenHeight * 0.02).clamp(12.0, 20.0),
                  ), // 반응형 반지름
                ),
              ),
              child: AddCategoryWidget(
                textController: _categoryNameController,
                scrollController: ScrollController(),
                onBackPressed: () {
                  Navigator.pop(context);
                  _categoryNameController.clear();
                },
                onSavePressed: () {
                  _createNewCategory();
                },
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
