import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// 빈 피드 위젯
// 사용자가 사진을 업로드하지 않았을 때 표시되는 위젯
class EmptyFeedWidget extends StatelessWidget {
  const EmptyFeedWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 80),
          SizedBox(height: 16.h),
          Text(
            '아직 사진이 없어요',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '친구들과 카테고리를 만들고\n첫 번째 사진을 공유해보세요!',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
