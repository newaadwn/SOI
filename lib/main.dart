import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'controllers/contact_controller.dart';
import 'controllers/photo_controller.dart';
import 'controllers/friend_request_controller.dart';
import 'controllers/friend_controller.dart';
import 'controllers/user_matching_controller.dart';
import 'services/friend_request_service.dart';
import 'services/friend_service.dart';
import 'services/user_matching_service.dart';
import 'repositories/friend_request_repository.dart';
import 'repositories/friend_repository.dart';
import 'repositories/user_search_repository.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'views/about_archiving/all_archives_screen.dart';
import 'views/about_archiving/archive_main_screen.dart';
import 'views/about_archiving/my_archives_screen.dart';
import 'views/about_archiving/shared_archives_screen.dart';
import 'views/about_camera/camera_screen.dart';
import 'views/about_feed/feed_home.dart';
import 'views/about_login/register_screen.dart';
import 'views/about_login/login_screen.dart';
import 'views/about_login/start_screen.dart';
import 'views/about_setting/privacy.dart';
import 'views/about_friends/friend_management_screen.dart';
import 'controllers/auth_controller.dart';
import 'controllers/category_controller.dart';
import 'controllers/audio_controller.dart';
import 'controllers/comment_controller.dart';

import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'package:intl/date_symbol_data_local.dart'; // 1. 이 줄을 추가하세요.
import 'views/home_navigator_screen.dart';
import 'views/home_screen.dart'; // PlatformDispatcher를 위해 필요

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 날짜 포맷팅 초기화 (한국어 로케일)
  await initializeDateFormatting('ko_KR', null);

  // Firebase 초기화 (더 안전한 방법)
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
    debugPrint('✅ Firebase 초기화 성공');

    // Firebase Auth 설정 (Firebase가 성공적으로 초기화된 경우에만)
    try {
      FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: false,
        forceRecaptchaFlow: false,
      );
      debugPrint('✅ Firebase Auth 설정 완료');
    } catch (authError) {
      debugPrint('⚠️ Firebase Auth 설정 실패: $authError');
    }
  } catch (e) {
    debugPrint('❌ Firebase 초기화 실패: $e');
    debugPrint('📱 앱은 Firebase 없이 계속 실행됩니다');
    // Firebase 없이도 앱이 실행되도록 처리
  }

  // 🔥 Firebase Emulator 연결 설정 (개발 환경에서만)
  //_connectToFirebaseEmulator();

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

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

class MyApp extends StatefulWidget {
  final bool firebaseInitialized;

  const MyApp({super.key, required this.firebaseInitialized});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Deep Link 초기화는 첫 번째 화면에서 처리
  }

  @override
  Widget build(BuildContext context) {
    // Firebase가 초기화되지 않았으면 로딩 화면 표시
    if (!widget.firebaseInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('앱을 준비하고 있습니다...'),
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => CategoryController()),
        ChangeNotifierProvider(create: (_) => AudioController()),
        ChangeNotifierProvider(create: (_) => CommentController()),
        ChangeNotifierProvider(create: (_) => PhotoController()),
        ChangeNotifierProvider(create: (_) => ContactController()),

        // 친구 관리 관련 컨트롤러들
        ChangeNotifierProvider(
          create:
              (_) => FriendRequestController(
                friendRequestService: FriendRequestService(
                  friendRequestRepository: FriendRequestRepository(),
                  friendRepository: FriendRepository(),
                  userSearchRepository: UserSearchRepository(),
                ),
              ),
        ),
        ChangeNotifierProvider(
          create:
              (_) => FriendController(
                friendService: FriendService(
                  friendRepository: FriendRepository(),
                  userSearchRepository: UserSearchRepository(),
                ),
              ),
        ),
        ChangeNotifierProvider(
          create:
              (_) => UserMatchingController(
                userMatchingService: UserMatchingService(
                  userSearchRepository: UserSearchRepository(),
                  friendRepository: FriendRepository(),
                  friendRequestRepository: FriendRequestRepository(),
                ),
                friendRequestService: FriendRequestService(
                  friendRequestRepository: FriendRequestRepository(),
                  friendRepository: FriendRepository(),
                  userSearchRepository: UserSearchRepository(),
                ),
                userSearchRepository: UserSearchRepository(),
              ),
        ),
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

          // 친구 관리 라우트
          '/contact_manager': (context) => const FriendManagementScreen(),

          '/feed_home': (context) => const FeedHomeScreen(),
        },
        theme: ThemeData(iconTheme: IconThemeData(color: Colors.white)),
      ),
    );
  }
}
