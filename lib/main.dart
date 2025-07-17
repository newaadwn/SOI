import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'controllers/contact_controller.dart';
import 'controllers/photo_controller.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'views/about_archiving/all_archives_screen.dart';
import 'views/about_archiving/archive_main_screen.dart';
import 'views/about_archiving/my_archives_screen.dart';
import 'views/about_archiving/shared_archives_screen.dart';
import 'views/about_camera/camera_screen.dart';
import 'views/about_contacts/contact_manager_screen.dart';
import 'views/about_login/register_screen.dart';
import 'views/about_login/login_screen.dart';
import 'views/about_login/start_screen.dart';
import 'views/about_setting/privacy.dart';
import 'controllers/auth_controller.dart';
import 'controllers/category_controller.dart';
import 'controllers/audio_controller.dart';
import 'controllers/comment_controller.dart';
import 'controllers/friend_request_controller.dart';

import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'package:intl/date_symbol_data_local.dart'; // 1. 이 줄을 추가하세요.
import 'views/home_navigator_screen.dart';
import 'views/home_screen.dart'; // PlatformDispatcher를 위해 필요

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 날짜 포맷팅 초기화 (한국어 로케일)
  await initializeDateFormatting('ko_KR', null);

  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firebase Auth 설정 (iOS에서 reCAPTCHA 관련 문제 해결)
  FirebaseAuth.instance.setSettings(
    appVerificationDisabledForTesting: false,
    forceRecaptchaFlow: false,
  );

  // 에러 핸들링 추가
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // 플랫폼 에러 핸들링 (예: 비동기 코드의 에러)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher Error: $error');
    debugPrint('Stack trace: $stack');

    // Firebase Auth reCAPTCHA 에러 무시 (사용자에게 영향 없음)
    if (error.toString().contains('reCAPTCHA') ||
        error.toString().contains('web-internal-error')) {
      debugPrint('Firebase Auth reCAPTCHA 에러 무시됨');
      return true;
    }

    return true; // 에러를 처리했음을 표시
  };

  debugPaintSizeEnabled = false;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => CategoryController()),
        ChangeNotifierProvider(create: (_) => AudioController()),
        ChangeNotifierProvider(create: (_) => CommentController()),
        ChangeNotifierProvider(create: (_) => ContactController()),
        ChangeNotifierProvider(create: (_) => PhotoController()),
        ChangeNotifierProvider(create: (_) => FriendRequestController()),
      ],
      child: MaterialApp(
        initialRoute: '/',
        debugShowCheckedModeBanner: false,
        routes: {
          '/': (context) => const StartScreen(),
          '/home': (context) => const HomeScreen(),
          '/home_navigation_screen':
              (context) => HomePageNavigationBar(currentPageIndex: 1),
          '/camera': (context) => const CameraScreen(),
          '/archiving': (context) => const ArchiveMainScreen(),
          '/start': (context) => const StartScreen(),
          '/auth': (context) => const AuthScreen(),
          '/login': (context) => const LoginScreen(),

          // 아카이빙 관련 라우트
          '/share_record': (context) => const SharedArchivesScreen(),
          '/my_record': (context) => const MyArchivesScreen(),
          '/all_category': (context) => const AllArchivesScreen(),
          '/privacy_policy': (context) => const PrivacyPolicyScreen(),
          '/contact_manager': (context) => const ContactManagerScreen(),
        },
        theme: ThemeData(iconTheme: IconThemeData(color: Colors.white)),
      ),
    );
  }
}
