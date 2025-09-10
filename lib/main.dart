import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'controllers/comment_record_controller.dart';
import 'controllers/contact_controller.dart';
import 'controllers/photo_controller.dart';
import 'controllers/friend_request_controller.dart';
import 'controllers/friend_controller.dart';
import 'controllers/user_matching_controller.dart';
import 'controllers/emoji_reaction_controller.dart';
import 'services/friend_request_service.dart';
import 'services/friend_service.dart';
import 'services/user_matching_service.dart';
import 'services/notification_service.dart';
import 'repositories/friend_request_repository.dart';
import 'repositories/friend_repository.dart';
import 'repositories/user_search_repository.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'views/about_archiving/screens/archive_detail/all_archives_screen.dart';
import 'views/about_archiving/screens/archive_detail/my_archives_screen.dart';
import 'views/about_archiving/screens/archive_detail/shared_archives_screen.dart';
import 'views/about_archiving/screens/archive_main_screen.dart';
import 'views/about_camera/camera_screen.dart';
import 'views/about_feed/feed_home.dart';
import 'views/about_friends/friend_list_add_screen.dart';
import 'views/about_friends/friend_list_screen.dart';
import 'views/about_friends/friend_request_screen.dart';
import 'views/about_login/register_screen.dart';
import 'views/about_login/login_screen.dart';
import 'views/about_login/start_screen.dart';
import 'views/about_notification/notification_screen.dart';
import 'views/about_profile/profile_screen.dart';
import 'views/about_setting/privacy.dart';
import 'views/about_friends/friend_management_screen.dart';
import 'controllers/auth_controller.dart';
import 'controllers/category_controller.dart';
import 'controllers/audio_controller.dart';
import 'controllers/comment_audio_controller.dart';
import 'controllers/notification_controller.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'views/home_navigator_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드
  await dotenv.load(fileName: ".env");

  // 날짜 포맷팅 초기화 (한국어 로케일)
  await initializeDateFormatting('ko_KR', null);

  // CachedNetworkImage 메모리 설정 (메모리 누수 방지)
  PaintingBinding.instance.imageCache.maximumSize = 100; // 최대 100개 이미지 캐시
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      50 * 1024 * 1024; // 50MB 제한

  // 추가 메모리 최적화 설정
  if (!kDebugMode) {
    // Release 모드에서만 더 엄격한 설정 적용
    PaintingBinding.instance.imageCache.maximumSize = 50; // 더 적은 이미지 캐시
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        30 * 1024 * 1024; // 30MB 제한
  }

  if (kDebugMode) {
    // 메모리 사용량 주기적 출력 (개발 중에만)
    Timer.periodic(Duration(seconds: 30), (timer) {
      final cache = PaintingBinding.instance.imageCache;
      debugPrint(
        '🖼️ Image Cache: ${cache.currentSize}/${cache.maximumSize} '
        'images, ${(cache.currentSizeBytes / 1024 / 1024).toStringAsFixed(1)}MB',
      );
    });
  }

  // Firebase 초기화 (더 안전한 방법)
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;

    // Firebase Auth 설정 (Firebase가 성공적으로 초기화된 경우에만)
    try {
      FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: false,
        forceRecaptchaFlow: false,
      );
    } catch (authError) {
      rethrow;
    }
  } catch (e) {
    rethrow;
  }

  // Supabase 설정: .env 파일에서 환경 변수 로드
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint('supabse url과 supabase Anon key가 없습니다.');
  } else {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    debugPrint('[Supabase][Init] ✅ Initialized successfully');
  }

  // 에러 핸들링 추가
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // 플랫폼 에러 핸들링 (예: 비동기 코드의 에러)
  PlatformDispatcher.instance.onError = (error, stack) {
    // Firebase Auth reCAPTCHA 에러 무시 (사용자에게 영향 없음)
    if (error.toString().contains('reCAPTCHA') ||
        error.toString().contains('web-internal-error')) {
      return true;
    }

    return true;
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
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();

    // 앱 시작시 백그라운드 알림 시스템 정리 수행
    if (widget.firebaseInitialized) {
      _performSystemMaintenanceOnStart();
      _startPeriodicCleanup();
    }
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  /// 앱 시작시 시스템 유지보수 작업 수행
  void _performSystemMaintenanceOnStart() {
    // 앱 시작 후 몇 초 후에 백그라운드에서 시스템 정리 수행
    Future.delayed(const Duration(seconds: 5), () {
      try {
        NotificationService().performSystemCleanup().catchError((e) {
          debugPrint('❌ 시스템 시작시 알림 정리 실패: $e');
          // 사용자 경험에 영향을 주지 않도록 에러를 무시
        });
      } catch (e) {
        debugPrint('❌ 시스템 정리 작업 초기화 실패: $e');
      }
    });
  }

  /// 정기적인 알림 정리 작업 시작 (24시간마다)
  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(hours: 24), (timer) {
      try {
        NotificationService().performSystemCleanup().catchError((e) {
          debugPrint('❌ 정기 알림 정리 실패: $e');
        });
      } catch (e) {
        debugPrint('❌ 정기 정리 작업 실행 실패: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Firebase가 초기화되지 않았으면 로딩 화면 표시
    if (!widget.firebaseInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => CategoryController()),
        ChangeNotifierProvider(create: (_) => AudioController()),
        ChangeNotifierProvider(create: (_) => CommentAudioController()),
        ChangeNotifierProvider(create: (_) => CommentRecordController()),
        ChangeNotifierProvider(create: (_) => PhotoController()),
        ChangeNotifierProvider(create: (_) => ContactController()),
        ChangeNotifierProvider(create: (_) => EmojiReactionController()),

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

        // 알림 관리 컨트롤러
        ChangeNotifierProvider(create: (_) => NotificationController()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          initialRoute: '/',
          debugShowCheckedModeBanner: false,
          routes: {
            '/': (context) => const StartScreen(),

            '/home_navigation_screen':
                (context) => HomePageNavigationBar(currentPageIndex: 1),
            '/camera': (context) => const CameraScreen(),
            '/archiving': (context) => const ArchiveMainScreen(),
            '/start': (context) => const StartScreen(),
            '/auth': (context) => AuthScreen(),
            '/login': (context) => const LoginScreen(),

            // 아카이빙 관련 라우트
            '/share_record': (context) => const SharedArchivesScreen(),
            '/my_record': (context) => const MyArchivesScreen(),
            '/all_category': (context) => const AllArchivesScreen(),
            '/privacy_policy': (context) => const PrivacyPolicyScreen(),

            // 친구 관리 라우트
            '/contact_manager': (context) => const FriendManagementScreen(),
            '/friend_list_add': (context) => const FriendListAddScreen(),
            '/friend_list': (context) => const FriendListScreen(),
            '/friend_requests': (context) => const FriendRequestScreen(),

            // 피드 홈 라우트
            '/feed_home': (context) => const FeedHomeScreen(),

            // 프로필 페이지 라우트
            '/profile_screen': (context) => const ProfileScreen(),

            // 알림 페이지 라우트
            '/notifications': (context) => const NotificationScreen(),
          },
          theme: ThemeData(iconTheme: IconThemeData(color: Colors.white)),
        ),
      ),
    );
  }
}
