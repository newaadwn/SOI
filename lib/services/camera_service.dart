import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

// 서비스 클래스: 카메라 관련 기능을 제공
// 이 클래스는 싱글톤 패턴을 사용하여 앱 전체에서 하나의 인스턴스만 사용합니다.
// 카메라 초기화, 세션 관리, 최적화, 플래시 설정, 줌 레벨 조정,
// 사진 촬영 등의 기능을 제공합니다.

// 다른 service 파일들은 repositories를 가지고 와서 비즈니스 로직을 구현하지만, cameraService는
// 카메라 관련 기능들을 여기서 구현하여서 camera resource가 한번만 생성되도록 하기 위함입니다.
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() {
    return _instance;
  }
  CameraService._internal();

  static const MethodChannel _channel = MethodChannel('com.soi.camera');

  bool _isGloballyInitialized = false;
  //static Widget? _cameraView;
  //final GlobalKey _cameraKey = GlobalKey();
  //static final bool _isViewCreated = false;

  Future<void> globalInitialize() async {
    if (!_isGloballyInitialized) {
      try {
        await _channel
            .invokeMethod('initCamera')
            .timeout(
              const Duration(seconds: 1),
              onTimeout: () {
                debugPrint('카메라 초기화 타임아웃');
                throw PlatformException(
                  code: 'TIMEOUT',
                  message: '카메라 초기화 시간이 초과되었습니다',
                );
              },
            );
        _isGloballyInitialized = true;
        debugPrint('카메라 전역 초기화 완료');
      } on PlatformException catch (e) {
        debugPrint("카메라 전역 초기화 오류: ${e.message}");
        rethrow;
      }
    }
  }

  Widget getCameraView() {
    // 한 번 생성된 뷰는 절대 재생성하지 않음
    //debugPrint("isViewCreated: $_isViewCreated");

    return _buildCameraView();
  }

  Widget _buildCameraView() {
    // 플랫폼에 따라 다른 카메라 프리뷰 위젯 생성
    if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'com.soi.camera/preview',
        onPlatformViewCreated: (int id) {
          debugPrint('안드로이드 카메라 뷰 생성됨: $id');
          optimizeCamera();
        },
        creationParams: <String, dynamic>{
          'useSRGBColorSpace': true,
          'useHighQuality': true,
          'resumeExistingSession': true,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isIOS) {
      return UiKitView(
        viewType: 'com.soi.camera/preview',
        onPlatformViewCreated: (int id) {
          debugPrint('iOS 카메라 뷰 생성됨: $id');
        },
        creationParams: <String, dynamic>{
          'useSRGBColorSpace': true,
          'useHighQuality': true,
          'resumeExistingSession': true,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return Center(
        child: Text('지원되지 않는 플랫폼입니다', style: TextStyle(color: Colors.white)),
      );
    }
  }

  Future<void> activateSession() async {
    try {
      await _channel.invokeMethod('resumeCamera');
      debugPrint('카메라 세션 활성화');
    } on PlatformException catch (e) {
      debugPrint("카메라 세션 활성화 오류: ${e.message}");
    }
  }

  Future<void> deactivateSession() async {
    try {
      await _channel.invokeMethod('pauseCamera');
      debugPrint('카메라 세션 비활성화');
    } on PlatformException catch (e) {
      debugPrint("카메라 세션 비활성화 오류: ${e.message}");
    }
  }

  Future<void> pauseCamera() async {
    try {
      await _channel.invokeMethod('pauseCamera');
      debugPrint('카메라 세션 일시 중지');
    } on PlatformException catch (e) {
      debugPrint("카메라 일시 중지 오류: ${e.message}");
    }
  }

  Future<void> resumeCamera() async {
    try {
      await _channel.invokeMethod('resumeCamera');
      debugPrint('카메라 세션 재개');
    } on PlatformException catch (e) {
      debugPrint("카메라 재개 오류: ${e.message}");
    }
  }

  Future<void> optimizeCamera() async {
    try {
      // 기존 네이티브 구현에 optimizeCamera 메서드가 없을 수 있으므로
      // 안전하게 처리하거나 필요한 경우 네이티브에서 구현 필요
      await _channel.invokeMethod('optimizeCamera', {
        'autoFocus': true,
        'highQuality': true,
        'stabilization': true,
      });
      debugPrint('카메라 최적화 완료');
    } on PlatformException catch (e) {
      // optimizeCamera 메서드가 구현되지 않은 경우 무시
      if (e.code == 'unimplemented') {
        debugPrint('카메라 최적화 메서드가 구현되지 않음 (무시)');
      } else {
        debugPrint("카메라 최적화 오류: ${e.message}");
      }
    }
  }

  Future<void> setFlash(bool isOn) async {
    try {
      await _channel.invokeMethod('setFlash', {'isOn': isOn});
    } on PlatformException catch (e) {
      debugPrint("플래시 설정 오류: ${e.message}");
    }
  }

  Future<void> setZoomLevel(String level) async {
    try {
      await _channel.invokeMethod('setZoomLevel', {'level': level});
    } on PlatformException catch (e) {
      debugPrint("줌 레벨 설정 오류: ${e.message}");
    }
  }

  Future<void> setBrightness(double value) async {
    try {
      await _channel.invokeMethod('setBrightness', {'value': value});
    } on PlatformException catch (e) {
      debugPrint("밝기 설정 오류: ${e.message}");
    }
  }

  Future<String> takePicture() async {
    try {
      return await _channel.invokeMethod('takePicture');
    } on PlatformException catch (e) {
      debugPrint("사진 촬영 오류: ${e.message}");
      return '';
    }
  }

  Future<void> switchCamera() async {
    try {
      await _channel.invokeMethod('switchCamera');
    } on PlatformException catch (e) {
      debugPrint("카메라 전환 오류: ${e.message}");
    }
  }

  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('disposeCamera');
      // _cameraView = null;
      _isGloballyInitialized = false;
      debugPrint('카메라 리소스 정리 완료');
    } on PlatformException catch (e) {
      debugPrint("카메라 리소스 정리 오류: ${e.message}");
    }
  }
}
