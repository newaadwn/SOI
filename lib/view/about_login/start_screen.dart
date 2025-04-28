import 'package:flutter/material.dart';
import '../../theme/theme.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    // AuthViewModel authViewModel = Provider.of<AuthViewModel>(
    //  context,
    //  listen: false,
    //);

    // 로그인 상태 확인
    /*WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authViewModel.isLoggedIn) {
        Navigator.pushReplacementNamed(context, '/home_screen');
      }
    });*/
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/SOI.png',
              width: (349 / 393) * screenWidth,
              height: (128 / 852) * screenHeight,
            ),
            SizedBox(height: (201 / 852) * screenHeight),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/auth');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lightTheme.colorScheme.primary,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Container(
                width: (239 / 393) * screenWidth,
                height: (59 / 852) * screenHeight,
                alignment: Alignment.center,
                child: Text(
                  '시작하기',
                  style: TextStyle(
                    color: AppTheme.lightTheme.colorScheme.onPrimary,
                    fontSize: (24 / 852) * screenHeight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(height: (19 / 852) * screenHeight),
            ElevatedButton(
              onPressed: () {
                // 로그인 페이지로 이동
                Navigator.pushNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.lightTheme.colorScheme.primary,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Container(
                width: (239 / 393) * screenWidth,
                height: (59 / 852) * screenHeight,
                alignment: Alignment.center,
                child: Text(
                  '로그인',
                  style: TextStyle(
                    color: AppTheme.lightTheme.colorScheme.onPrimary,
                    fontSize: (24 / 852) * screenHeight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
