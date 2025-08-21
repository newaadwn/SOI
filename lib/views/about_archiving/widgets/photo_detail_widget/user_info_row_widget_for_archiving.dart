import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/photo_data_model.dart';
import '../../../../utils/format_utils.dart';

class UserInfoRowWidget extends StatelessWidget {
  final PhotoDataModel photo;
  final String userName;
  final bool isCurrentUserPhoto;
  final VoidCallback onDeletePressed;

  const UserInfoRowWidget({
    super.key,
    required this.photo,
    required this.userName,
    required this.isCurrentUserPhoto,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 25.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사용자 닉네임
              Container(
                height: 22.h,
                alignment: Alignment.centerLeft,
                child: Text(
                  '@${userName.isNotEmpty ? userName : photo.userID}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontFamily: "Pretendard",
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.visible, // 긴 텍스트 처리
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

        // 좋아요 버튼 - Material + InkWell
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(50.w),
            onTap: () {
              // TODO: 좋아요 기능 구현
            },
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Image.asset(
                "assets/like_icon.png",
                width: 33.w,
                height: 33.h,
              ),
            ),
          ),
        ),

        // 더보기 버튼 - Material + InkWell
        (!isCurrentUserPhoto) ? Container() : _buildMoreMenuButton(context),
        SizedBox(width: 13.w),
      ],
    );
  }

  /// 더보기 메뉴 버튼 위젯
  Widget _buildMoreMenuButton(BuildContext context) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(9.14)),
        ),
      ),
      builder: (
        BuildContext context,
        MenuController controller,
        Widget? child,
      ) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(50.w),
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Icon(
                Icons.more_vert,
                size: 25.sp,
                color: Color(0xfff9f9f9),
              ),
            ),
          ),
        );
      },
      menuChildren: [
        MenuItemButton(
          onPressed: onDeletePressed,
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9.14),
                side: BorderSide.none,
              ),
            ),
          ),
          child: Container(
            width: 173.w,
            height: 45.h,
            padding: EdgeInsets.only(left: 13.96.w),
            decoration: BoxDecoration(
              color: Color(0xff323232),
              borderRadius: BorderRadius.circular(9.14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/trash_red.png',
                  color: Colors.red,
                  width: 11.16.sp,
                  height: 12.56.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  '삭제',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 15.3517.sp,
                    fontFamily: "Pretendard",
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
