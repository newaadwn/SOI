import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../controllers/emoji_reaction_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../about_emoji/emoji_overay_manager.dart';

class LikeButton extends StatefulWidget {
  final String photoId;
  final String categoryId; // Firestore 경로 계산용

  const LikeButton({
    super.key,
    required this.photoId,
    required this.categoryId,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  final GlobalKey _buttonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      final userId = auth.getUserId;
      if (userId != null && userId.isNotEmpty) {
        final reactionController = context.read<EmojiReactionController>();
        // 이미 메모리에 없으면 서버에서 로드
        if (reactionController.getPhotoReaction(widget.photoId) == null) {
          await reactionController.loadUserReactionForPhoto(
            categoryId: widget.categoryId,
            photoId: widget.photoId,
            userId: userId,
          );
        }
      }
      // 초기 로드 완료 후 별도 상태 사용 불필요
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EmojiReactionController>(
      builder: (context, reactionController, child) {
        final selectedReaction = reactionController.getPhotoReaction(
          widget.photoId,
        );
        final hasReaction = selectedReaction != null;

        return GestureDetector(
          key: _buttonKey,
          onTap: () async {
            final auth = context.read<AuthController>();
            final userId = auth.getUserId;
            if (userId == null || userId.isEmpty) return; // 로그인 전

            if (hasReaction) {
              reactionController.removePhotoReaction(
                categoryId: widget.categoryId,
                photoId: widget.photoId,
                userId: userId,
              );
            } else {
              // 사용자 메타 미리 로드
              String userHandle = '';
              String userName = '';
              try {
                userHandle = await auth.getUserID();
              } catch (_) {}
              try {
                userName = await auth.getUserName();
              } catch (_) {}
              EmojiOverlayManager.showEmojiPicker(
                context: context,
                buttonKey: _buttonKey,
                onEmojiSelected: (emoji) async {
                  String profileUrl = '';
                  try {
                    profileUrl = await auth.getUserProfileImageUrl();
                  } catch (_) {}
                  reactionController.setPhotoReaction(
                    categoryId: widget.categoryId,
                    photoId: widget.photoId,
                    userId: userId,
                    userHandle: userHandle,
                    userName: userName,
                    profileImageUrl: profileUrl,
                    reaction: emoji,
                  );
                },
              );
            }
          },
          child: SizedBox(
            width: 40.w,
            height: 40.h,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder:
                    (widget, anim) =>
                        ScaleTransition(scale: anim, child: widget),
                child:
                    hasReaction
                        ? Text(
                          selectedReaction.emoji,
                          key: const ValueKey('emoji'),
                          style: TextStyle(fontSize: 33.sp),
                        )
                        : Image.asset(
                          'assets/like_icon.png',
                          key: const ValueKey('like_icon'),
                          width: 33.w,
                          height: 33.h,
                        ),
              ),
            ),
          ),
        );
      },
    );
  }
}
