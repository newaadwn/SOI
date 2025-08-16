import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../controllers/friend_controller.dart';
import '../../models/friend_model.dart';

class FriendListScreen extends StatefulWidget {
  final String? categoryId;

  const FriendListScreen({super.key, this.categoryId});

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  // 선택된 친구들의 UID를 저장하는 Set
  final Set<String> _selectedFriendUids = <String>{};

  // 검색 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  // 각 친구별 MenuController를 저장하는 Map
  final Map<String, MenuController> _menuControllers = {};

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    // FriendController 초기화 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final friendController = context.read<FriendController>();
      if (!friendController.isInitialized) {
        friendController.initialize();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _toggleFriendSelection(String friendUid) {
    setState(() {
      if (_selectedFriendUids.contains(friendUid)) {
        _selectedFriendUids.remove(friendUid);
      } else {
        _selectedFriendUids.add(friendUid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xffd9d9d9)),
        title: Text(
          widget.categoryId != null ? '카테고리에 친구 추가' : '친구 목록',
          style: TextStyle(
            color: const Color(0xfff9f9f9),
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: false,
      ),
      body: Consumer<FriendController>(
        builder: (context, friendController, child) {
          // 검색어에 따라 실시간으로 친구 목록 필터링
          final query = _searchController.text.toLowerCase();
          final displayFriends =
              query.isEmpty
                  ? friendController.friends
                  : friendController.friends.where((friend) {
                    return friend.name.toLowerCase().contains(query) ||
                        friend.id.toLowerCase().contains(query);
                  }).toList();

          return Column(
            children: [
              // 검색 바
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Container(
                  width: double.infinity,
                  height: 47.h,
                  decoration: BoxDecoration(
                    color: const Color(0xff292929),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 16.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: '친구 검색하기',
                      hintStyle: TextStyle(
                        color: const Color(0xffd9d9d9),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Pretendard',
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: const Color(0xffd9d9d9),
                        size: 24.w,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 38.h),
              Row(
                children: [
                  SizedBox(width: 27.w),
                  Icon(Icons.people_alt_outlined, size: 21.sp),
                  SizedBox(width: 11.w),
                  Text(
                    "친구 목록",
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              // 친구 목록
              friendController.isLoading
                  ? Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                  : !friendController.isInitialized
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16.h),
                        Text(
                          '친구 목록을 불러오는 중...',
                          style: TextStyle(
                            color: const Color(0xff666666),
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                  : displayFriends.isEmpty
                  ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? '친구가 없습니다'
                          : '검색 결과가 없습니다',
                      style: TextStyle(
                        color: const Color(0xff666666),
                        fontSize: 16.sp,
                      ),
                    ),
                  )
                  : Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xffadadad).withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          SizedBox(height: (13).h),
                          // 친구 목록
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children:
                                displayFriends.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final friend = entry.value;
                                  final isSelected = _selectedFriendUids
                                      .contains(friend.userId);

                                  return _buildFriendItem(
                                    friend: friend,
                                    isSelected: isSelected,
                                    index: index,
                                    isLast: index == displayFriends.length - 1,
                                    onTap:
                                        () => _toggleFriendSelection(
                                          friend.userId,
                                        ),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFriendItem({
    required FriendModel friend,
    required bool isSelected,
    required int index,
    required bool isLast,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
            child: Row(
              children: [
                // 프로필 이미지
                SizedBox(
                  width: 44,
                  height: 44,
                  child: CircleAvatar(
                    radius: 24.r,
                    backgroundColor: const Color(0xff323232),
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
                                color: const Color(0xfff9f9f9),
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                            : null,
                  ),
                ),
                SizedBox(width: 12.w),

                // 친구 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.name,
                        style: TextStyle(
                          color: const Color(0xfff9f9f9),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        friend.id,
                        style: TextStyle(
                          color: const Color(0xff999999),
                          fontSize: 14.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                MenuAnchor(
                  style: MenuStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                    shadowColor: WidgetStatePropertyAll(Colors.transparent),

                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9.14),
                      ),
                    ),
                  ),
                  builder: (
                    BuildContext context,
                    MenuController controller,
                    Widget? child,
                  ) {
                    // 각 친구별로 MenuController 저장
                    _menuControllers[friend.userId] = controller;
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: IconButton(
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        icon: Icon(
                          Icons.more_vert,
                          size: 25.sp,
                          color: Color(0xfff9f9f9),
                        ),
                      ),
                    );
                  },
                  menuChildren: [_menuItem(friend.userId)],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuItem(String friendUserId) {
    return MenuItemButton(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9.14),
            side: BorderSide.none,
          ),
        ),
      ),
      child: Container(
        width: 173.w,
        height: 88.h,

        decoration: BoxDecoration(
          color: Color(0xff323232),
          borderRadius: BorderRadius.circular(9.14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () {
                debugPrint("친구 삭제");
                // 해당 친구의 MenuController를 찾아서 닫기
                final controller = _menuControllers[friendUserId];
                if (controller != null && controller.isOpen) {
                  controller.close();
                }
              },
              child: Row(
                children: [
                  SizedBox(width: 13.96.w),
                  Image.asset(
                    'assets/trash_bin.png',

                    width: 11.16.sp,
                    height: 12.56.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '친구 삭제',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.3517.sp,
                      fontFamily: "Pretendard",
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Color(0xff5a5a5a)),
            InkWell(
              onTap: () {
                debugPrint("차단");
                // 해당 친구의 MenuController를 찾아서 닫기
                final controller = _menuControllers[friendUserId];
                if (controller != null && controller.isOpen) {
                  controller.close();
                }
              },
              child: Row(
                children: [
                  SizedBox(width: 13.96.w),
                  Image.asset(
                    'assets/block.png',

                    width: 11.16.sp,
                    height: 12.56.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '차단',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 15.3517.sp,
                      fontFamily: "Pretendard",
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
