import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 각 페이지에서 사용되는 공통 제목 위젯
class PageTitle extends StatelessWidget {
  final String title;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;

  const PageTitle({
    super.key,
    required this.title,
    this.fontSize = 18,
    this.fontWeight = FontWeight.w600,
    this.color = const Color(0xFFF8F8F8),
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: fontSize!.sp,
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: fontWeight,
      ),
      textAlign: textAlign,
    );
  }
}
