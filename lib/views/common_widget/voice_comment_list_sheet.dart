import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../models/comment_record_model.dart';
import '../../controllers/emoji_reaction_controller.dart';
import '../../controllers/comment_record_controller.dart';
import 'about_emoji/reaction_row_widget.dart';
import 'about_voice_comment/voice_comment_widget.dart';

/// 재사용 가능한 음성 댓글 리스트 Bottom Sheet
/// feed / archive 모두에서 사용
class VoiceCommentListSheet extends StatelessWidget {
  final String photoId;
  final String? categoryId; // 리액션 스트림용 (선택적 - 없으면 표시 생략)
  final String title; // 상단 제목 (예: "공감")
  final String? commentIdFilter; // 특정 댓글만 표시할 때 사용
  const VoiceCommentListSheet({
    super.key,
    required this.photoId,
    this.categoryId,
    this.title = '공감',
    this.commentIdFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.8),
          topRight: Radius.circular(24.8),
        ),
      ),
      padding: EdgeInsets.only(
        top: 18.h,
        bottom: 18.h,
        left: 27.w,
        right: 27.w,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,

        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              fontFamily: 'Pretendard',
            ),
          ),

          // 통합 ListView: (리액션들 + 음성 댓글) 하나의 스크롤
          Consumer2<EmojiReactionController, CommentRecordController>(
            builder: (context, reactionController, recordController, _) {
              final hasCommentFilter = commentIdFilter != null;
              // 1) 리액션 스트림 (optional)
              final reactionsStream =
                  (!hasCommentFilter && categoryId != null)
                      ? reactionController.reactionsStream(
                        categoryId: categoryId!,
                        photoId: photoId,
                      )
                      : const Stream<List<Map<String, dynamic>>>.empty();

              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: reactionsStream,
                builder: (context, reactSnap) {
                  final reactions = reactSnap.data ?? [];
                  // 2) 댓글 스트림 (중첩 StreamBuilder)
                  return StreamBuilder<List<CommentRecordModel>>(
                    stream: recordController.getCommentRecordsStream(photoId),
                    builder: (context, commentSnap) {
                      final waiting =
                          reactSnap.connectionState ==
                              ConnectionState.waiting ||
                          commentSnap.connectionState ==
                              ConnectionState.waiting;
                      if (waiting) {
                        return SizedBox(
                          height: 120.h,
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      if (reactSnap.hasError || commentSnap.hasError) {
                        return SizedBox(
                          height: 120.h,
                          child: Center(
                            child: Text(
                              '불러오기 실패',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        );
                      }
                      final allComments = commentSnap.data ?? [];
                      final comments =
                          hasCommentFilter
                              ? allComments
                                  .where(
                                    (comment) => comment.id == commentIdFilter,
                                  )
                                  .toList()
                              : allComments;
                      final total =
                          (hasCommentFilter ? 0 : reactions.length) +
                          comments.length;
                      if (total == 0) {
                        return SizedBox(
                          height: 120.h,
                          child: Center(
                            child: Text(
                              hasCommentFilter ? '댓글을 찾을 수 없습니다' : '댓글이 없습니다',
                              style: TextStyle(
                                color: const Color(0xFF9E9E9E),
                                fontSize: 16.sp,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }
                      return Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: total,
                          separatorBuilder: (_, __) => SizedBox(height: 18.h),
                          itemBuilder: (context, index) {
                            if (!hasCommentFilter && index < reactions.length) {
                              final r = reactions[index];
                              return ReactionRow(
                                data: r,
                                emoji: r['emoji'] ?? '',
                              );
                            }
                            final commentIndex =
                                hasCommentFilter
                                    ? index
                                    : index - reactions.length;
                            final comment = comments[commentIndex];
                            return VoiceCommentRow(comment: comment);
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
