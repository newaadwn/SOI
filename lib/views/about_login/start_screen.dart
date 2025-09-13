import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/theme.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool _isCheckingAutoLogin = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  /// ✅ 자동 로그인 체크
  Future<void> _checkAutoLogin() async {
    try {
      // debugPrint('🔄 앱 시작 - 자동 로그인 체크 중...');

      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final canAutoLogin = await authController.tryAutoLogin();

      if (mounted) {
        if (canAutoLogin) {
          // debugPrint('✅ 자동 로그인 성공 - 홈 화면으로 이동');
          Navigator.pushReplacementNamed(context, '/home_navigation_screen');
        } else {
          // debugPrint('❌ 자동 로그인 실패 - 시작 화면 표시');
          setState(() {
            _isCheckingAutoLogin = false;
          });
        }
      }
    } catch (e) {
      // debugPrint('❌ 자동 로그인 체크 오류: $e');
      if (mounted) {
        setState(() {
          _isCheckingAutoLogin = false;
        });
      }
    }
  }

  /// ✅ 로그인 버튼 클릭 처리
  Future<void> _handleLoginButtonPress() async {
    try {
      // debugPrint('🔄 로그인 버튼 클릭 - 로그인 기록 체크 중...');

      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );

      // 저장된 로그인 기록 확인
      final isLoggedIn = await authController.isLoggedIn();

      if (isLoggedIn) {
        // debugPrint('✅ 로그인 기록 발견 - 바로 홈 화면으로 이동');

        // 자동 로그인 시도
        final canAutoLogin = await authController.tryAutoLogin();

        if (canAutoLogin) {
          // ✅ 로그인 기록이 있으면 바로 홈 화면으로 이동
          Navigator.pushReplacementNamed(context, '/home_navigation_screen');
        } else {
          // 자동 로그인 실패 시 로그인 화면으로
          // debugPrint('❌ 자동 로그인 실패 - 로그인 화면으로 이동');
          Navigator.pushNamed(context, '/login');
        }
      } else {
        // debugPrint('❌ 로그인 기록 없음 - 로그인 화면으로 이동');
        Navigator.pushNamed(context, '/login');
      }
    } catch (e) {
      // debugPrint('❌ 로그인 버튼 처리 오류: $e');
      // 오류 발생 시 기본 로그인 화면으로
      Navigator.pushNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // ✅ 자동 로그인 체크 중일 때 로딩 화면 표시
    if (_isCheckingAutoLogin) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/SOI.png',
                width: (349 / 393) * screenWidth,
                height: (128 / 852) * screenHeight,
                // 메모리 최적화: 로고 이미지 캐시 크기 제한
                cacheHeight: ((128 / 852) * screenHeight * 2).toInt(),
                cacheWidth: ((349 / 393) * screenWidth * 2).toInt(),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                '로그인 확인 중...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

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
              // 메모리 최적화: 로고 이미지 캐시 크기 제한
              cacheHeight: ((128 / 852) * screenHeight * 2).toInt(),
              cacheWidth: ((349 / 393) * screenWidth * 2).toInt(),
            ),
            SizedBox(height: (201 / 852) * screenHeight),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/auth');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff323232),
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
              onPressed: () async {
                // ✅ 로그인 기록 체크 후 분기 처리
                await _handleLoginButtonPress();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff323232),
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
