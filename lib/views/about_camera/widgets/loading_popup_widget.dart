import 'package:flutter/material.dart';

class LoadingPopupWidget extends StatelessWidget {
  final String message;
  final double? iconSize;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? indicatorColor;

  const LoadingPopupWidget({
    super.key,
    this.message = '잠시만 기다려주세요',
    this.iconSize,
    this.backgroundColor,
    this.textColor,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: EdgeInsets.all(screenWidth * 0.064),
          margin: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.128,
          ), // 반응형 마진 (50px 기준)
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(screenWidth * 0.032),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: screenWidth * 0.025,
                offset: Offset(0, screenHeight * 0.006),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 로딩 인디케이터
              SizedBox(
                width: iconSize ?? screenWidth * 0.128,
                height: iconSize ?? screenWidth * 0.128,
                child: CircularProgressIndicator(
                  strokeWidth: screenWidth * 0.01,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    indicatorColor ?? Colors.white,
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.024),
              // 메시지 텍스트
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: screenWidth * 0.041,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 팝업을 표시하는 정적 메서드
  static Future<void> show(
    BuildContext context, {
    String message = '잠시만 기다려주세요',
    double? iconSize,
    Color? backgroundColor,
    Color? textColor,
    Color? indicatorColor,
    bool barrierDismissible = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return LoadingPopupWidget(
          message: message,
          iconSize: iconSize,
          backgroundColor: backgroundColor,
          textColor: textColor,
          indicatorColor: indicatorColor,
        );
      },
    );
  }

  /// 팝업을 닫는 정적 메서드
  static void hide(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}
