import 'dart:math';
import 'package:intl/intl.dart';

/// 포맷팅 관련 유틸리티 클래스
/// 날짜, 시간, 숫자 등의 표시 형식을 관리합니다.
class FormatUtils {
  /// 날짜를 안전하게 포맷팅하는 메서드
  static String formatDate(DateTime date) {
    try {
      return DateFormat('yyyy.MM.dd').format(date);
    } catch (e) {
      // Fallback 포맷팅
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// 시간을 mm:ss 형식으로 포맷팅
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// 파일 크기를 사람이 읽기 쉬운 형식으로 포맷팅
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// 숫자를 천 단위로 구분하여 포맷팅 (예: 1,234)
  static String formatNumber(int number) {
    final formatter = NumberFormat('#,###');
    return formatter.format(number);
  }

  /// 현재 시간을 기준으로 경과 시간을 동적으로 포맷팅
  /// 예: "방금 전", "5분 전", "2시간 전", "3일 전", "2025.08.20"
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // 음수인 경우 (미래 시간) 처리
    if (difference.isNegative) {
      return formatDate(dateTime);
    }

    final seconds = difference.inSeconds;
    final minutes = difference.inMinutes;
    final hours = difference.inHours;
    final days = difference.inDays;

    if (seconds < 60) {
      return '방금 전';
    } else if (minutes < 60) {
      return '$minutes분 전';
    } else if (hours < 24) {
      return '$hours시간 전';
    } else if (days < 7) {
      return '$days일 전';
    } else {
      // 7일 이상 지난 경우 날짜 형식으로 표시
      return formatDate(dateTime);
    }
  }
}
