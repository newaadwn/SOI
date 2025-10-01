import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CategoryInviteePreview {
  final String id;
  final String name;
  final String profileImageUrl;

  const CategoryInviteePreview({
    required this.id,
    required this.name,
    required this.profileImageUrl,
  });
}

class CategoryInviteConfirmSheet extends StatelessWidget {
  final String categoryName;
  final String categoryImageUrl;
  final List<CategoryInviteePreview> invitees;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  const CategoryInviteConfirmSheet({
    super.key,
    required this.categoryName,
    required this.categoryImageUrl,
    required this.invitees,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(100.r),
              ),
            ),
            SizedBox(height: 24.h),
            _buildCategoryThumbnail(),
            SizedBox(height: 18.h),
            if (invitees.isNotEmpty) _buildInviteeRow(),
            if (invitees.isNotEmpty) SizedBox(height: 24.h),
            Text(
              '"$categoryName" 카테고리에 초대되었습니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              '모르는 친구가 추가되어 있는 카테고리입니다.\n수락하시겠습니까?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFC4C4C4),
                fontSize: 14.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                letterSpacing: -0.25,
              ),
            ),
            SizedBox(height: 28.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                ),
                child: Text(
                  '수락',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            TextButton(
              onPressed: onCancel,
              child: Text(
                '취소',
                style: TextStyle(
                  color: const Color(0xFFC4C4C4),
                  fontSize: 16.sp,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryThumbnail() {
    return Container(
      width: 76.w,
      height: 76.w,
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: categoryImageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: categoryImageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => _placeholder(),
                errorWidget: (context, url, error) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF3A3A3A),
      child: Icon(
        Icons.image_outlined,
        color: const Color(0xFF8E8E8E),
        size: 28.sp,
      ),
    );
  }

  Widget _buildInviteeRow() {
    return SizedBox(
      height: 94.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: invitees.length,
        separatorBuilder: (_, __) => SizedBox(width: 14.w),
        itemBuilder: (context, index) {
          final invitee = invitees[index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInviteeAvatar(invitee),
              SizedBox(height: 8.h),
              SizedBox(
                width: 72.w,
                child: Text(
                  invitee.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFCFCFCF),
                    fontSize: 12.sp,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInviteeAvatar(CategoryInviteePreview invitee) {
    return Container(
      width: 56.w,
      height: 56.w,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: invitee.profileImageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: invitee.profileImageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => _avatarPlaceholder(),
                errorWidget: (context, url, error) => _avatarPlaceholder(),
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: const Color(0xFF3A3A3A),
      child: Icon(
        Icons.person,
        size: 24.sp,
        color: const Color(0xFF858585),
      ),
    );
  }
}
