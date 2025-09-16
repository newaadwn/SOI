import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../common/page_title.dart';
import '../common/custom_text_field.dart';

/// 이름 입력 페이지 위젯
class NameInputPage extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;

  const NameInputPage({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const PageTitle(title: '당신의 이름을 알려주세요.'),
        SizedBox(height: 24.h),
        CustomTextField(
          controller: controller,
          hintText: '이름',
          keyboardType: TextInputType.text,
          onChanged: onChanged,
        ),
        SizedBox(height: 100.h),
      ],
    );
  }
}
