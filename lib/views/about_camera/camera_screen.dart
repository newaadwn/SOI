import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/camera_service.dart';
import '../../theme/theme.dart';
import 'photo_editor_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
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

  // 기본 밝기 값
  double brightnessValue = 0.5;

  // 카메라 초기화 Future 추가
  Future<void>? _cameraInitialization;
  bool _isInitialized = false;

  // 카메라 로딩 중 상태
  bool _isLoading = true;

  // ✅ 추가: 초기화 시 카메라 세션 시작
  @override
  void initState() {
    super.initState();

    // 앱 라이프사이클 옵저버 등록
    WidgetsBinding.instance.addObserver(this);

    // 카메라 초기화 시작
    _cameraInitialization = _initCamera()
        .then((_) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isInitialized = true;
            });
          }
        })
        .catchError((error) {
          debugPrint('카메라 초기화 오류: $error');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
  }

  @override
  void dispose() {
    // 앱 라이프사이클 옵저버 해제
    WidgetsBinding.instance.removeObserver(this);

    // 카메라 리소스 정리
    _cameraService.deactivateSession();
    super.dispose();
  }

  // 앱 라이프사이클 상태 변화 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화될 때 카메라 세션 복구
    if (state == AppLifecycleState.resumed) {
      if (_isInitialized) {
        _cameraService.resumeCamera();
      }
    }
    // 앱이 비활성화될 때 카메라 리소스 정리
    else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraService.pauseCamera();
    }
  }

  // ✅ 추가: 카메라 초기화 메서드 - 비동기 작업을 명확하게 처리
  Future<void> _initCamera() async {
    try {
      // 카메라 초기화 요청
      await _cameraService.globalInitialize();
      debugPrint('카메라 초기화 완료');
      return;
    } on PlatformException catch (e) {
      debugPrint("카메라 초기화 오류: ${e.message}");
      // 오류 발생 시 다시 시도
      if (e.code != 'TIMEOUT') {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          await _cameraService.globalInitialize();
          debugPrint('카메라 초기화 재시도 성공');
          return;
        } catch (retryError) {
          debugPrint('카메라 초기화 재시도 실패: $retryError');
          rethrow; // 재시도 실패 시 오류 전달
        }
      }
      rethrow; // 오류를 상위로 전달하여 UI에서 적절히 처리
    } catch (e) {
      debugPrint("카메라 초기화 중 예상치 못한 오류: $e");
      rethrow;
    }
  }

  // 플래시 토글 요청
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

  // 사진 촬영 요청
  Future<void> _takePicture() async {
    try {
      final String result = await _cameraService.takePicture();
      setState(() {
        imagePath = result;
      });

      // 사진 촬영 후 처리
      if (result.isNotEmpty) {
        // 로컬 파일 경로만 사용하여 편집 화면으로 이동 (Firebase 사용 안 함)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoEditorScreen(imagePath: result),
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Error taking picture: ${e.message}");
    } catch (e) {
      // 추가 예외 처리
      debugPrint("Unexpected error: $e");
    }
  }

  // 카메라 전환 요청
  Future<void> _switchCamera() async {
    try {
      await _cameraService.switchCamera();
    } on PlatformException catch (e) {
      debugPrint("Error switching camera: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black, // 배경을 검정색으로 설정
      extendBodyBehindAppBar: true, // AppBar 뒤로 본문 확장
      appBar: AppBar(
        title: Text(
          'SOI',
          style: TextStyle(color: AppTheme.lightTheme.colorScheme.secondary),
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        toolbarHeight: 70 / 852 * screenHeight,
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 100 / 852 * screenHeight),

            // 카메라 초기화 상태에 따라 로딩 표시 또는 카메라 뷰 표시
            FutureBuilder<void>(
              future: _cameraInitialization,
              builder: (context, snapshot) {
                // 카메라 초기화 중이면 로딩 인디케이터 표시
                if (_isLoading) {
                  return Container(
                    width: 355 / 393 * screenWidth,
                    height: 472 / 852 * screenHeight,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
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
                    width: 355 / 393 * screenWidth,
                    height: 472 / 852 * screenHeight,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        '카메라를 초기화할 수 없습니다.\n앱을 다시 시작해 주세요.',
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // 카메라 초기화 완료되면 카메라 뷰 표시
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 355 / 393 * screenWidth,
                    height: 472 / 852 * screenHeight,
                    child: _cameraService.getCameraView(),
                  ),
                );
              },
            ),
            SizedBox(height: 44 / 852 * screenHeight),

            // ✅ 수정: 하단 버튼 레이아웃 변경
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 플래시 버튼
                SizedBox(
                  width: 50,
                  height: 50,
                  child: IconButton(
                    onPressed: _toggleFlash,
                    icon: Icon(
                      isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 28,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),

                // 촬영 버튼
                GestureDetector(
                  onTap: _takePicture,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 5),
                    ),
                    child: Center(
                      child: Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // 카메라 전환 버튼
                SizedBox(
                  width: 56 / 393 * screenWidth,
                  height: 47 / 852 * screenHeight,
                  child: IconButton(
                    onPressed: _switchCamera,
                    icon: Image.asset("assets/switch.png"),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
