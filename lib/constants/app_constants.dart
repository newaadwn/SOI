/// 앱 전체에서 사용하는 상수들
class AppConstants {
  // ==================== 카메라 관련 ====================

  /// 카메라 초기화 타임아웃 (밀리초)
  static const int cameraInitTimeout = 5000;

  /// 카메라 세션 재시도 횟수
  static const int cameraRetryCount = 3;

  /// 카메라 권한 요청 타임아웃 (밀리초)
  static const int permissionTimeout = 3000;

  // ==================== UI 성능 ====================

  /// IndexedStack 페이지 preload 여부
  static const bool enablePagePreload = true;

  /// 카메라 뷰 캐시 사용 여부
  static const bool enableViewCache = true;

  /// 디버그 로그 출력 여부
  static const bool enableDebugLogs = true;

  // ==================== 메모리 관리 ====================

  /// 이미지 캐시 최대 크기 (MB)
  static const int maxImageCacheSize = 50;

  /// 프로필 이미지 캐시 최대 개수
  static const int maxProfileCacheCount = 100;
}
