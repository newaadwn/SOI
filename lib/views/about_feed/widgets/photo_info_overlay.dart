import 'package:flutter/material.dart';
import '../../../models/photo_data_model.dart';

class PhotoInfoOverlay extends StatelessWidget {
  final PhotoDataModel photo;
  final Map<String, String> userNames;
  final VoidCallback? onUserTap;

  const PhotoInfoOverlay({
    super.key,
    required this.photo,
    required this.userNames,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenHeight * 0.01,
      ),
      child: Row(
        children: [
          SizedBox(width: screenWidth * 0.032),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onUserTap,
                  child: Text(
                    '@${userNames[photo.userID] ?? photo.userID}', // @ 형식으로 표시
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.037,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _formatTimestamp(photo.createdAt),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: screenWidth * 0.032,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 타임스탬프 포맷팅
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${timestamp.year}.${timestamp.month.toString().padLeft(2, '0')}.${timestamp.day.toString().padLeft(2, '0')}';
    }
  }
}
