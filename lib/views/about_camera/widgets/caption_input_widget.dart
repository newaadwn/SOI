import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CaptionInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final bool isCaptionEmpty;
  final VoidCallback onMicTap;

  const CaptionInputWidget({
    super.key,
    required this.controller,
    required this.isCaptionEmpty,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF373737).withOpacity(0.66),
        borderRadius: BorderRadius.circular(21.5),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 19.w, vertical: 5.h),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.50,
                ),
                cursorColor: Colors.white,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: '게시글 추가하기....',
                  hintStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w200,
                    letterSpacing: -1.14,
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder:
                  (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
              child:
                  isCaptionEmpty
                      ? Row(
                        key: const ValueKey('mic_button'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 12.w),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onMicTap,
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                'assets/mic_icon.png',
                                width: 36.w,
                                height: 36.h,
                              ),
                            ),
                          ),
                        ],
                      )
                      : SizedBox(
                        key: const ValueKey('mic_placeholder'),
                        width: 0,
                        height: 36.h,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
