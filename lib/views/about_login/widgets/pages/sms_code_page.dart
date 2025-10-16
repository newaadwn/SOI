import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../common/page_title.dart';
import '../common/custom_text_field.dart';

/// SMS 코드 입력 페이지 위젯
class SmsCodePage extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback onResendPressed;
  final PageController? pageController;

  const SmsCodePage({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onResendPressed,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    // 키보드 높이 계산
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final verticalOffset = keyboardHeight > 0 ? -30.0 : 0.0; // 키보드가 올라올 때 위로 이동

    return Stack(
      children: [
        Positioned(
          top: 60.h,
          left: 20.w,
          child: IconButton(
            onPressed: () {
              pageController?.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, verticalOffset),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const PageTitle(title: '인증번호를 입력해주세요.'),
                SizedBox(height: 24.h),
                CustomTextField(
                  controller: controller,
                  hintText: '인증번호',
                  keyboardType: TextInputType.number,
                  borderRadius: 16.5,
                  contentPadding: EdgeInsets.only(bottom: 7.h),
                  onChanged: onChanged,
                ),
                TextButton(
                  onPressed: onResendPressed,
                  child: RichText(
                    text: TextSpan(
                      text: '인증번호 다시 받기',
                      style: TextStyle(
                        color: const Color(0xFFF8F8F8),
                        fontSize: 12,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
