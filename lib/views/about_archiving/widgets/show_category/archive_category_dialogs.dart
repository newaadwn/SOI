import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../models/category_data_model.dart';

// 카테고리 관련 다이얼로그들을 관리합니다.
// 팝업 메뉴에서 호출되는 다이얼로그들을 포함합니다.
class ArchiveCategoryDialogs {
  // 이름 수정 다이얼로그
  static void showEditNameDialog(
    BuildContext context,
    CategoryDataModel category, {
    required Function(String newName) onConfirm,
  }) {
    final TextEditingController controller = TextEditingController(
      text: category.name,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text(
            '카테고리 이름 수정',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: '새 이름을 입력하세요',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  onConfirm(controller.text.trim());
                }
              },
              child: const Text('확인', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

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
            width: 314,
            height: 286,
            decoration: BoxDecoration(
              color: const Color(0xFF323232), // 피그마 배경색
              borderRadius: BorderRadius.circular(14.22),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 39),
              child: Column(
                children: [
                  // 제목
                  Container(
                    height: 61.h,
                    alignment: Alignment.center,
                    child: Text(
                      '카테고리 나가기',
                      style: TextStyle(
                        color: Color(0xFFF9F9F9),
                        fontSize: (19.78).sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Pretendard Variable',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // 설명 텍스트
                  Container(
                    height: 78.h,
                    alignment: Alignment.topCenter,
                    child: Text(
                      '카테고리를 나가면, 해당 카테고리에 저장된 사진은 더 이상 확인할 수 없으며 복구가 불가능합니다.',
                      style: TextStyle(
                        color: Color(0xFFF9F9F9),
                        fontSize: (15.78).sp,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Pretendard Variable',
                        height: 1.66,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: 12.h), // 여백 조정
                  // 나가기 버튼
                  Container(
                    width: (185.55).w,
                    height: 38.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F9), // 흰색 배경
                      borderRadius: BorderRadius.circular(14.22),
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onConfirm();
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.22),
                        ),
                      ),
                      child: Text(
                        '나가기',
                        style: TextStyle(
                          color: Color(0xFF000000), // 검은색 텍스트
                          fontSize: (17.78).sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Pretendard Variable',
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 13.h), // 버튼 간 간격
                  // 취소 버튼
                  Container(
                    width: (185.55).w,
                    height: 38.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A5A5A), // 회색 배경
                      borderRadius: BorderRadius.circular(14.22),
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.22),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          color: Color(0xFFCCCCCC), // 연한 회색 텍스트
                          fontSize: (17.78).sp,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Pretendard Variable',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
