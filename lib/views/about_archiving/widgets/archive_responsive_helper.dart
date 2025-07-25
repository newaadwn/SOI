import 'package:flutter/material.dart';

/// 📱 아카이브 화면 반응형 헬퍼 클래스
/// 작은 화면 (< 375px), 일반 화면 (375px - 414px), 큰 화면 (> 414px) 기준으로
/// Figma 디자인 기준 168x229 비율의 카드 레이아웃을 지원합니다.
class ArchiveResponsiveHelper {
  /// 화면 크기 구분
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 375;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 414;
  }

  static bool isRegularScreen(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 375 && width <= 414;
  }

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
    if (isSmallScreen(context)) {
      return 1; // 작은 화면: 1열로 표시
    } else if (isRegularScreen(context)) {
      return 2; // 일반 화면: 2열로 표시
    } else {
      return 2; // 큰 화면: 2열로 표시 (더 넓은 카드)
    }
  }

  /// 카드 크기 계산 (화면 크기별 최적화)
  static Map<String, double> getCardDimensions(BuildContext context) {
    final screenWidth = getResponsiveWidth(context);
    final crossAxisCount = getGridCrossAxisCount(context);

    // 화면 크기별 패딩 조정
    double horizontalPadding;
    double cardSpacing;

    if (isSmallScreen(context)) {
      horizontalPadding = screenWidth * 0.05; // 작은 화면: 5%
      cardSpacing = 10.0; // 작은 간격
    } else if (isLargeScreen(context)) {
      horizontalPadding = screenWidth * 0.06; // 큰 화면: 6%
      cardSpacing = 18.0; // 큰 간격
    } else {
      horizontalPadding = screenWidth * 0.051; // 일반 화면: 5.1%
      cardSpacing = 15.0; // 일반 간격
    }

    // 패딩과 간격을 고려한 실제 카드 너비 계산
    final totalPadding = horizontalPadding * 2;
    final totalSpacing = (crossAxisCount - 1) * cardSpacing;
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

  /// 그리드 패딩 계산 (화면 크기별)
  static EdgeInsets getGridPadding(BuildContext context) {
    final screenWidth = getResponsiveWidth(context);

    double horizontalPadding;
    if (isSmallScreen(context)) {
      horizontalPadding = screenWidth * 0.05; // 작은 화면: 5%
    } else if (isLargeScreen(context)) {
      horizontalPadding = screenWidth * 0.06; // 큰 화면: 6%
    } else {
      horizontalPadding = screenWidth * 0.051; // 일반 화면: 5.1%
    }

    return EdgeInsets.symmetric(horizontal: horizontalPadding);
  }

  /// 그리드 메인 축 간격 계산 (화면 크기별)
  static double getMainAxisSpacing(BuildContext context) {
    if (isSmallScreen(context)) {
      return 12.0; // 작은 화면: 작은 간격
    } else if (isLargeScreen(context)) {
      return 18.0; // 큰 화면: 큰 간격
    } else {
      return 15.0; // 일반 화면: 일반 간격
    }
  }

  /// 그리드 교차 축 간격 계산 (화면 크기별)
  static double getCrossAxisSpacing(BuildContext context) {
    if (isSmallScreen(context)) {
      return 10.0; // 작은 화면: 작은 간격
    } else if (isLargeScreen(context)) {
      return 18.0; // 큰 화면: 큰 간격
    } else {
      return 15.0; // 일반 화면: 일반 간격
    }
  }

  /// 스크롤 뷰 상단 여백 계산
  static double getTopSpacing(BuildContext context) {
    if (isSmallScreen(context)) {
      return getResponsiveHeight(context) * 0.005; // 작은 화면: 0.5%
    } else if (isLargeScreen(context)) {
      return getResponsiveHeight(context) * 0.015; // 큰 화면: 1.5%
    } else {
      return getResponsiveHeight(context) * 0.01; // 일반 화면: 1%
    }
  }
}
