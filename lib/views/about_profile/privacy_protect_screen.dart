import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PrivacyProtectScreen extends StatelessWidget {
  const PrivacyProtectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '개인정보 보호',
              style: TextStyle(
                color: Color(0xFFF8F8F8),
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1C1C1E),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: SizedBox(
                width: 358.w,
                height: 62,
                child: Row(
                  children: [
                    SizedBox(width: 16.w),
                    Icon(Icons.block_flipped, size: 32, color: Colors.white),
                    SizedBox(width: 25.w),
                    Text(
                      '차단된 사용자',
                      style: TextStyle(
                        color: const Color(0xFFF8F8F8),
                        fontSize: 17.sp,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 13.h),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1C1C1E),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: SizedBox(
                width: 358.w,
                height: 62,
                child: Row(
                  children: [
                    SizedBox(width: 16.w),
                    Image.asset(
                      "assets/unactive_icon.png",
                      width: 26.w,
                      height: 26.h,
                    ),
                    SizedBox(width: 25.w),
                    Text(
                      '계정 비활성화',
                      style: TextStyle(
                        color: const Color(0xFFF8F8F8),
                        fontSize: 17.sp,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 13.h),
            Container(
              width: 358.w,
              height: 62,
              decoration: BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(width: 16.w),
                  Image.asset(
                    "assets/contact.png",
                    width: 22.5.w,
                    height: 22.5.h,
                  ),
                  SizedBox(width: 25.w),
                  Text(
                    '연락처 동기화',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8),
                      fontSize: 17.sp,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
