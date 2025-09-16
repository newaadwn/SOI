import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../common/page_title.dart';
import '../common/custom_text_field.dart';

/// 전화번호 입력 페이지 위젯
class PhoneInputPage extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;

  const PhoneInputPage({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const PageTitle(title: 'SOI 접속을 위해 전화번호를 입력해주세요.'),
        SizedBox(height: 24.h),
        CustomTextField(
          controller: controller,
          hintText: '전화번호',
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.start,
          prefixIcon: Icon(
            SolarIconsOutline.phone,
            color: const Color(0xffC0C0C0),
            size: 24.sp,
          ),
          onChanged: onChanged,
        ),
        SizedBox(height: 24.h),
      ],
    );
  }
}
