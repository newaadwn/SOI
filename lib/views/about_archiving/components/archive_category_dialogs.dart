import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../models/category_data_model.dart';

// 카테고리 관련 다이얼로그들을 관리합니다.
// 팝업 메뉴에서 호출되는 다이얼로그들을 포함합니다.
class ArchiveCategoryDialogs {
  /// 🚪 카테고리 나가기 확인 다이얼로그 (피그마 디자인)
  static void showLeaveCategoryDialog(
    BuildContext context,
    CategoryDataModel category, {
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 314.w,
            height: 326.h,

            decoration: BoxDecoration(
              color: const Color(0xFF323232),
              borderRadius: BorderRadius.circular(14.2),
            ),
            child: Column(
              children: [
                // 제목
                Padding(
                  padding: EdgeInsets.only(top: 31.h),
                  child: Column(
                    children: [
                      Text(
                        '카테고리 나가기',
                        style: TextStyle(
                          fontFamily: 'Pretendard Variable',
                          fontWeight: FontWeight.w700,
                          fontSize: (19.8).sp,
                          color: Color(0xFFF9F9F9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 39.w),
                        child: Text(
                          '카테고리를 나가면, 해당 카테고리에 저장된 사진은 더 이상 확인할 수 없으며 복구가 불가능합니다.',
                          style: TextStyle(
                            color: Color(0xFFF9F9F9),
                            fontSize: (15.78).sp,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Pretendard Variable',
                            height: 1.66,
                            overflow: TextOverflow.visible,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12.h),

                // 버튼들
                Column(
                  children: [
                    // 확인 버튼
                    GestureDetector(
                      onTap: () async {
                        Navigator.of(context).pop(); // 다이얼로그 닫기
                        onConfirm();
                      },
                      child: Container(
                        width: (185.55).w,
                        height: 38.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(14.2),
                        ),
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(top: 3.h),
                            child: Text(
                              '나가기',
                              style: TextStyle(
                                fontFamily: 'Pretendard Variable',
                                fontWeight: FontWeight.w600,
                                fontSize: (17.8).sp,
                                color: Color(0xFF000000),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 13.h),

                    // 취소 버튼
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop(); // 다이얼로그 닫기
                      },
                      child: Container(
                        width: (185.55).w,
                        height: (38).h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A5A5A),
                          borderRadius: BorderRadius.circular(14.2),
                        ),
                        child: Center(
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontFamily: 'Pretendard Variable',
                              fontWeight: FontWeight.w500,
                              fontSize: (17.8).sp,
                              color: Color(0xFFCCCCCC),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
