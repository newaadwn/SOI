import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme.dart';
import '../view_model/auth_view_model.dart';
import 'about_arcaving/archiving_screen.dart';
import 'about_camera/camera_screen.dart';
import 'home_screen.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class HomePageNavigationBar extends StatefulWidget {
  const HomePageNavigationBar({super.key});

  @override
  State<HomePageNavigationBar> createState() => _HomePageNavigationBarState();
}

class _HomePageNavigationBarState extends State<HomePageNavigationBar> {
  int currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    currentPageIndex = 1;

    // 앱이 실행될 때 잘못된 프로필 이미지 URL을 확인하고 정리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cleanInvalidProfileImages();
    });
  }

  // 잘못된 프로필 이미지 URL을 확인하고 정리하는 함수
  Future<void> _cleanInvalidProfileImages() async {
    try {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      if (authViewModel.currentUser != null) {
        await authViewModel.cleanInvalidProfileImageUrl();
      }
    } catch (e) {
      debugPrint('프로필 이미지 정리 중 오류 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(),
        child: NavigationBar(
          indicatorColor: Colors.transparent,
          backgroundColor: AppTheme.lightTheme.colorScheme.surface,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          onDestinationSelected: (int index) {
            setState(() {
              currentPageIndex = index;
            });
          },
          selectedIndex: currentPageIndex,
          destinations: <Widget>[
            const NavigationDestination(
              selectedIcon: Icon(Icons.home, color: Colors.white, size: 31),
              icon: Icon(Icons.home, size: 31, color: Color(0xff535252)),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.camera_alt, size: 31, color: Color(0xff535252)),
              selectedIcon: Icon(
                Icons.camera_alt,
                size: 31,
                color: Colors.white,
              ),
              label: '',
            ),
            const NavigationDestination(
              icon: Icon(
                FluentIcons.archive_24_filled,
                size: 31,
                color: Color(0xff535252),
              ),
              selectedIcon: Icon(
                FluentIcons.archive_24_filled,
                size: 31,
                color: Colors.white,
              ),
              label: '',
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: currentPageIndex,
        children: [
          const HomeScreen(),
          // 매번 새로운 카메라 스크린 인스턴스 생성
          currentPageIndex == 1 ? CameraScreen(key: UniqueKey()) : Container(),
          const ArchivingScreen(),
        ],
      ),
    );
  }
}
