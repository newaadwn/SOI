import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_swift_camera/firebase_options.dart';
import 'package:flutter_swift_camera/views/about_archiving/archive_main_screen.dart';
import 'package:flutter_swift_camera/views/about_archiving/all_archives_screen.dart';
import 'package:flutter_swift_camera/views/about_archiving/personal_archives_screen.dart';
import 'package:flutter_swift_camera/views/about_archiving/shared_archives_screen.dart';
import 'package:flutter_swift_camera/views/about_camera/camera_screen.dart';
import 'package:flutter_swift_camera/views/about_category/category_add_screen.dart';
import 'package:flutter_swift_camera/views/about_category/category_select_screen.dart';
import 'package:flutter_swift_camera/views/home_navigator_screen.dart';
import 'package:flutter_swift_camera/views/home_screen.dart';
import 'package:provider/provider.dart';
import 'views/about_contacts/addContacts.dart';
import 'views/about_login/register_screen.dart';
import 'views/about_login/login_screen.dart';
import 'views/about_login/start_screen.dart';
import 'views/about_setting/privacy.dart';
import 'controllers/auth_controller.dart';
import 'controllers/category_controller.dart';
import 'controllers/audio_controller.dart';
import 'controllers/comment_controller.dart';
import 'controllers/contacts_controller.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui'; // PlatformDispatcher를 위해 필요

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return true; // 에러를 처리했음을 표시
  };

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

        ChangeNotifierProvider(create: (_) => ContactsController()),
      ],
      child: MaterialApp(
        initialRoute: '/',
        debugShowCheckedModeBanner: false,
        routes: {
          '/': (context) => const StartScreen(),
          '/home': (context) => const HomeScreen(),
          '/home_navigation_screen':
              (context) => HomePageNavigationBar(currentPageIndex: 0),
          '/camera': (context) => const CameraScreen(),
          '/archiving': (context) => const ArchiveMainScreen(),
          '/start': (context) => const StartScreen(),
          '/auth': (context) => const AuthScreen(),
          '/login': (context) => const LoginScreen(),

          // 카테고리 관련 라우트
          '/category_select': (context) => const CategorySelectScreen(),
          '/category_add_screen': (context) => const CategoryAddScreen(),

          // 아카이빙 관련 라우트
          '/share_record': (context) => const SharedArchivesScreen(),
          '/my_record': (context) => const PersonalArchivesScreen(),
          '/all_category': (context) => const AllArchivesScreen(),

          '/privacy_policy': (context) => const PrivacyPolicyScreen(),

          '/add_contacts': (context) => const AddcontactsPage(),
        },
        theme: ThemeData(iconTheme: IconThemeData(color: Colors.white)),
      ),
    );
  }
}
