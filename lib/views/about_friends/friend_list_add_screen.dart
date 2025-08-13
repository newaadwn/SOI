import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../controllers/friend_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/friend_model.dart';
import '../../models/selected_friend_model.dart';

class FriendListAddScreen extends StatefulWidget {
  final String? categoryId; // 카테고리에 친구를 추가할 때 사용

  const FriendListAddScreen({super.key, this.categoryId});

  @override
  State<FriendListAddScreen> createState() => _FriendListAddScreenState();
}

class _FriendListAddScreenState extends State<FriendListAddScreen> {
  // 선택된 친구들의 UID를 저장하는 Set
  final Set<String> _selectedFriendUids = <String>{};

  // 검색 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    debugPrint('=== FriendListAddScreen 초기화 ===');
    debugPrint('categoryId: ${widget.categoryId}');

    _searchController.addListener(_onSearchChanged);

    // FriendController 초기화 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final friendController = context.read<FriendController>();
      if (!friendController.isInitialized) {
        debugPrint('FriendController 초기화되지 않음 - 초기화 시작');
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
    setState(() {
      // 검색어 변경 시 UI만 업데이트 (상태는 저장하지 않음)
      debugPrint('검색어 변경: "${_searchController.text}"');
    });
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

  void _onConfirmPressed() async {
    if (widget.categoryId != null) {
      // 카테고리에 친구들 추가
      try {
        debugPrint('=== 친구 추가 시작 ===');
        debugPrint('categoryId: ${widget.categoryId}');
        debugPrint('선택된 친구 수: ${_selectedFriendUids.length}');
        debugPrint('선택된 친구 UIDs: $_selectedFriendUids');

        final categoryController = context.read<CategoryController>();

        // 선택된 각 친구의 UID를 카테고리 mates에 추가
        for (final friendUid in _selectedFriendUids) {
          debugPrint('친구 UID 추가 시도: $friendUid');
          await categoryController.addUidToCategory(
            widget.categoryId!,
            friendUid,
          );
          debugPrint('친구 UID 추가 완료: $friendUid');
        }

        debugPrint('=== 친구 추가 성공 ===');

        // CategoryController 강제 새로고침 - 즉시 UI 업데이트를 위해
        final authController = context.read<AuthController>();
        final userId = authController.getUserId;
        if (userId != null) {
          await categoryController.loadUserCategories(
            userId,
            forceReload: true,
          );
          debugPrint('CategoryController 강제 새로고침 완료');
        }

        if (mounted) {
          // 성공 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_selectedFriendUids.length}명의 친구가 카테고리에 추가되었습니다.',
              ),
              backgroundColor: const Color(0xFF323232),
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigator 호출을 안전하게 처리
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      } catch (e) {
        debugPrint('=== 친구 추가 실패 ===');
        debugPrint('에러: $e');

        if (mounted) {
          // 에러 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('친구 추가 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // 단순히 선택된 친구들의 정보와 함께 이전 화면으로 돌아가기
      final friendController = context.read<FriendController>();
      final selectedFriends = <SelectedFriendModel>[];

      // 선택된 UID들을 기반으로 친구 정보 수집
      for (final uid in _selectedFriendUids) {
        final friend = friendController.friends.firstWhere(
          (friend) => friend.userId == uid,
          orElse:
              () => FriendModel(
                userId: uid,
                name: '알 수 없음',
                id: uid,
                status: FriendStatus.active,
                isFavorite: false,
                addedAt: DateTime.now(),
              ),
        );

        selectedFriends.add(
          SelectedFriendModel(
            uid: friend.userId,
            name: friend.name,
            profileImageUrl: friend.profileImageUrl,
          ),
        );
      }

      debugPrint('=== 선택된 친구 정보 반환 ===');
      debugPrint('선택된 친구 수: ${selectedFriends.length}');
      for (final friend in selectedFriends) {
        debugPrint('- ${friend.name} (${friend.uid})');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(selectedFriends);
        }
      });
    }
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
          // 디버깅: FriendController 상태 확인
          debugPrint('FriendListAddScreen - FriendController 상태:');
          debugPrint('- isInitialized: ${friendController.isInitialized}');
          debugPrint('- isLoading: ${friendController.isLoading}');
          debugPrint('- friends 개수: ${friendController.friends.length}');
          if (friendController.friends.isNotEmpty) {
            debugPrint('- 첫 번째 친구: ${friendController.friends.first.name}');
          }

          // 검색어에 따라 실시간으로 친구 목록 필터링
          final query = _searchController.text.toLowerCase();
          final displayFriends =
              query.isEmpty
                  ? friendController.friends
                  : friendController.friends.where((friend) {
                    return friend.name.toLowerCase().contains(query) ||
                        friend.id.toLowerCase().contains(query);
                  }).toList();

          debugPrint('- displayFriends 개수: ${displayFriends.length}');
          debugPrint('- 검색어: "${_searchController.text}"');

          return Column(
            children: [
              // 검색 바
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Container(
                  width: double.infinity,
                  height: 47.h,
                  decoration: BoxDecoration(
                    color: const Color(0xff1e1e1e),
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
              // 친구 목록
              friendController.isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                  : !friendController.isInitialized
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
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
                        color: const Color(0xff1c1c1c),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children:
                            displayFriends.asMap().entries.map((entry) {
                              final index = entry.key;
                              final friend = entry.value;
                              final isSelected = _selectedFriendUids.contains(
                                friend.userId,
                              );

                              return _buildFriendItem(
                                friend: friend,
                                isSelected: isSelected,
                                index: index,
                                isLast: index == displayFriends.length - 1,
                                onTap:
                                    () => _toggleFriendSelection(friend.userId),
                              );
                            }).toList(),
                      ),
                    ),
                  ),

              // 확인 버튼을 위한 여유 공간
              const Spacer(),

              // 확인 버튼
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                child: SizedBox(
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed:
                        _selectedFriendUids.isEmpty
                            ? null
                            : () {
                              debugPrint('확인 버튼 클릭됨');
                              _onConfirmPressed();
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _selectedFriendUids.isEmpty
                              ? const Color(0xff404040)
                              : const Color(0xffffffff),
                      foregroundColor:
                          _selectedFriendUids.isEmpty
                              ? const Color(0xff666666)
                              : const Color(0xff000000),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
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
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                // 프로필 이미지
                CircleAvatar(
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

                // 체크박스
                Container(
                  width: 24.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isSelected
                            ? const Color(0xffffffff)
                            : Colors.transparent,
                    border: Border.all(
                      color:
                          isSelected
                              ? const Color(0xffffffff)
                              : const Color(0xff666666),
                      width: 2,
                    ),
                  ),
                  child:
                      isSelected
                          ? Icon(
                            Icons.check,
                            color: const Color(0xff000000),
                            size: 16.w,
                          )
                          : null,
                ),
              ],
            ),
          ),
        ),
        // 구분선 (마지막 아이템이 아닌 경우에만)
        if (!isLast)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w),
            height: 1,
            color: const Color(0xff404040),
          ),
      ],
    );
  }
}
