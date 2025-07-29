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
}
