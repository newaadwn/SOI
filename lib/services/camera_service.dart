import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

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

  final ImagePicker _imagePicker = ImagePicker();

  // ✅ 카메라 세션 상태 추적
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

  // ✅ 갤러리 미리보기 상태 관리 (아키텍처 준수)
  String? _latestGalleryImagePath;
  bool _isLoadingGalleryImage = false;

  // Getters (View에서 상태 접근용)
  String? get latestGalleryImagePath => _latestGalleryImagePath;
  bool get isLoadingGalleryImage => _isLoadingGalleryImage;

  // ==================== 갤러리 및 파일 관리 ====================

  // 갤러리에서 이미지를 선택할 때 사용할 필터 옵션
  // 이 필터는 이미지 크기 제약을 무시하고 모든 이미지를 선택할 수 있도록 설정합니다.
  final PMFilter filter = FilterOptionGroup(
    imageOption: const FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
    ),
  );

  /// ✅ 갤러리 미리보기 이미지 로드 (Service 로직)
  /// 최신 갤러리 이미지를 캐시하여 성능 향상
  Future<void> loadLatestGalleryImage() async {
    // 이미 로딩 중이면 중복 실행 방지
    if (_isLoadingGalleryImage) {
      debugPrint('갤러리 이미지 로딩이 이미 진행 중');
      return;
    }

    _isLoadingGalleryImage = true;

    try {
      debugPrint('최신 갤러리 이미지 로딩 시작...');

      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        filterOption: filter,
      );

      if (paths.isNotEmpty) {
        final List<AssetEntity> assets = await paths.first.getAssetListPaged(
          page: 0,
          size: 1,
        );

        if (assets.isNotEmpty) {
          // 실제 파일 경로를 캐시에 저장
          final File? file = await assets.first.file;
          _latestGalleryImagePath = file?.path;

          debugPrint('갤러리 이미지 로딩 완료: $_latestGalleryImagePath');
        } else {
          _latestGalleryImagePath = null;
          debugPrint('갤러리에 이미지가 없음');
        }
      } else {
        _latestGalleryImagePath = null;
        debugPrint('갤러리 접근 불가');
      }
    } catch (e) {
      debugPrint("갤러리 이미지 로딩 오류: $e");
      _latestGalleryImagePath = null;
    } finally {
      _isLoadingGalleryImage = false;
    }
  }

  /// ✅ 갤러리 미리보기 캐시 새로고침 (사진 촬영 후 호출)
  Future<void> refreshGalleryPreview() async {
    debugPrint('갤러리 미리보기 새로고침');
    await loadLatestGalleryImage();
  }

  /// ✅ 개선된 갤러리 첫 번째 이미지 로딩 (권한 처리 포함)
  Future<AssetEntity?> getFirstGalleryImage() async {
    try {
      // 1. 갤러리 접근 권한 요청
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        debugPrint('갤러리 접근 권한 없음');
        return null;
      }

      // 2. 갤러리 경로 가져오기
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
        ),
      );

      if (paths.isEmpty) {
        debugPrint('갤러리 경로가 비어있음');
        return null;
      }

      // 3. 첫 번째 경로에서 첫 번째 이미지 가져오기
      final List<AssetEntity> assets = await paths.first.getAssetListPaged(
        page: 0,
        size: 1,
      );

      if (assets.isEmpty) {
        debugPrint('갤러리에 이미지 없음');
        return null;
      }

      debugPrint('갤러리 첫 번째 이미지 로딩 성공: ${assets.first.id}');
      return assets.first;
    } catch (e) {
      debugPrint('갤러리 첫 번째 이미지 로딩 오류: $e');
      return null;
    }
  }

  /// ✅ AssetEntity를 File로 변환
  Future<File?> assetToFile(AssetEntity asset) async {
    try {
      final File? file = await asset.file;
      return file;
    } catch (e) {
      debugPrint('AssetEntity 파일 변환 오류: $e');
      return null;
    }
  }

  // 갤러리의 첫 번째 사진을 골라서 반환하는 함수 (레거시 - 호환성용)
  // 이 함수는 갤러리에서 첫 번째 사진의 경로를 가져옵니다.
  // 만약 갤러리가 비어있다면 null을 반환합니다.
  @Deprecated('Use loadLatestGalleryImage() instead for better performance')
  Future<String?> pickFirstImageFromGallery() async {
    try {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        filterOption: filter,
      );

      if (paths.isNotEmpty) {
        final List<AssetEntity> assets = await paths.first.getAssetListPaged(
          page: 0,
          size: 1,
        );

        if (assets.isNotEmpty) {
          // 실제 파일 경로 반환
          final File? file = await assets.first.file;
          return file?.path;
        }
      }
    } catch (e) {
      debugPrint("갤러리에서 이미지 선택 오류: $e");
      return null;
    }
    return null;
  }

  // 갤러리에서 이미지를 선택하는 함수
  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? imageFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      return imageFile?.path;
    } catch (e) {
      debugPrint("갤러리에서 이미지 선택 오류: $e");
      return null;
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
      debugPrint('카메라 세션 활성화 시작...');

      // ✅ 안전한 세션 상태 확인 (네이티브 메서드가 없어도 작동)
      bool needsReactivation = false;

      try {
        // 네이티브 세션 상태 확인 시도 (선택적)
        final result = await _channel.invokeMethod('isSessionActive');
        bool nativeSessionActive = result ?? false;
        debugPrint(
          '네이티브 세션 상태: $nativeSessionActive, 서비스 상태: $_isSessionActive',
        );

        needsReactivation = !nativeSessionActive || !_isSessionActive;
      } catch (e) {
        // 네이티브 메서드가 구현되지 않은 경우 기본 로직 사용
        if (e.toString().contains('unimplemented') ||
            e.toString().contains('MissingPluginException')) {
          debugPrint('네이티브 isSessionActive 메서드 미구현 - 기본 로직 사용');
          needsReactivation = !_isSessionActive;
        } else {
          debugPrint('네이티브 세션 상태 확인 실패, 강제 재초기화: $e');
          needsReactivation = true;
        }
      }

      // ✅ 재활성화가 필요한 경우에만 실행
      if (needsReactivation) {
        debugPrint('카메라 세션 재활성화 필요');
        await _channel.invokeMethod('resumeCamera');
        _isSessionActive = true;
        debugPrint('카메라 세션 활성화 완료');
      } else {
        debugPrint('카메라 세션이 이미 정상적으로 활성화되어 있음');
        _isSessionActive = true; // 상태 동기화
      }
    } on PlatformException catch (e) {
      debugPrint("카메라 세션 활성화 오류: ${e.message}");
      _isSessionActive = false;

      // ✅ 오류 발생 시 세션 상태 강제 리셋
      await _forceResetSession();
    }
  }

  // ✅ 세션 상태 강제 리셋 메서드 추가
  Future<void> _forceResetSession() async {
    try {
      debugPrint('카메라 세션 강제 리셋 시작');
      _isSessionActive = false;

      // 네이티브 세션 완전 종료 후 재시작
      await _channel.invokeMethod('pauseCamera');
      await Future.delayed(Duration(milliseconds: 100));
      await _channel.invokeMethod('resumeCamera');

      _isSessionActive = true;
      debugPrint('카메라 세션 강제 리셋 완료');
    } catch (e) {
      debugPrint('카메라 세션 강제 리셋 실패: $e');
      _isSessionActive = false;
    }
  }

  Future<void> deactivateSession() async {
    // ✅ 이미 비활성화된 세션은 다시 비활성화하지 않음
    if (!_isSessionActive) {
      debugPrint('📷 카메라 세션이 이미 비활성화되어 있음');
      return;
    }

    try {
      debugPrint('카메라 세션 비활성화 시작...');
      await _channel.invokeMethod('pauseCamera');
      _isSessionActive = false;
      debugPrint('카메라 세션 비활성화 완료');
    } on PlatformException catch (e) {
      debugPrint("카메라 세션 비활성화 오류: ${e.message}");
    }
  }

  Future<void> pauseCamera() async {
    // ✅ 이미 비활성화된 세션은 다시 일시중지하지 않음
    if (!_isSessionActive) {
      debugPrint('📷 카메라 세션이 이미 비활성화되어 있음');
      return;
    }

    try {
      await _channel.invokeMethod('pauseCamera');
      // ✅ 일시 중지는 완전 비활성화가 아니므로 상태는 유지
      debugPrint('카메라 세션 일시 중지');
    } on PlatformException catch (e) {
      debugPrint("카메라 일시 중지 오류: ${e.message}");
    }
  }

  Future<void> resumeCamera() async {
    try {
      await _channel.invokeMethod('resumeCamera');
      _isSessionActive = true;
      debugPrint('카메라 세션 재개');
    } on PlatformException catch (e) {
      debugPrint("카메라 재개 오류: ${e.message}");
      _isSessionActive = false;
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

      // ✅ 상태 리셋
      _isSessionActive = false;

      debugPrint('카메라 리소스 정리 완료');
    } on PlatformException catch (e) {
      debugPrint("카메라 리소스 정리 오류: ${e.message}");
      // ✅ 에러가 나도 상태는 리셋
      _isSessionActive = false;
    }
  }
}
