import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/photo_data_model.dart';
import '../../../utils/format_utils.dart';

/// 사용자 정보 표시 위젯 (아이디와 날짜)
///
/// 피드에서 사진 하단에 표시되는 사용자 닉네임과 날짜 정보를 담당합니다.
class UserInfoWidget extends StatelessWidget {
  final PhotoDataModel photo;
  final Map<String, String> userNames;

  const UserInfoWidget({
    super.key,
    required this.photo,
    required this.userNames,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 23.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사용자 닉네임
              Container(
                height: 22.h,
                alignment: Alignment.centerLeft,
                child: Text(
                  '@${userNames[photo.userID] ?? photo.userID}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 날짜
              Text(
                FormatUtils.formatRelativeTime(photo.createdAt),
                style: TextStyle(
                  color: Color(0xffcccccc),
                  fontSize: 14.sp,
                  fontFamily: "Pretendard",
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
