import 'package:flutter/material.dart';
import 'package:flutter_boxicons/flutter_boxicons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../controllers/contact_controller.dart';

class FriendAddOptionsCard extends StatelessWidget {
  final double scale;
  final ContactController contactController;
  final VoidCallback onToggleChange;
  final VoidCallback onAddByIdTap;

  const FriendAddOptionsCard({
    super.key,
    required this.scale,
    required this.contactController,
    required this.onToggleChange,
    required this.onAddByIdTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xff1c1c1c),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Column(
        children: [
          // 연락처 동기화
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
            child: Row(
              children: [
                // 아이콘
                Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: const BoxDecoration(
                    color: Color(0xff323232),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Boxicons.bxs_contact,
                    color: const Color(0xfff9f9f9),
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 9.sp),

                // 텍스트
                Expanded(
                  child: Text(
                    '연락처 동기화',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                // 토글 스위치 또는 로딩 스피너
                Row(
                  children: [
                    // 일시중지 상태 표시
                    if (contactController.isSyncPaused) ...[
                      Icon(
                        Icons.pause_circle_filled,
                        color: Colors.orange,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.sp),
                    ],
                    Transform.scale(
                      scale: scale,
                      child:
                          contactController.isLoading
                              ? SizedBox(
                                width: 24.sp,
                                height: 24.sp,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : SizedBox(
                                width: 35,
                                height: 18,
                                child: Switch(
                                  value: contactController.contactSyncEnabled,
                                  onChanged: (value) {
                                    onToggleChange();
                                  },
                                  activeColor: const Color(0xff000000),
                                  activeTrackColor: const Color(0xffffffff),
                                  inactiveThumbColor: const Color(0xff000000),
                                  inactiveTrackColor: const Color(0xff5a5a5a),
                                ),
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 구분선
          Divider(
            color: Color(0xff5a5a5a).withValues(alpha: 0.1),
            height: 1,
            thickness: 1,
          ),

          // ID로 추가 하기
          InkWell(
            onTap: onAddByIdTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    width: 44.w,
                    height: 44.h,
                    decoration: const BoxDecoration(
                      color: Color(0xff323232),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'ID',
                        style: TextStyle(
                          color: const Color(0xfff9f9f9),
                          fontSize: 25.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 9.sp),

                  // 텍스트 (수정됨)
                  Expanded(
                    child: Text(
                      'ID로 추가 하기',
                      style: TextStyle(
                        color: const Color(0xfff9f9f9),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
