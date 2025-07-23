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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Column(
      children: [
        // 헤더 영역
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: (screenWidth * 0.051).clamp(18.0, 24.0), // 반응형 아이콘 크기
              ),
              onPressed: onBackPressed,
            ),
            Text(
              '새 카테고리 만들기',
              style: TextStyle(
                fontSize: (screenWidth * 0.041).clamp(14.0, 18.0), // 반응형 폰트 크기
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            ElevatedButton(
              onPressed: onSavePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff323232),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    (screenWidth * 0.042).clamp(14.0, 20.0),
                  ), // 반응형 반지름
                ),
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: (screenWidth * 0.051).clamp(16.0, 24.0), // 반응형 패딩
                  vertical: (screenHeight * 0.012).clamp(8.0, 12.0), // 반응형 패딩
                ),
              ),
              child: Text(
                '저장',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (screenWidth * 0.036).clamp(
                    12.0,
                    16.0,
                  ), // 반응형 폰트 크기
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Divider(color: Color(0xff3d3d3d)),
        SizedBox(height: (screenHeight * 0.014).clamp(10.0, 16.0)), // 반응형 간격
        // 스크롤 가능한 컨텐츠 영역
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: (screenWidth * 0.041).clamp(14.0, 20.0),
            ), // 반응형 패딩
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 친구 추가하기 버튼
                ElevatedButton.icon(
                  onPressed: () {
                    // 친구 추가하기 로직
                  },
                  icon: Image.asset(
                    'assets/person_add.png',
                    width: (screenWidth * 0.043).clamp(
                      15.0,
                      20.0,
                    ), // 반응형 아이콘 크기
                    height: (screenWidth * 0.043).clamp(
                      15.0,
                      20.0,
                    ), // 반응형 아이콘 크기
                  ),
                  label: Text(
                    '친구 추가하기',
                    style: TextStyle(
                      color: Color(0xffE2E2E2),
                      fontSize: (screenWidth * 0.036).clamp(
                        12.0,
                        16.0,
                      ), // 반응형 폰트 크기
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff323232),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        (screenWidth * 0.042).clamp(14.0, 20.0),
                      ), // 반응형 반지름
                    ),
                    elevation: 0,
                    minimumSize: Size(
                      (screenWidth * 0.298).clamp(100.0, 130.0), // 반응형 최소 너비
                      (screenHeight * 0.035).clamp(28.0, 35.0), // 반응형 최소 높이
                    ),
                  ),
                ),

                // 카테고리 이름 입력 필드
                TextField(
                  controller: textController,
                  cursorColor: Color(0xffcccccc),
                  style: TextStyle(color: Color(0xffcccccc)),
                  decoration: InputDecoration(
                    filled: false,
                    hintText: '카테고리 이름을 입력해 주세요.',
                    hintStyle: TextStyle(color: Color(0xffcccccc)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
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
