import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../widgets/custom_drawer.dart';
import 'all_archives_screen.dart';
import 'personal_archives_screen.dart';
import 'shared_archives_screen.dart';

class ArchiveMainScreen extends StatefulWidget {
  const ArchiveMainScreen({super.key});

  @override
  State<ArchiveMainScreen> createState() => _ArchiveMainScreenState();
}

class _ArchiveMainScreenState extends State<ArchiveMainScreen> {
  int _selectedIndex = 0;

  // 탭 화면 목록
  final List<Widget> _screens = const [
    AllArchivesScreen(),
    PersonalArchivesScreen(),
    SharedArchivesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    //double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
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
                                        backgroundImage: NetworkImage(
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
            onPressed: () {
              Navigator.pushNamed(context, '/add_contacts');
            },
            icon: Image.asset('assets/person_add.png', width: 19, height: 19),
          ),
          IconButton(
            onPressed: () {},
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
}
