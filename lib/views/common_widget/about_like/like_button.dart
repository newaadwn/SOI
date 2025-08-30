import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../controllers/emoji_reaction_controller.dart';
import '../about_emoji/emoji_overay_manager.dart';

class LikeButton extends StatefulWidget {
  final String photoId;

  const LikeButton({required this.photoId});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  final GlobalKey _buttonKey = GlobalKey();

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

          onTap: () {
            if (hasReaction) {
              reactionController.removePhotoReaction(widget.photoId);
            } else {
              EmojiOverlayManager.showEmojiPicker(
                context: context,
                buttonKey: _buttonKey,
                onEmojiSelected: (emoji) {
                  reactionController.setPhotoReaction(widget.photoId, emoji);
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
