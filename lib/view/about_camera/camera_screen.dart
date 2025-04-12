import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Swift와 통신할 플랫폼 채널
  static const MethodChannel platform = MethodChannel('com.soi.camera');
  String imagePath = '';

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
      await _uploadImage(File(result));
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
    } on PlatformException catch (e) {
      debugPrint("Error toggling flash: ${e.message}");
    }
  }

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
    // ✅ 수정: 내장 카메라 프리뷰로 UI 변경
    return Scaffold(
      appBar: AppBar(title: Text('Camera Screen')),
      body: Column(
        children: [
          // ✅ 추가: 네이티브 카메라 프리뷰를 직접 화면에 표시
          Expanded(
            flex: 3,
            child: UiKitView(
              viewType: 'com.soi.camera/preview',
              onPlatformViewCreated: (int id) {
                debugPrint('카메라 뷰 생성됨: $id');
              },
              creationParams: <String, dynamic>{},
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ),

          // 기존 기능: 카메라 전환, 플래시 토글, 촬영
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _switchCamera,
                      icon: Icon(
                        Icons.switch_camera,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(Icons.flash_on, size: 32, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: _takePicture,
                      icon: Icon(
                        Icons.camera_alt,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 촬영한 이미지 미리보기 (있을 경우)
          if (imagePath.isNotEmpty)
            Container(
              height: 100,
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.file(File(imagePath), height: 100),
              ),
            ),
        ],
      ),
    );
  }
}
