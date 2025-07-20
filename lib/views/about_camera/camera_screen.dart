import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/camera_service.dart';
//import '../../theme/theme.dart';
import 'photo_editor_screen.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:photo_manager/photo_manager.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  // Swift와 통신할 플랫폼 채널
  final CameraService _cameraService = CameraService();

  // ✅ 추가: 카메라 관련 상태 변수
  // 촬영된 이미지 경로
  String imagePath = '';

  // 플래시 상태 추적
  bool isFlashOn = false;

  // ✅ 추가: 줌 레벨 관리
  // 기본 줌 레벨
  String currentZoom = '1x';

  // 카메라 초기화 Future 추가
  Future<void>? _cameraInitialization;
  bool _isInitialized = false;

  // 카메라 로딩 중 상태
  bool _isLoading = true;

  // ✅ 갤러리 미리보기 상태 관리
  AssetEntity? _firstGalleryImage;
  bool _isLoadingGallery = false;
  String? _galleryError;

  // ✅ IndexedStack에서 상태 유지
  @override
  bool get wantKeepAlive => true;

  // ✅ 개선: 지연 초기화로 성능 향상
  @override
  void initState() {
    super.initState();

    // 앱 라이프사이클 옵저버 등록
    WidgetsBinding.instance.addObserver(this);

    // ✅ 카메라 초기화를 지연시킴 (첫 빌드에서 UI 블로킹 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCameraAsync();
    });
  }

  // ✅ 화면이 다시 표시될 때 호출되는 메서드 추가
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 화면 재진입 시 강제 전체 재초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceReinitializeCamera(); // 새 메서드
    });
  }

  // ✅ 비동기 카메라 초기화
  Future<void> _initializeCameraAsync() async {
    if (!_isInitialized && mounted) {
      try {
        debugPrint('카메라 초기화 시작...');

        // 병렬 처리로 성능 향상
        await Future.wait([
          _cameraService.activateSession(),
          _loadFirstGalleryImage(), // ✅ 개선된 갤러리 미리보기 로드
        ]);

        if (mounted) {
          setState(() {
            _isLoading = false;
            _isInitialized = true;
          });
          debugPrint('카메라 및 갤러리 초기화 완료');
        }
      } catch (e) {
        debugPrint('카메라 초기화 실패: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // ✅ 개선된 갤러리 첫 번째 이미지 로딩
  Future<void> _loadFirstGalleryImage() async {
    if (_isLoadingGallery) return;

    setState(() {
      _isLoadingGallery = true;
      _galleryError = null;
    });

    try {
      final AssetEntity? firstImage =
          await _cameraService.getFirstGalleryImage();

      if (mounted) {
        setState(() {
          _firstGalleryImage = firstImage;
          _isLoadingGallery = false;
        });
      }
    } catch (e) {
      debugPrint('갤러리 이미지 로딩 실패: $e');
      if (mounted) {
        setState(() {
          _galleryError = '갤러리 접근 실패';
          _isLoadingGallery = false;
        });
      }
    }
  }

  @override
  void dispose() {
    debugPrint('CameraScreen dispose 시작');

    // 앱 라이프사이클 옵저버 해제
    WidgetsBinding.instance.removeObserver(this);

    // ✅ IndexedStack 사용 시 카메라 세션 유지
    // dispose는 호출되지만 세션은 유지
    debugPrint('📹 IndexedStack 환경 - 카메라 세션 유지');

    super.dispose();
    debugPrint('CameraScreen dispose 완료');
  }

  // 앱 라이프사이클 상태 변화 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화될 때 카메라 세션 복구
    if (state == AppLifecycleState.resumed) {
      if (_isInitialized) {
        _cameraService.resumeCamera();

        // ✅ 갤러리 미리보기 새로고침 (다른 앱에서 사진을 찍었을 수 있음)
        _loadFirstGalleryImage();
      }
    }
    // 앱이 비활성화될 때 카메라 리소스 정리
    else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService.pauseCamera();
    }
  }

  // cameraservice에 플래시 토글 요청
  Future<void> _toggleFlash() async {
    try {
      final bool newFlashState = !isFlashOn;
      await _cameraService.setFlash(newFlashState);

      setState(() {
        isFlashOn = newFlashState;
      });
    } on PlatformException catch (e) {
      debugPrint("플래시 전환 오류: ${e.message}");
    }
  }

  // cameraservice에 사진 촬영 요청
  Future<void> _takePicture() async {
    try {
      final String result = await _cameraService.takePicture();
      setState(() {
        imagePath = result;
      });

      // 사진 촬영 후 처리
      if (result.isNotEmpty) {
        // ✅ 즉시 편집 화면으로 이동 (갤러리 새로고침과 독립적)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoEditorScreen(imagePath: result),
          ),
        );
        // ✅ 사진 촬영 후 갤러리 미리보기 새로고침 (백그라운드에서)
        Future.microtask(() => _loadFirstGalleryImage());
      }
    } on PlatformException catch (e) {
      debugPrint("Error taking picture: ${e.message}");
    } catch (e) {
      // 추가 예외 처리
      debugPrint("Unexpected error: $e");
    }
  }

  /// ✅ 개선된 갤러리 미리보기 위젯 (photo_manager 기반) - 반응형
  Widget _buildGalleryPreviewWidget(double screenWidth) {
    // 📱 반응형: 갤러리 미리보기 크기 (기준: 46/393)
    final gallerySize = 46 / 393 * screenWidth;
    final borderRadius = 8.76 / 393 * screenWidth;

    return Container(
      width: gallerySize,
      height: gallerySize,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: _buildGalleryContent(gallerySize, borderRadius),
    );
  }

  /// ✅ 갤러리 콘텐츠 빌드 (로딩/에러/이미지 상태 처리)
  Widget _buildGalleryContent(double gallerySize, double borderRadius) {
    // 로딩 중
    if (_isLoadingGallery) {
      return Center(
        child: SizedBox(
          width: gallerySize * 0.43, // 20/46 비율
          height: gallerySize * 0.43,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    // 에러 상태
    if (_galleryError != null) {
      return _buildPlaceholderGallery(gallerySize);
    }

    // 갤러리 이미지 표시
    if (_firstGalleryImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: FutureBuilder<Uint8List?>(
          future: _firstGalleryImage!.thumbnailData,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                width: gallerySize,
                height: gallerySize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('갤러리 썸네일 메모리 로드 오류: $error');
                  return _buildPlaceholderGallery(gallerySize);
                },
              );
            } else if (snapshot.hasError) {
              debugPrint('갤러리 썸네일 데이터 로드 오류: ${snapshot.error}');
              return _buildPlaceholderGallery(gallerySize);
            } else {
              return Center(
                child: SizedBox(
                  width: gallerySize * 0.3,
                  height: gallerySize * 0.3,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              );
            }
          },
        ),
      );
    }

    // 기본 플레이스홀더
    return _buildPlaceholderGallery(gallerySize);
  }

  /// ✅ 갤러리 플레이스홀더 위젯 - 반응형
  Widget _buildPlaceholderGallery(double gallerySize) {
    return Center(
      child: Icon(
        Icons.photo_library,
        color: Colors.white.withValues(alpha: 0.7),
        size: gallerySize * 0.52, // 24/46 비율
      ),
    );
  }

  // cameraservice에 카메라 전환 요청
  Future<void> _switchCamera() async {
    try {
      await _cameraService.switchCamera();
    } on PlatformException catch (e) {
      debugPrint("Error switching camera: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ AutomaticKeepAliveClientMixin 필수 호출
    super.build(context);

    // 📱 개선된 반응형: MediaQuery.sizeOf() 사용
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // 📱 반응형: 기준 해상도 설정 (393 x 852 기준)
    const double baseWidth = 393;
    const double baseHeight = 852;

    return Scaffold(
      backgroundColor: Color(0xff000000), // 배경을 검정색으로 설정

      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/contact_manager'),
              icon: Image.asset(
                "assets/contacts.png",
                width: (screenWidth * 0.089).clamp(30.0, 40.0), // 📱 개선된 반응형
                height: (screenWidth * 0.089).clamp(30.0, 40.0), // 📱 개선된 반응형
              ),
            ),

            Expanded(
              child: Center(
                child: Text(
                  'SOI',
                  style: TextStyle(
                    color: Color(0xfff8f8f8),
                    fontSize: (screenWidth * 0.051).clamp(16.0, 24.0), // 📱 개선된 반응형
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            IconButton(onPressed: () {}, icon: Text('')),
          ],
        ),

        backgroundColor: Color(0xff000000),
      ),
      body: Column(
        children: [
          // 📱 카메라 영역을 Expanded로 감싸서 오버플로우 방지
          Expanded(
            child: Center(
              child: FutureBuilder<void>(
                future: _cameraInitialization,
                builder: (context, snapshot) {
                  // 카메라 초기화 중이면 로딩 인디케이터 표시
                  if (_isLoading) {
                    return Container(
                      width: (screenWidth * 0.903).clamp(300.0, 400.0), // 📱 개선된 반응형
                      constraints: BoxConstraints(
                        maxHeight: double.infinity, // 📱 유연한 높이
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(
                          (screenWidth * 0.041).clamp(12.0, 20.0), // 📱 개선된 반응형
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  }

                  // 초기화 실패 시 오류 메시지 표시
                  if (snapshot.hasError) {
                    return Container(
                      width: (screenWidth * 0.903).clamp(300.0, 400.0), // 📱 개선된 반응형
                      constraints: BoxConstraints(
                        maxHeight: double.infinity, // 📱 유연한 높이
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(
                          (screenWidth * 0.041).clamp(12.0, 20.0), // 📱 개선된 반응형
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '카메라를 초기화할 수 없습니다.\n앱을 다시 시작해 주세요.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (screenWidth * 0.041).clamp(14.0, 18.0), // 📱 개선된 반응형
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  // 카메라 초기화 완료되면 카메라 뷰 표시
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          16 / baseWidth * screenWidth,
                        ), // 📱 반응형
                        child: SizedBox(
                          width: 354 / baseWidth * screenWidth, // 📱 반응형
                          height: 500 / baseHeight * screenHeight, // 📱 반응형
                          child: _cameraService.getCameraView(),
                        ),
                      ),

                      // 플래시 버튼
                      IconButton(
                        onPressed: _toggleFlash,
                        icon: Icon(
                          isFlashOn ? EvaIcons.flash : EvaIcons.flashOff,
                          color: Colors.white,
                          size: 28 / baseWidth * screenWidth, // 📱 반응형
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 20 / baseHeight * screenHeight), // 📱 반응형
          // ✅ 수정: 하단 버튼 레이아웃 변경 - 반응형
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ 갤러리 미리보기 버튼 (Service 상태 사용) - 반응형
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: InkWell(
                    onTap: () async {
                      try {
                        // ✅ Service를 통해 갤러리에서 이미지 선택 (에러 핸들링 개선)
                        final result =
                            await _cameraService.pickImageFromGallery();
                        if (result != null && result.isNotEmpty && mounted) {
                          // 선택한 이미지 경로를 편집 화면으로 전달
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      PhotoEditorScreen(imagePath: result),
                            ),
                          );
                        } else {
                          debugPrint('갤러리에서 이미지를 선택하지 않았습니다');
                        }
                      } catch (e) {
                        debugPrint('갤러리 이미지 선택 중 오류 발생: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('갤러리에서 이미지를 선택할 수 없습니다'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: _buildGalleryPreviewWidget(screenWidth), // 📱 반응형
                  ),
                ),
              ),

              // 촬영 버튼 - 반응형
              IconButton(
                onPressed: _takePicture,
                icon: Image.asset(
                  "assets/take_picture.png",
                  width: 65 / baseWidth * screenWidth, // 📱 반응형
                  height: 65 / baseWidth * screenWidth, // 📱 반응형 (정사각형 유지)
                ),
              ),

              // 카메라 전환 버튼 - 반응형
              Expanded(
                child: SizedBox(
                  child: IconButton(
                    onPressed: _switchCamera,
                    color: Color(0xffd9d9d9),
                    icon: Image.asset(
                      "assets/switch.png",
                      width: 67 / baseWidth * screenWidth, // 📱 반응형 (크기 명시)
                      height: 56 / baseWidth * screenWidth, // 📱 반응형 (정사각형 유지)
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24 / baseHeight * screenHeight),
        ],
      ),
    );
  }

  Future<void> _forceReinitializeCamera() async {
    setState(() {
      _isInitialized = false;
      _isLoading = true;
    });

    await _initializeCameraAsync(); // 완전한 재초기화
  }
}
