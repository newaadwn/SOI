import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// 카테고리 추가 UI 위젯
// 새로운 카테고리를 생성하는 인터페이스를 제공합니다.
class AddCategoryWidget extends StatelessWidget {
  final TextEditingController textController;
  final ScrollController scrollController;
  final VoidCallback onBackPressed;
  final VoidCallback onSavePressed;

  const AddCategoryWidget({
    super.key,
    required this.textController,
    required this.scrollController,
    required this.onBackPressed,
    required this.onSavePressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      color: Color(0xFF171717),
      child: Column(
        children: [
          // 네비게이션 헤더
          Container(
            padding: EdgeInsets.only(left: 12.w, right: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 뒤로가기 버튼
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFFD9D9D9),
                    size: 20.sp,
                  ),
                  onPressed: onBackPressed,
                ),

                // 제목
                Text(
                  '새 카테고리 만들기',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                    letterSpacing: -0.4,
                  ),
                ),

                // 저장 버튼
                SizedBox(
                  width: 51.w,
                  height: 35.h,
                  child: ElevatedButton(
                    onPressed: onSavePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF323232),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.5),
                      ),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      '저장',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 구분선
          Divider(height: 1, color: Color(0xFF323232)),

          // 메인 컨텐츠 영역
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 친구 추가하기 버튼
                    SizedBox(
                      width: 129.w,
                      height: 30.h,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigator 호출을 안전하게 처리
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              Navigator.pushNamed(context, '/friend_list_add');
                            }
                          });
                        },
                        icon: Image.asset(
                          'assets/person_add.png',
                          width: 17.w,
                          height: 17.h,
                          color: Color(0xFFE2E2E2),
                        ),
                        label: Text(
                          '친구 추가하기',
                          style: TextStyle(
                            color: Color(0xFFE2E2E2),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF323232),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.5),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 6.h,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: screenHeight * (14 / 852)),

                    // 텍스트 입력 영역
                    Column(
                      children: [
                        // 입력 필드
                        TextField(
                          controller: textController,
                          cursorColor: Color(0xFFCCCCCC),
                          style: TextStyle(
                            color: Color(0xFFCCCCCC),
                            fontSize: 16.sp,
                          ),

                          decoration: InputDecoration(
                            border: UnderlineInputBorder(
                              borderSide: BorderSide.none,
                            ),

                            hintText: '카테고리 이름을 입력하세요',
                            hintStyle: TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 16.sp,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                          maxLength: 20,
                          buildCounter: (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) {
                            return null; // 기본 카운터 숨김
                          },
                        ),

                        SizedBox(height: 8.h),

                        // 글자 수 카운터
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: textController,
                              builder: (context, value, child) {
                                return Text(
                                  '${value.text.length}/20자',
                                  style: TextStyle(
                                    color: Color(0xFFCCCCCC),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Pretendard',
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
