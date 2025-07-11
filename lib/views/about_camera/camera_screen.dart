import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/camera_service.dart';
//import '../../theme/theme.dart';
import 'photo_editor_screen.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

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

    _cameraService.activateSession();
    setState(() {
      _isLoading = false;
      _isInitialized = true;
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
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Color(0xff000000), // 배경을 검정색으로 설정

      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/contact_manager'),
              icon: Image.asset("assets/contacts.png", width: 35, height: 35),
            ),

            Expanded(
              child: Center(
                child: Text(
                  'SOI',
                  style: TextStyle(
                    color: Color(0xfff8f8f8),
                    fontSize: 20,
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          //SizedBox(height: 20 / 852 * screenHeight),

          // 카메라 초기화 상태에 따라 로딩 표시 또는 카메라 뷰 표시
          FutureBuilder<void>(
            future: _cameraInitialization,
            builder: (context, snapshot) {
              // 카메라 초기화 중이면 로딩 인디케이터 표시
              if (_isLoading) {
                return Container(
                  width: 355,
                  height: 472,
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
                  width: 355,
                  height: 472,
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
              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 354 / 393 * screenWidth,
                      height: 500 / 852 * screenHeight,
                      child: _cameraService.getCameraView(),
                    ),
                  ),

                  // 플래시 버튼
                  IconButton(
                    onPressed: _toggleFlash,
                    icon: Icon(
                      isFlashOn ? EvaIcons.flash : EvaIcons.flashOff,
                      color: Colors.white,
                      size: 28,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 24 / 852 * screenHeight),

          // ✅ 수정: 하단 버튼 레이아웃 변경
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 갤러리 버튼
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: InkWell(
                    onTap: () {
                      _cameraService.pickImageFromGallery().then((result) {
                        if (result != null && result.isNotEmpty) {
                          // 선택한 이미지 경로를 편집 화면으로 전달
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      PhotoEditorScreen(imagePath: result),
                            ),
                          );
                        }
                      });
                    },
                    child: FutureBuilder(
                      future: _cameraService.pickFirstImageFromGallery(),
                      builder: (context, snapshot) {
                        debugPrint("snapshot: ${snapshot.data}");
                        return (snapshot.hasData)
                            ? Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(8.76),

                                image: DecorationImage(
                                  image: FileImage(File(snapshot.data!)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                            : Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(8.76),
                                color: Colors.white,
                              ),
                            );
                      },
                    ),
                  ),
                ),
              ),

              // 촬영 버튼
              IconButton(
                onPressed: _takePicture,
                icon: Image.asset(
                  "assets/take_picture.png",
                  width: 65,
                  height: 65,
                ),
              ),

              // 카메라 전환 버튼
              Expanded(
                child: SizedBox(
                  height: 90 / 852 * screenHeight,
                  child: IconButton(
                    onPressed: _switchCamera,
                    color: Color(0xffd9d9d9),
                    icon: Image.asset("assets/switch.png"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
