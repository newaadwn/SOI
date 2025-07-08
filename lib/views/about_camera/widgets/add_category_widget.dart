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
    return Column(
      children: [
        // 헤더 영역
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: onBackPressed,
              ),
              Text(
                '새 카테고리 만들기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton(
                onPressed: onSavePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xff323232),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.5),
                  ),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text(
                  '저장',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: Color(0xff3d3d3d)),
        SizedBox(height: 12),

        // 스크롤 가능한 컨텐츠 영역
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    width: 17,
                    height: 17,
                  ),
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
                    minimumSize: Size(117, 30),
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
