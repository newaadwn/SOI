import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/selected_friend_model.dart';

/// 선택된 친구들의 프로필 이미지를 겹쳐서 표시하는 위젯
/// 최대 4개의 프로필 이미지를 표시합니다.
class OverlappingProfilesWidget extends StatelessWidget {
  final List<SelectedFriendModel> selectedFriends;
  final VoidCallback? onAddPressed;
  final double profileSize;
  final double overlapDistance;
  final bool showAddButton;

  const OverlappingProfilesWidget({
    super.key,
    required this.selectedFriends,
    this.onAddPressed,
    this.profileSize = 27.0,
    this.overlapDistance = 16.0,
    this.showAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    // 최대 4개의 프로필만 표시
    final displayFriends = selectedFriends.take(3).toList();

    // 전체 너비 계산: 첫 번째 프로필(profileSize) + 겹치는 부분들(overlapDistance * 개수) + (+ 버튼이 있다면 추가)
    final totalProfiles =
        displayFriends.length +
        (showAddButton && displayFriends.length < 4 ? 1 : 0);
    final containerWidth = profileSize + (totalProfiles - 1) * overlapDistance;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Color(0xFF323232),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 겹쳐지는 프로필 이미지들
          SizedBox(
            height: profileSize,
            width: containerWidth,
            child: Stack(
              children: [
                // 친구 프로필들
                ...displayFriends.asMap().entries.map((entry) {
                  final index = entry.key;
                  final friend = entry.value;

                  return Positioned(
                    left: (index * overlapDistance).w,
                    child: Container(
                      width: profileSize,
                      height: profileSize,
                      decoration: BoxDecoration(shape: BoxShape.circle),
                      child: CircleAvatar(
                        backgroundColor: Color(0xFF404040),
                        backgroundImage:
                            friend.profileImageUrl != null
                                ? CachedNetworkImageProvider(
                                  friend.profileImageUrl!,
                                )
                                : null,
                        child:
                            friend.profileImageUrl == null
                                ? Text(
                                  friend.name.isNotEmpty
                                      ? friend.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: Color(0xFFE2E2E2),
                                    fontSize: (profileSize * 0.33).sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                                : null,
                      ),
                    ),
                  );
                }),

                // + 버튼 (showAddButton이 true일 때만 표시)
                if (showAddButton && onAddPressed != null)
                  Positioned(
                    left: (displayFriends.length * overlapDistance).w,
                    child: GestureDetector(
                      onTap: onAddPressed,
                      child: Container(
                        width: profileSize,
                        height: profileSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF5a5a5a),
                        ),
                        child: Image.asset("assets/plus_container.png"),
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
