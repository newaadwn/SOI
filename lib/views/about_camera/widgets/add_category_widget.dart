import 'package:flutter/material.dart';

/// 카테고리 추가 UI 위젯
///
/// 새로운 카테고리를 생성하는 인터페이스를 제공합니다.
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
      color: Color(0xFF171717), // 피그마 배경색
      child: Column(
        children: [
          // 네비게이션 헤더
          Container(
            padding: EdgeInsets.only(left: 12, right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 뒤로가기 버튼
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: Color(0xFFD9D9D9),
                    size: 20,
                  ),
                  onPressed: onBackPressed,
                ),

                // 제목
                Text(
                  '새 카테고리 만들기',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                    letterSpacing: -0.4,
                  ),
                ),

                // 저장 버튼
                SizedBox(
                  width: 51,
                  height: 25,
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
                        fontSize: 14,
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
          Divider(
            height: 1,
            color: Color(0xFF323232), // 피그마 구분선 색상
          ),

          // 메인 컨텐츠 영역
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 친구 추가하기 버튼
                    SizedBox(
                      width: 109,
                      height: 35,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 친구 추가하기 로직
                        },
                        icon: Image.asset(
                          'assets/person_add.png',
                          width: 17,
                          height: 17,
                          color: Color(0xFFE2E2E2),
                        ),
                        label: Text(
                          '친구 추가하기',
                          style: TextStyle(
                            color: Color(0xFFE2E2E2),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF323232),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.5),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
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
                            fontSize: 16,
                          ),

                          decoration: InputDecoration(
                            border: UnderlineInputBorder(
                              borderSide: BorderSide.none,
                            ),

                            hintText: '카테고리 이름을 입력하세요',
                            hintStyle: TextStyle(
                              color: Color(0xFFCCCCCC),
                              fontSize: 16,
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

                        SizedBox(height: 8),

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
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Pretendard',
                                    letterSpacing: -0.4,
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
