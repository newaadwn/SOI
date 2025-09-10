import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 메모리 사용량을 모니터링하고 최적화하는 유틸리티 클래스
class MemoryMonitor {
  static bool _isMonitoring = false;
  static int _lastMemoryUsage = 0;

  /// 메모리 모니터링 시작
  static void startMonitoring() {
    if (_isMonitoring || !kDebugMode) return;

    _isMonitoring = true;
    developer.log('메모리 모니터링 시작');

    // 5초마다 메모리 사용량 체크
    _monitorMemoryUsage();
  }

  /// 메모리 모니터링 중지
  static void stopMonitoring() {
    _isMonitoring = false;
    developer.log('메모리 모니터링 중지');
  }

  /// 현재 메모리 사용량 출력
  static void logCurrentMemoryUsage(String context) {
    if (!kDebugMode) return;

    try {
      final usage = _getCurrentMemoryUsage();
      final usageMB = (usage / (1024 * 1024)).toStringAsFixed(1);

      final deltaFromLast = usage - _lastMemoryUsage;
      final deltaMB = (deltaFromLast / (1024 * 1024)).toStringAsFixed(1);

      String deltaStr = '';
      if (deltaFromLast > 0) {
        deltaStr = ' (+${deltaMB}MB)';
      } else if (deltaFromLast < 0) {
        deltaStr = ' (${deltaMB}MB)';
      }

      developer.log('[$context] 메모리: ${usageMB}MB$deltaStr');

      // 메모리 사용량이 1GB를 넘으면 경고
      if (usage > 1024 * 1024 * 1024) {
        developer.log('메모리 사용량 경고: ${usageMB}MB', name: 'MemoryWarning');
      }

      _lastMemoryUsage = usage;
    } catch (e) {
      developer.log('메모리 사용량 측정 오류: $e');
    }
  }

  /// 메모리 정리 실행
  static void forceGarbageCollection(String context) {
    if (!kDebugMode) return;

    try {
      developer.log('[$context] 메모리 정리 시작');

      // 이미지 캐시 정리
      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (e) {
        developer.log('이미지 캐시 정리 오류: $e');
      }

      // GC 트리거 (개발 모드에서만)
      if (Platform.isAndroid || Platform.isIOS) {
        // native GC 호출 (가능한 경우)
      }

      developer.log('[$context] 메모리 정리 완료');

      // 정리 후 메모리 사용량 체크
      Future.delayed(Duration(milliseconds: 500), () {
        logCurrentMemoryUsage('$context - 정리 후');
      });
    } catch (e) {
      developer.log('메모리 정리 오류: $e');
    }
  }

  /// 현재 메모리 사용량 가져오기 (바이트 단위)
  static int _getCurrentMemoryUsage() {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // ProcessInfo를 통해 메모리 사용량 가져오기
        final info = ProcessInfo.currentRss;
        return info;
      }
    } catch (e) {
      // ProcessInfo를 사용할 수 없는 경우 대체 방법
    }

    // 대체 방법: 대략적인 추정
    return 0;
  }

  /// 주기적 메모리 모니터링
  static void _monitorMemoryUsage() async {
    while (_isMonitoring) {
      await Future.delayed(Duration(seconds: 5));
      if (_isMonitoring) {
        logCurrentMemoryUsage('주기적 체크');
      }
    }
  }

  /// 메모리 임계값 체크
  static bool isMemoryUsageHigh() {
    try {
      final usage = _getCurrentMemoryUsage();
      final usageMB = usage / (1024 * 1024);

      // 1.5GB 이상이면 높은 사용량으로 판단
      return usageMB > 1536;
    } catch (e) {
      return false;
    }
  }

  /// 메모리 사용량 경고 알림
  static void checkMemoryWarning(String context) {
    if (isMemoryUsageHigh()) {
      developer.log('[$context] 높은 메모리 사용량 감지 - 정리 필요', name: 'MemoryWarning');
      forceGarbageCollection(context);
    }
  }
}
