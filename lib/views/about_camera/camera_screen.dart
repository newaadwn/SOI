import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/camera_service.dart';
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

  // 추가: 카메라 관련 상태 변수
  // 촬영된 이미지 경로
  String imagePath = '';

  // 플래시 상태 추적
  bool isFlashOn = false;

  // 추가: 줌 레벨 관리
  // 기본 줌 레벨
  String currentZoom = '1x';

  // 카메라 초기화 Future 추가
  Future<void>? _cameraInitialization;
  bool _isInitialized = false;

  // 카메라 로딩 중 상태
  bool _isLoading = true;

  // 갤러리 미리보기 상태 관리
  AssetEntity? _firstGalleryImage;
  bool _isLoadingGallery = false;
  String? _galleryError;

  // IndexedStack에서 상태 유지
  @override
  bool get wantKeepAlive => true;

  // 개선: 지연 초기화로 성능 향상
  @override
  void initState() {
    super.initState();

    // 앱 라이프사이클 옵저버 등록
    WidgetsBinding.instance.addObserver(this);

    // 카메라 초기화를 지연시킴 (첫 빌드에서 UI 블로킹 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCameraAsync();
    });
  }

  // 화면이 다시 표시될 때 호출되는 메서드 추가
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 화면 재진입 시 강제 전체 재초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceReinitializeCamera(); // 새 메서드
    });
  }

  // 비동기 카메라 초기화
  Future<void> _initializeCameraAsync() async {
    if (!_isInitialized && mounted) {
      try {
        // Starting camera initialization process

        // 병렬 처리로 성능 향상
        await Future.wait([
          _cameraService.activateSession(),
          _loadFirstGalleryImage(), // 개선된 갤러리 미리보기 로드
        ]);

        if (mounted) {
          setState(() {
            _isLoading = false;
            _isInitialized = true;
          });
          // Camera and gallery initialization completed successfully
        }
      } catch (e) {
        // Camera initialization failed with error: $e
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // 개선된 갤러리 첫 번째 이미지 로딩
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
      // Gallery image loading failed with error: $e
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
    // Starting CameraScreen disposal process

    // 앱 라이프사이클 옵저버 해제
    WidgetsBinding.instance.removeObserver(this);

    // IndexedStack 사용 시 카메라 세션 유지
    // dispose는 호출되지만 세션은 유지
    // IndexedStack environment - maintaining camera session

    super.dispose();
    // CameraScreen disposal completed
  }

  // 앱 라이프사이클 상태 변화 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화될 때 카메라 세션 복구
    if (state == AppLifecycleState.resumed) {
      if (_isInitialized) {
        _cameraService.resumeCamera();

        // 갤러리 미리보기 새로고침 (다른 앱에서 사진을 찍었을 수 있음)
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
    } on PlatformException {
      // Flash toggle error occurred: ${e.message}
    }
  }

  // cameraservice에 사진 촬영 요청
  Future<void> _takePicture() async {
    try {
      // iOS에서 오디오 세션 충돌 방지를 위한 사전 처리
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        // iOS 플랫폼에서만 실행 - 잠시 대기하여 오디오 세션 정리
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final String result = await _cameraService.takePicture();
      setState(() {
        imagePath = result;
      });

      // 사진 촬영 후 처리
      if (result.isNotEmpty && mounted) {
        // 즉시 편집 화면으로 이동 (갤러리 새로고침과 독립적)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoEditorScreen(imagePath: result),
          ),
        );
        // 사진 촬영 후 갤러리 미리보기 새로고침 (백그라운드에서)
        Future.microtask(() => _loadFirstGalleryImage());
      }
    } on PlatformException catch (e) {
      // Picture taking error occurred: ${e.message}

      // iOS에서 "Cannot Record" 오류가 발생한 경우 추가 정보 제공
      if (e.message?.contains("Cannot Record") == true) {
        // iOS audio session conflict detected - possible audio recording in progress
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('카메라 촬영 중 오류가 발생했습니다. 오디오 녹음을 중지하고 다시 시도해주세요.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // 추가 예외 처리
      // Unexpected error occurred during picture taking: $e
    }
  }

  /// 갤러리 콘텐츠 빌드 (로딩/에러/이미지 상태 처리)
  Widget _buildGalleryContent(double gallerySize, double borderRadius) {
    // 로딩 중
    if (_isLoadingGallery) {
      return Center(
        child: SizedBox(
          width: 46.w,
          height: 46.h,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    // 에러 상태
    if (_galleryError != null) {
      return _buildPlaceholderGallery(46);
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
                width: 46.w,
                height: 46.h,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Gallery thumbnail memory load error: $error
                  return _buildPlaceholderGallery(gallerySize);
                },
              );
            } else if (snapshot.hasError) {
              // Gallery thumbnail data load error: ${snapshot.error}
              return _buildPlaceholderGallery(gallerySize);
            } else {
              return Center(
                child: SizedBox(
                  width: 46.w,
                  height: 46.h,
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

  /// 갤러리 플레이스홀더 위젯 - 반응형
  Widget _buildPlaceholderGallery(double gallerySize) {
    return Center(
      child: Icon(
        Icons.photo_library,
        color: Colors.white.withValues(alpha: 0.7),
        size: 46.sp, // 24/46 비율
      ),
    );
  }

  // cameraservice에 카메라 전환 요청
  Future<void> _switchCamera() async {
    try {
      await _cameraService.switchCamera();
    } on PlatformException {
      // Camera switching error occurred: ${e.message}
    }
  }

  @override
  Widget build(BuildContext context) {
    // AutomaticKeepAliveClientMixin 필수 호출
    super.build(context);

    return Scaffold(
      backgroundColor: Color(0xff000000), // 배경을 검정색으로 설정

      appBar: AppBar(
        leadingWidth: 80.w, // leading 영역 크기 확장
        title: Column(
          children: [
            Text(
              'SOI',
              style: TextStyle(
                color: Color(0xfff9f9f9),
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 30.h),
          ],
        ),
        backgroundColor: Colors.black,
        toolbarHeight: 70.h,
        leading: Row(
          children: [
            SizedBox(width: 32.w),
            IconButton(
              constraints: BoxConstraints(),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pushNamed(context, '/contact_manager'),
              icon: Container(
                width: 35.w,
                height: 35.h,
                decoration: BoxDecoration(
                  color: Color(0xff1c1c1c),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.people, color: Colors.white, size: 25.sp),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 32.w),
            child: IconButton(
              onPressed: () {},
              icon: Container(
                width: 35.w,
                height: 35.h,
                decoration: BoxDecoration(
                  color: Color(0xff1c1c1c), // 아이콘 배경색
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications,
                  color: Colors.white,
                  size: 25.sp,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 📱 카메라 영역을 Expanded로 감싸서 오버플로우 방지
          Center(
            child: FutureBuilder<void>(
              future: _cameraInitialization,
              builder: (contezxt, snapshot) {
                // 카메라 초기화 중이면 로딩 인디케이터 표시
                if (_isLoading) {
                  return Container(
                    width: 400.w,
                    constraints: BoxConstraints(
                      maxHeight: double.infinity, // 📱 유연한 높이
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
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
                    constraints: BoxConstraints(
                      maxHeight: double.infinity, // 📱 유연한 높이
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        '카메라를 초기화할 수 없습니다.\n앱을 다시 시작해 주세요.',
                        style: TextStyle(color: Colors.white, fontSize: 18.sp),
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
                      borderRadius: BorderRadius.circular(16), // 📱 반응형
                      child: Container(
                        width: 354.w, // 📱 반응형
                        height: 500.h, // 📱 반응형
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1.0),
                        ),
                        child: _cameraService.getCameraView(),
                      ),
                    ),

                    // 플래시 버튼
                    IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(
                        isFlashOn ? EvaIcons.flash : EvaIcons.flashOff,
                        color: Colors.white,
                        size: 28.sp, // 📱 반응형
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 20.h), // 📱 반응형
          // 수정: 하단 버튼 레이아웃 변경 - 반응형
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 갤러리 미리보기 버튼 (Service 상태 사용) - 반응형
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: InkWell(
                    onTap: () async {
                      try {
                        // Service를 통해 갤러리에서 이미지 선택 (에러 핸들링 개선)
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
                          // No image was selected from gallery
                        }
                      } catch (e) {
                        // Error occurred while selecting image from gallery: $e
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
                    child: Container(
                      width: 46.w,
                      height: 46.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.76),
                      ),
                      child: _buildGalleryContent(46, 8.76),
                    ), // 📱 반응형
                  ),
                ),
              ),

              // 촬영 버튼 - 개선된 반응형
              IconButton(
                onPressed: _takePicture,
                icon: Image.asset(
                  "assets/take_picture.png",
                  width: 65.w,
                  height: 65.h,
                ),
              ),

              // 카메라 전환 버튼 - 개선된 반응형
              Expanded(
                child: IconButton(
                  onPressed: _switchCamera,
                  color: Color(0xffd9d9d9),
                  icon: Image.asset(
                    "assets/switch.png",
                    width: 67.w,
                    height: 56.h,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 30.h),
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
