import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 314.w,
          height: 266.h,
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(14.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 로딩 인디케이터
              SizedBox(
                width: 50.w,
                height: 50.h,
                child: CircularProgressIndicator(
                  strokeWidth: 5.0,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    indicatorColor ?? Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 41.h),
              // 메시지 텍스트
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xffffffff),
                  fontSize: 15.78.sp,
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
