import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 공통으로 사용되는 커스텀 텍스트 필드
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final TextAlign textAlign;
  final Widget? prefixIcon;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final EdgeInsets? contentPadding;
  final double? borderRadius;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.textAlign = TextAlign.center,
    this.prefixIcon,
    this.maxLength,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.contentPadding,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 239.w,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xff323232),
        borderRadius: BorderRadius.circular(borderRadius!),
      ),
      alignment: Alignment.center,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (prefixIcon != null) ...[
            SizedBox(width: 17.w),
            prefixIcon!,
            SizedBox(width: 10.w),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textAlign: textAlign,
              maxLength: maxLength,
              inputFormatters: inputFormatters,
              cursorHeight: 16.h,
              cursorColor: const Color(0xFFF8F8F8),
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 16,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                letterSpacing: -0.08,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                counterText: maxLength != null ? '' : null,
                hintText: hintText,
                hintStyle: TextStyle(
                  color: const Color(0xFFC0C0C0),
                  fontSize: 16.sp,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                ),
                contentPadding:
                    (prefixIcon != null)
                        ? EdgeInsets.only(left: 15.w, bottom: 5.h)
                        : EdgeInsets.only(bottom: 5.h),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}
