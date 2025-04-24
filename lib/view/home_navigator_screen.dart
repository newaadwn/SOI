import 'package:flutter/material.dart';
import '../theme/theme.dart';
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
      body:
          <Widget>[
            const HomeScreen(),
            const CameraScreen(),
            const ArchivingScreen(),
          ][currentPageIndex],
    );
  }
}
