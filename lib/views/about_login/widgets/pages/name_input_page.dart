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
    // 키보드 높이 계산
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final verticalOffset = keyboardHeight > 0 ? -30.0 : 0.0;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 60.h,
          left: 20.w,
          child: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),
        Transform.translate(
          offset: Offset(0, verticalOffset),
          child: Column(
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
          ),
        ),
      ],
    );
  }
}
