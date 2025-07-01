import 'package:flutter/material.dart';

/// 카테고리 추가 UI 위젯
///
/// 새로운 카테고리를 생성하는 인터페이스를 제공합니다.
class AddCategoryWidget extends StatelessWidget {
  final TextEditingController textController;
  final ScrollController scrollController;

  const AddCategoryWidget({
    super.key,
    required this.textController,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    //final screenWidth = MediaQuery.of(context).size.width;
    //final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 카테고리 이름 입력 필드
        ElevatedButton.icon(
          onPressed: () {
            // 친구 추가하기 로직
          },
          icon: Image.asset('assets/person_add.png', width: 17, height: 17),
          label: Text(
            '친구 추가하기',
            style: TextStyle(color: Color(0xffE2E2E2), fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xff323232),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.5),
            ),
            elevation: 0,
            minimumSize: Size(117, 30), // 버튼 크기 조정
          ),
        ),
        TextField(
          controller: textController,
          cursorColor: Color(0xffcccccc),
          style: TextStyle(
            color: Color(0xffcccccc), // 입력 글자색 지정
          ),
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
        const SizedBox(height: 20),

        // 선택된 메이트 보여주기 영역 (필요시 구현)
      ],
    );
  }
}
