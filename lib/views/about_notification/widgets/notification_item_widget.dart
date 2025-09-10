import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/notification_model.dart';

/// 개별 알림 아이템 위젯
class NotificationItemWidget extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isLast;

  const NotificationItemWidget({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(left: 18.w, right: 18.w, bottom: 28.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileImage(),
            SizedBox(width: 9.w),
            Expanded(child: _buildNotificationText()),
            SizedBox(width: 23.w),
            _buildThumbnail(),
          ],
        ),
      ),
    );
  }

  /// 프로필 이미지 구성
  Widget _buildProfileImage() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: notification.actorProfileImage ?? '',
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder:
              (context, url) => Container(
                color: Colors.grey[700],
                child: Icon(Icons.person, size: 20.sp, color: Colors.grey[500]),
              ),
          errorWidget:
              (context, url, error) => Container(
                color: Colors.grey[700],
                child: Icon(Icons.person, size: 20.sp, color: Colors.grey[500]),
              ),
        ),
      ),
    );
  }

  /// 알림 텍스트 구성
  Widget _buildNotificationText() {
    final userName = notification.actorName ?? '사용자';
    final remainingText = _getNotificationText();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: userName,
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 14,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.40,
                ),
              ),
              TextSpan(
                text: remainingText,
                style: TextStyle(
                  color: const Color(0xFFD9D9D9),
                  fontSize: 14,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.40,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 썸네일 이미지 구성
  Widget _buildThumbnail() {
    switch (notification.type) {
      case NotificationType.categoryInvite:
        return _buildCategoryThumbnail();
      case NotificationType.photoAdded:
        return _buildPhotoThumbnail();
      case NotificationType.voiceCommentAdded:
        return _buildVoiceCommentThumbnail();
    }
  }

  /// 카테고리 썸네일
  Widget _buildCategoryThumbnail() {
    final categoryImageUrl = notification.categoryThumbnailUrl;

    return Container(
      width: 44.w,
      height: 44.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: Colors.grey[700],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child:
            categoryImageUrl != null && categoryImageUrl.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: categoryImageUrl,
                  width: 44.w,
                  height: 44.h,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildCategoryIcon(),
                )
                : _buildCategoryIcon(),
      ),
    );
  }

  /// 사진 썸네일
  Widget _buildPhotoThumbnail() {
    final thumbnailUrl = notification.photoThumbnailUrl;

    return Container(
      width: 44.w,
      height: 44.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: Colors.grey[700],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child:
            thumbnailUrl != null && thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  width: 44.w,
                  height: 44.h,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildPlaceholder(),
                  errorWidget: (context, url, error) => _buildPhotoIcon(),
                )
                : _buildPhotoIcon(),
      ),
    );
  }

  /// 음성 댓글 썸네일
  Widget _buildVoiceCommentThumbnail() {
    return SizedBox(
      width: 44.w,
      height: 44.h,
      child: ClipRRect(
        child: Image.asset(
          "assets/record_notification_icon.png",
          width: 44.w,
          height: 44.h,
        ),
      ),
    );
  }

  /// 알림 타입별 텍스트 반환
  String _getNotificationText() {
    switch (notification.type) {
      case NotificationType.categoryInvite:
        return '님이 새 카테고리에 초대했습니다.';
      case NotificationType.photoAdded:
        return '님이 "${notification.categoryName}" 카테고리에 사진을 추가하였습니다.';
      case NotificationType.voiceCommentAdded:
        return '님이 음성 댓글을 달았습니다.';
    }
  }

  /// 공통 위젯들
  Widget _buildCategoryIcon() {
    return Icon(
      Icons.folder_outlined,
      size: 24.sp,
      color: const Color(0xff634D45),
    );
  }

  Widget _buildPhotoIcon() {
    return Icon(Icons.photo_outlined, size: 24.sp, color: Colors.blue[400]!);
  }

  Widget _buildPlaceholder() {
    return Container(color: Colors.grey[700]);
  }
}
