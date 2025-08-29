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
  final bool isCurrentUserPhoto; // 현재 사용자 사진인지 여부
  final VoidCallback? onDeletePressed; // 삭제 콜백 (피드 갱신 위해 상위 전달)
  final VoidCallback? onLikePressed; // 좋아요 콜백 (추후 구현용)
  final bool isLiked; // 좋아요 상태 (간단 표시)

  const UserInfoWidget({
    super.key,
    required this.photo,
    required this.userNames,
    this.isCurrentUserPhoto = false,
    this.onDeletePressed,
    this.onLikePressed,
    this.isLiked = false,
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
                  overflow: TextOverflow.visible,
                ),
              ),
              Text(
                FormatUtils.formatRelativeTime(photo.createdAt),
                style: TextStyle(
                  color: const Color(0xffcccccc),
                  fontSize: 14.sp,
                  fontFamily: "Pretendard",
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        // 좋아요 버튼
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(50.w),
            onTap: onLikePressed,
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Image.asset(
                'assets/like_icon.png',
                width: 33.w,
                height: 33.h,
                color: isLiked ? Colors.redAccent : null,
              ),
            ),
          ),
        ),
        // 더보기 (현재 사용자 소유 사진일 때만)
        if (isCurrentUserPhoto)
          _MoreMenuButton(onDeletePressed: onDeletePressed),
        SizedBox(width: 13.w),
      ],
    );
  }
}

/// 피드 더보기 메뉴 (삭제 전 확인 다이얼로그 표시)
class _MoreMenuButton extends StatelessWidget {
  final VoidCallback? onDeletePressed;
  const _MoreMenuButton({this.onDeletePressed});

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(BorderSide.none),
      ),
      builder: (context, controller, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(50.w),
            onTap: () {
              controller.isOpen ? controller.close() : controller.open();
            },
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Icon(
                Icons.more_vert,
                size: 25.sp,
                color: const Color(0xfff9f9f9),
              ),
            ),
          ),
        );
      },
      menuChildren: [
        MenuItemButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              barrierDismissible: true,
              builder: (ctx) {
                return AlertDialog(
                  backgroundColor: const Color(0xff323232),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 17.h),
                      Text(
                        '사진 삭제',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                          fontSize: 19.8.sp,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        '사진 삭제하면 더 이상 해당 카테고리에서 확인할 수 없으며 삭제 후 복구가 \n불가능합니다.',
                        style: TextStyle(
                          color: const Color(0xfff9f9f9),
                          fontFamily: 'Pretendard',
                          fontSize: 15.8.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: (185.5).w,
                        height: 38.h,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop(true); // confirm
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xfff5f5f5),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.2),
                            ),
                          ),
                          child: Text(
                            '삭제',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              fontSize: (17.8).sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 13.h),
                      SizedBox(
                        width: (185.5).w,
                        height: 38.h,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff5a5a5a),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.2),
                            ),
                          ),
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w500,
                              fontSize: (17.8).sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),
                    ],
                  ),
                );
              },
            );
            if (confirmed == true) {
              onDeletePressed?.call();
            }
          },
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
              color: const Color(0xff323232),
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
                    fontFamily: 'Pretendard',
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
