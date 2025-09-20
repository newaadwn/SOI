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
            final confirmed = await showModalBottomSheet<bool>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (sheetContext) {
                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xff323232),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 17.h),
                      Text(
                        '사진 삭제',
                        style: TextStyle(
                          color: const Color(0xFFF8F8F8),
                          fontSize: (19.78).sp,
                          fontFamily: 'Pretendard Variable',
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Text(
                          '사진 삭제 시 해당 카테고리에서 확인할 수 없으며,\n30일 이내에 복구가 가능합니다',
                          style: TextStyle(
                            color: const Color(0xFFF8F8F8),
                            fontSize: 14.sp,
                            fontFamily: 'Pretendard Variable',
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        height: 38.h,
                        width: 344.w,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(true);
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
                        height: 38.h,
                        width: 344.w,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF323232),
                            foregroundColor: Colors.white,
                            elevation: 0,
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
                      SizedBox(height: 30.h),
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
