import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/audio_controller.dart';
import '../../../models/photo_data_model.dart';
import '../../../models/comment_record_model.dart';

class DroppedProfileWidget extends StatelessWidget {
  final PhotoDataModel photo;
  final Offset position;
  final double cardWidth;
  final double cardHeight;
  final Map<String, List<CommentRecordModel>> photoComments;
  final Map<String, String> commentProfileImageUrls;
  final double topOffset;

  const DroppedProfileWidget({
    super.key,
    required this.photo,
    required this.position,
    required this.cardWidth,
    required this.cardHeight,
    required this.photoComments,
    required this.commentProfileImageUrls,
    this.topOffset = 20.5,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: (position.dx - 13.5).clamp(0, cardWidth - 27),
      top: (position.dy - 13.5 - topOffset).clamp(0, cardHeight - 27),
      child: Consumer<AuthController>(
        builder: (context, authController, child) {
          final currentUserId = authController.currentUser?.uid;
          final comments = photoComments[photo.id] ?? [];

          String? profileImageUrl;
          String? audioUrl;

          // 댓글에서 프로필 이미지 URL 사용
          profileImageUrl = commentProfileImageUrls[photo.id];

          // 실시간 댓글에서 audioUrl 찾기
          for (var comment in comments) {
            if (comment.recorderUser == currentUserId &&
                comment.profilePosition != null) {
              audioUrl = comment.audioUrl;
              break;
            }
          }

          return InkWell(
            onTap: () async {
              if (audioUrl != null && audioUrl.isNotEmpty) {
                try {
                  debugPrint('프로필 이미지 클릭됨 - 음성 재생 시작');
                  final audioController = Provider.of<AudioController>(
                    context,
                    listen: false,
                  );
                  await audioController.toggleAudio(audioUrl);
                } catch (e) {
                  debugPrint('❌ 음성 재생 실패: $e');
                }
              } else {
                debugPrint('❌ 재생할 audioUrl이 없습니다');
              }
            },
            child: Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child:
                  (profileImageUrl?.isNotEmpty ?? false)
                      ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: profileImageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        ),
                      )
                      : _buildPlaceholder(),
            ),
          );
        },
      ),
    );
  }

  /// 플레이스홀더 위젯
  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[700],
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 14),
    );
  }
}
