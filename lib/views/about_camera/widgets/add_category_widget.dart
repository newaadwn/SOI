import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/selected_friend_model.dart';
import '../../about_friends/friend_list_add_screen.dart';

// 카테고리 추가 UI 위젯
// 새로운 카테고리를 생성하는 인터페이스를 제공합니다.
class AddCategoryWidget extends StatefulWidget {
  final TextEditingController textController;
  final ScrollController scrollController;
  final VoidCallback onBackPressed;
  final Function(List<SelectedFriendModel>) onSavePressed;

  const AddCategoryWidget({
    super.key,
    required this.textController,
    required this.scrollController,
    required this.onBackPressed,
    required this.onSavePressed,
  });

  @override
  State<AddCategoryWidget> createState() => _AddCategoryWidgetState();
}

class _AddCategoryWidgetState extends State<AddCategoryWidget> {
  // 선택된 친구들 상태 관리
  List<SelectedFriendModel> _selectedFriends = [];

  void _handleSavePressed() {
    widget.onSavePressed(_selectedFriends);
  }

  Future<void> _handleAddFriends() async {
    // Navigator.push로 결과값 받기
    final result = await Navigator.push<List<SelectedFriendModel>>(
      context,
      MaterialPageRoute(builder: (context) => const FriendListAddScreen()),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _selectedFriends = result;
      });

      debugPrint('=== 선택된 친구 정보 수신 ===');
      debugPrint('선택된 친구 수: ${_selectedFriends.length}');
      for (final friend in _selectedFriends) {
        debugPrint('- ${friend.name} (${friend.uid})');
      }
    }
  }

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
                  onPressed: widget.onBackPressed,
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
                    onPressed: _handleSavePressed,
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
              controller: widget.scrollController,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedFriends.isEmpty)
                      // 친구 추가하기 버튼
                      SizedBox(
                        width: 129.w,
                        height: 30.h,
                        child: ElevatedButton.icon(
                          onPressed: _handleAddFriends,
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

                    // 선택된 친구들 표시
                    if (_selectedFriends.isNotEmpty) ...[
                      SizedBox(height: 16.h),
                      _buildOverlappingProfilesWidget(),
                    ],

                    SizedBox(height: screenHeight * (14 / 852)),

                    // 텍스트 입력 영역
                    Column(
                      children: [
                        // 입력 필드
                        TextField(
                          controller: widget.textController,
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
                              valueListenable: widget.textController,
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

  // 겹쳐지는 프로필 이미지들과 + 버튼을 표시하는 위젯
  Widget _buildOverlappingProfilesWidget() {
    // 최대 4개의 프로필만 표시 (5번째는 + 버튼)
    final displayFriends = _selectedFriends.take(4).toList();
    final hasMoreFriends = _selectedFriends.length > 4;

    // 전체 너비 계산: 첫 번째 프로필(24) + 겹치는 부분들(16 * 개수) + + 버튼(24)
    final totalProfiles =
        displayFriends.length +
        (hasMoreFriends || displayFriends.length < 5 ? 1 : 0);
    final containerWidth = 24.0 + (totalProfiles - 1) * 16.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Color(0xFF323232),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 겹쳐지는 프로필 이미지들
          SizedBox(
            height: 24.h,
            width: containerWidth,
            child: Stack(
              children: [
                // 친구 프로필들
                ...displayFriends.asMap().entries.map((entry) {
                  final index = entry.key;
                  final friend = entry.value;

                  return Positioned(
                    left: index * 16.0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Color(0xFF323232), width: 1),
                      ),
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Color(0xFF404040),
                        backgroundImage:
                            friend.profileImageUrl != null
                                ? NetworkImage(friend.profileImageUrl!)
                                : null,
                        child:
                            friend.profileImageUrl == null
                                ? Text(
                                  friend.name.isNotEmpty
                                      ? friend.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Color(0xFFE2E2E2),
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                                : null,
                      ),
                    ),
                  );
                }),

                // + 버튼 (항상 표시)
                Positioned(
                  left: displayFriends.length * 16.0,
                  child: GestureDetector(
                    onTap: _handleAddFriends,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF404040),
                        border: Border.all(color: Color(0xFF323232), width: 1),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Color(0xFFE2E2E2),
                        size: 14.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
