import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/controllers/category_member_controller.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../models/category_data_model.dart';

class ExitButton extends StatelessWidget {
  final CategoryDataModel category;

  const ExitButton({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62.h,
      child: ElevatedButton(
        onPressed: () => _showExitDialog(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1c1c1c),
          foregroundColor: Color(0xffff0000),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/log_out.png', width: 24.w, height: 24.h),
            SizedBox(width: 12.w),
            Text(
              '나가기',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard Variable',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1c1c1c),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '카테고리 나가기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              fontFamily: 'Pretendard Variable',
            ),
          ),
          content: Text(
            '정말로 이 카테고리에서 나가시겠습니까?\n나가면 이 카테고리의 사진들을 더 이상 볼 수 없습니다.',
            style: TextStyle(
              color: const Color(0xFFCCCCCC),
              fontSize: 14.sp,
              fontFamily: 'Pretendard Variable',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(
                  color: const Color(0xFFcccccc),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Pretendard Variable',
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                // 다이얼로그 닫기 전에 BuildContext를 저장
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                navigator.pop(); // 다이얼로그 닫기

                // 실제 카테고리 나가기 로직 수행
                final categoryController =
                    context.read<CategoryMemberController>();
                final authController = context.read<AuthController>();
                final userId = authController.getUserId;

                if (userId != null) {
                  await categoryController.leaveCategoryByUid(
                    category.id,
                    userId,
                  );

                  if (categoryController.error == null) {
                    // 성공 시 홈 화면의 아카이브 탭으로 이동

                    navigator.popUntil((route) => route.isFirst);
                  }
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('사용자 정보를 확인할 수 없습니다.'),
                      backgroundColor: Color(0xFFcccccc),
                    ),
                  );
                }
              },
              child: Text(
                '나가기',
                style: TextStyle(
                  color: const Color(0xff000000),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Pretendard Variable',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
