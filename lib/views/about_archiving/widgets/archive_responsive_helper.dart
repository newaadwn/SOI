import 'package:flutter/material.dart';

/// 📱 아카이브 화면 반응형 헬퍼 클래스
/// Figma 디자인 기준 168x229 비율의 카드 레이아웃을 지원합니다.
class ArchiveResponsiveHelper {
  /// 화면 너비 가져오기
  static double getResponsiveWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// 화면 높이 가져오기
  static double getResponsiveHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// 그리드 아이템의 가로 세로 비율 계산 (Figma 기준: 168x229)
  static double getGridAspectRatio() {
    // Figma 디자인 비율: 168/229 ≈ 0.734
    return 168.0 / 229.0;
  }

  /// 그리드 열 개수 계산 (화면 크기에 따라)
  static int getGridCrossAxisCount(BuildContext context) {
    final screenWidth = getResponsiveWidth(context);

    if (screenWidth < 360) {
      return 1; // 매우 작은 화면
    } else if (screenWidth < 500) {
      return 2; // 일반적인 폰 크기
    } else if (screenWidth < 800) {
      return 3; // 큰 폰이나 작은 태블릿
    } else {
      return 4; // 태블릿
    }
  }

  /// 카드 크기 계산 (Figma 기준 168x229를 화면 크기에 맞게 조정)
  static Map<String, double> getCardDimensions(BuildContext context) {
    final screenWidth = getResponsiveWidth(context);
    final crossAxisCount = getGridCrossAxisCount(context);

    // 패딩과 간격을 고려한 실제 카드 너비 계산
    final totalPadding = screenWidth * 0.051 * 2; // 좌우 패딩
    final totalSpacing =
        (crossAxisCount - 1) * (screenWidth * (15 / 393)); // 카드 간 간격
    final availableWidth = screenWidth - totalPadding - totalSpacing;
    final cardWidth = availableWidth / crossAxisCount;

    // Figma 비율에 맞춰 높이 계산 (168:229)
    final cardHeight = cardWidth * (229.0 / 168.0);

    return {
      'width': cardWidth,
      'height': cardHeight,
      'imageSize': cardWidth * (146.7 / 168.0), // Figma에서 이미지 크기 비율
    };
  }

  /// 그리드 패딩 계산
  static EdgeInsets getGridPadding(BuildContext context) {
    final screenWidth = getResponsiveWidth(context);
    return EdgeInsets.symmetric(
      horizontal: screenWidth * 0.051, // 20/393 비율 유지
    );
  }

  /// 그리드 간격 계산
  static double getMainAxisSpacing(BuildContext context) {
    final screenHeight = getResponsiveHeight(context);
    return screenHeight * (15 / 852);
  }

  static double getCrossAxisSpacing(BuildContext context) {
    final screenWidth = getResponsiveWidth(context);
    return screenWidth * (15 / 393);
  }
}
