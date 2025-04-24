import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';

import '../../theme/theme.dart';
import 'photo_editor_screen.dart';
//import 'package:flutter_svg/flutter_svg.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Swift와 통신할 플랫폼 채널
  static const MethodChannel platform = MethodChannel('com.soi.camera');
  String imagePath = '';
  bool isFlashOn = false; // 플래시 상태 추적

  // ✅ 추가: 줌 레벨 관리
  String currentZoom = '1x'; // 기본 줌 레벨
  double brightnessValue = 0.5; // 기본 밝기 값

  // ✅ 추가: 초기화 시 카메라 세션 시작
  @override
  void initState() {
    super.initState();
    // 카메라 리소스 초기화
    _initCamera();
  }

  // ✅ 추가: 카메라 초기화 메서드
  Future<void> _initCamera() async {
    try {
      await platform.invokeMethod('initCamera');
    } on PlatformException catch (e) {
      debugPrint("Error initializing camera: ${e.message}");
    }
  }

  // 사진 촬영 요청
  Future<void> _takePicture() async {
    try {
      final String result = await platform.invokeMethod('takePicture');
      setState(() {
        imagePath = result;
      });

      // 사진 촬영 후 편집 화면으로 이동
      if (result.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoEditorScreen(imagePath: result),
          ),
        );
      }
      _uploadImage(File(result));
    } on PlatformException catch (e) {
      debugPrint("Error taking picture: ${e.message}");
    }
  }

  // 카메라 전환 요청
  Future<void> _switchCamera() async {
    try {
      await platform.invokeMethod('switchCamera');
    } on PlatformException catch (e) {
      debugPrint("Error switching camera: ${e.message}");
    }
  }

  // 플래시 토글 요청
  Future<void> _toggleFlash() async {
    try {
      await platform.invokeMethod('toggleFlash');
      setState(() {
        isFlashOn = !isFlashOn;
      });
    } on PlatformException catch (e) {
      debugPrint("Error toggling flash: ${e.message}");
    }
  }

  // ✅ 추가: 줌 레벨 설정 함수
  /*Future<void> _setZoomLevel(String zoom) async {
    double zoomFactor;
    switch (zoom) {
      case '.5':
        zoomFactor = 0.5;
        break;
      case '1x':
        zoomFactor = 1.0;
        break;
      case '3':
        zoomFactor = 3.0;
        break;
      default:
        zoomFactor = 1.0;
    }

    try {
      await platform.invokeMethod('setZoomLevel', {'zoom': zoomFactor});
      setState(() {
        currentZoom = zoom;
      });
    } on PlatformException catch (e) {
      debugPrint("Error setting zoom level: ${e.message}");
    }
  }*/

  // 촬영한 이미지 Firebase Storage 업로드
  Future<void> _uploadImage(File imageFile) async {
    try {
      String fileName = 'images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Image uploaded: $downloadUrl');
    } catch (e) {
      debugPrint("Upload error: $e");
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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 100 / 852 * screenHeight),
          // ✅ 수정: 카메라 프리뷰 영역 (전체 화면)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 355 / 393 * screenWidth,
              height: 472 / 852 * screenHeight,
              child: UiKitView(
                viewType: 'com.soi.camera/preview',
                onPlatformViewCreated: (int id) {
                  debugPrint('카메라 뷰 생성됨: $id');
                },
                creationParams: <String, dynamic>{},
                creationParamsCodec: const StandardMessageCodec(),
              ),
            ),
          ),
          SizedBox(height: 44 / 852 * screenHeight),

          // ✅ 추가: 카메라 그리드 라인
          IgnorePointer(
            ignoring: true,
            child: CustomPaint(painter: GridPainter()),
          ),

          // ✅ 추가: 중앙 하단 줌 옵션
          /*Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildZoomOption('.5'),
                  SizedBox(width: 24),
                  _buildZoomOption('1x'),
                  SizedBox(width: 24),
                  _buildZoomOption('3'),
                ],
              ),
            ),
          ),*/

          // ✅ 수정: 하단 버튼 레이아웃 변경
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 플래시 버튼
              Container(
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
    );
  }

  // ✅ 추가: 줌 옵션 버튼 위젯
  /* Widget _buildZoomOption(String zoom) {
    final isSelected = currentZoom == zoom;
    return GestureDetector(
      onTap: () => _setZoomLevel(zoom),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          zoom,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }*/
}

// ✅ 추가: 그리드 라인 그리는 Custom Painter
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;

    // 수직선 그리기
    final double cellWidth = size.width / 3;
    for (int i = 1; i < 3; i++) {
      final x = cellWidth * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 수평선 그리기
    final double cellHeight = size.height / 3;
    for (int i = 1; i < 3; i++) {
      final y = cellHeight * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
