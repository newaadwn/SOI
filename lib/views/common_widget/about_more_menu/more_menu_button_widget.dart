import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 피드 더보기 메뉴 (삭제 전 확인 다이얼로그 표시)
class MoreMenuButton extends StatelessWidget {
  final VoidCallback? onDeletePressed;
  const MoreMenuButton({super.key, this.onDeletePressed});

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
              builder: (context) {
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
                          fontWeight: FontWeight.bold,
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
                            Navigator.of(context).pop(true); // confirm
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
                          onPressed: () => Navigator.of(context).pop(false),
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
              boxShadow: [
                BoxShadow(
                  color: Color(0x3F000000),
                  blurRadius: 12.98,
                  offset: Offset(0, 0),
                  spreadRadius: 2.79,
                ),
              ],
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
