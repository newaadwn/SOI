import 'package:flutter/material.dart';

/// 카테고리 추가 UI 위젯
///
/// 새로운 카테고리를 생성하는 인터페이스를 제공합니다.
class AddCategoryWidget extends StatelessWidget {
  final TextEditingController textController;
  final ScrollController scrollController;
  final String? hintText; // hintText 파라미터 추가

  const AddCategoryWidget({
    Key? key,
    required this.textController,
    required this.scrollController,
    this.hintText, // hintText 파라미터 추가
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 카테고리 이름 입력 필드
        ElevatedButton.icon(
          onPressed: () {
            // 친구 추가하기 로직
          },
          icon: Icon(Icons.person_add_alt, color: Color(0xffE2E2E2)),
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
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            hintText: hintText ?? '카테고리 이름을 입력해 주세요.', // 전달받은 hintText 사용
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 선택된 메이트 보여주기 영역 (필요시 구현)
      ],
    );
  }
}
