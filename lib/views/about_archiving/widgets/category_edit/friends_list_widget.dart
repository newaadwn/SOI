import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../models/category_data_model.dart';
import '../../../../models/auth_model.dart';
import '../../../about_friends/friend_list_screen.dart';

class FriendsListWidget extends StatelessWidget {
  final CategoryDataModel category;
  final Map<String, AuthModel> friendsInfo;
  final bool isLoadingFriends;
  final bool isExpanded;
  final VoidCallback onExpandToggle;
  final VoidCallback onCollapseToggle;

  const FriendsListWidget({
    super.key,
    required this.category,
    required this.friendsInfo,
    required this.isLoadingFriends,
    required this.isExpanded,
    required this.onExpandToggle,
    required this.onCollapseToggle,
  });

  @override
  Widget build(BuildContext context) {
    // 최대 2개까지만 표시 (나머지는 "+더보기"로 표시)
    const int maxDisplayCount = 2;
    final totalMates = category.mates.length;
    final displayMates =
        isExpanded
            ? category.mates
            : category.mates.take(maxDisplayCount).toList();
    final hasMore = totalMates > maxDisplayCount && !isExpanded;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1c),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '카테고리 친구 ${totalMates}명',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Pretendard Variable',
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              FriendListScreen(categoryId: category.id),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2a2a2a),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '편집',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Pretendard Variable',
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // 로딩 상태 표시
          if (isLoadingFriends) ...[
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              ),
            ),
          ] else ...[
            // 친구 목록
            for (int i = 0; i < displayMates.length; i++) ...[
              _FriendItem(
                mateUid: displayMates[i],
                friendInfo: friendsInfo[displayMates[i]],
              ),
              if (i < displayMates.length - 1) SizedBox(height: 23.h),
            ],

            // "+더보기" 항목
            if (hasMore) ...[
              SizedBox(height: 8.h),
              GestureDetector(
                onTap: onExpandToggle,
                child: Column(
                  children: [
                    Divider(color: const Color(0xFF666666)),
                    SizedBox(height: 13.h),
                    Text(
                      '+ 더보기',
                      style: TextStyle(
                        color: const Color(0xFFCCCCCC),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Pretendard Variable',
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // "접기" 버튼 (확장된 상태에서만 표시)
            if (isExpanded && totalMates > maxDisplayCount) ...[
              SizedBox(height: 8.h),
              GestureDetector(
                onTap: onCollapseToggle,
                child: Row(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF444444),
                        border: Border.all(
                          color: const Color(0xFF666666),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      '접기',
                      style: TextStyle(
                        color: const Color(0xFFCCCCCC),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Pretendard Variable',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FriendItem extends StatelessWidget {
  final String mateUid;
  final AuthModel? friendInfo;

  const _FriendItem({required this.mateUid, required this.friendInfo});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 프로필 이미지
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF666666),
          ),
          child:
              friendInfo?.profileImage != null &&
                      friendInfo!.profileImage.isNotEmpty
                  ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: friendInfo!.profileImage,
                      width: 40.w,
                      height: 40.w,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF666666),
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF666666),
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                          ),
                    ),
                  )
                  : Icon(Icons.person, color: Colors.white, size: 20.sp),
        ),
        SizedBox(width: 12.w),
        // 친구 이름/ID
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 이름
              Text(
                friendInfo?.name ?? '이름을 알 수 없습니다.!',
                style: TextStyle(
                  color: Color(0xffd9d9d9),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Pretendard Variable',
                ),
                overflow: TextOverflow.ellipsis,
              ),
              // ID
              Text(
                friendInfo?.id ?? mateUid,
                style: TextStyle(
                  color: const Color(0xFFAAAAAA),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Pretendard Variable',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
