import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_swift_camera/firebase_options.dart';
import 'package:flutter_swift_camera/view/about_arcaving/archiving_screen.dart';
import 'package:flutter_swift_camera/view/about_arcaving/all_category_screen.dart';
import 'package:flutter_swift_camera/view/about_arcaving/my_record_screen.dart';
import 'package:flutter_swift_camera/view/about_arcaving/share_record_screen.dart';
import 'package:flutter_swift_camera/view/about_camera/camera_screen.dart';
import 'package:flutter_swift_camera/view/about_category/category_add_screen.dart';
import 'package:flutter_swift_camera/view/about_category/category_select_screen.dart';
import 'package:flutter_swift_camera/view/home_navigator_screen.dart';
import 'package:flutter_swift_camera/view/home_screen.dart';
import 'package:provider/provider.dart';
import 'view/about_login/start_screen.dart';
import 'view_model/auth_view_model.dart';
import 'view_model/category_view_model.dart';
import 'view_model/audio_view_model.dart';
import 'view_model/comment_view_model.dart';
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
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => CategoryViewModel()),
        ChangeNotifierProvider(create: (_) => AudioViewModel()),
        ChangeNotifierProvider(create: (_) => CommentAudioViewModel()),
      ],
      child: MaterialApp(
        initialRoute: '/',

        routes: {
          '/': (context) => const StartScreen(),
          '/home': (context) => const HomeScreen(),
          '/home_navigation_screen': (context) => const HomePageNavigationBar(),
          '/camera': (context) => const CameraScreen(),
          '/archiving': (context) => const ArchivingScreen(),
          '/start': (context) => const StartScreen(),

          // 카테고리 관련 라우트
          '/category_select': (context) => const CategorySelectScreen(),

          '/category_add_screen': (context) => const CategoryAddScreen(),

          // 아카이빙 관련 라우트
          '/share_record': (context) => const ShareRecordScreen(),
          '/my_record': (context) => const MyRecordScreen(),
          '/all_category': (context) => const AllCategoryScreen(),
        },
        theme: ThemeData(iconTheme: IconThemeData(color: Colors.white)),
      ),
    );
  }
}
