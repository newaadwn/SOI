import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/photo_data_model.dart';
import '../../../models/comment_record_model.dart';
import 'voice_comment_widget.dart';

/// 음성 녹음 위젯
///
/// 피드에서 음성 댓글 녹음과 관련된 모든 기능을 담당합니다.
/// 음성 댓글 버튼, VoiceCommentWidget, 저장된 프로필 이미지 표시 등을 포함합니다.
class VoiceRecordingWidget extends StatelessWidget {
  final PhotoDataModel photo;
  final Map<String, bool> voiceCommentActiveStates;
  final Map<String, bool> voiceCommentSavedStates;
  final Map<String, String> commentProfileImageUrls;
  final Map<String, String> userProfileImages;
  final Map<String, List<CommentRecordModel>> photoComments;
  final Function(String) onToggleVoiceComment;
  final Function(String, String?, List<double>?, int?) onVoiceCommentCompleted;
  final Function(String) onVoiceCommentDeleted;
  final Function(String, Offset) onProfileImageDragged;
  final Function(String)? onSaveRequested;
  final Function(String)? onSaveCompleted; // 저장 완료 후 초기화 콜백

  const VoiceRecordingWidget({
    super.key,
    required this.photo,
    required this.voiceCommentActiveStates,
    required this.voiceCommentSavedStates,
    required this.commentProfileImageUrls,
    required this.userProfileImages,
    required this.photoComments,
    required this.onToggleVoiceComment,
    required this.onVoiceCommentCompleted,
    required this.onVoiceCommentDeleted,
    required this.onProfileImageDragged,
    this.onSaveRequested,
    this.onSaveCompleted, // 저장 완료 후 초기화 콜백
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90.h, // 고정된 높이 설정
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child:
            voiceCommentActiveStates[photo.id] == true
                ? Container(
                  key: ValueKey('voice-widget-${photo.id}'), // 고유 키 설정
                  height: 90.h, // 컨테이너도 같은 높이로 고정
                  alignment: Alignment.center, // 내용을 중앙 정렬
                  child: Consumer<AuthController>(
                    builder: (context, authController, child) {
                      final currentUserId = authController.currentUser?.uid;

                      // comment_records의 profileImageUrl 사용 (우선순위)
                      // 없으면 AuthController의 프로필 이미지 사용 (fallback)
                      final currentUserProfileImage =
                          commentProfileImageUrls[photo.id] ??
                          (currentUserId != null
                              ? userProfileImages[currentUserId]
                              : null);

                      // 실시간 댓글 데이터로 저장 상태 확인 (우선순위)
                      final hasRealTimeComment =
                          photoComments[photo.id]?.any(
                            (comment) => comment.recorderUser == currentUserId,
                          ) ??
                          false;

                      // 위젯이 활성화된 상태에서는 댓글이 있어도 새로운 녹음 모드로 시작
                      // (추가 댓글을 위한 로직)
                      final shouldStartAsSaved =
                          hasRealTimeComment &&
                          voiceCommentActiveStates[photo.id] != true;

                      // 다중 댓글 기능을 위해 항상 VoiceCommentWidget을 표시
                      // 댓글이 없으면 VoiceCommentWidget 표시
                      return VoiceCommentWidget(
                        autoStart: !shouldStartAsSaved, // 저장된 상태가 아닐 때만 자동 시작
                        startAsSaved: shouldStartAsSaved,
                        profileImageUrl:
                            currentUserProfileImage, // 이미 fallback 처리된 값 사용
                        enableMultipleComments: true, // 다중 댓글 활성화
                        hasExistingComments:
                            (photoComments[photo.id] ?? []).isNotEmpty,
                        onSaveRequested: () {
                          // 파형 클릭 시 저장 요청
                          onSaveRequested?.call(photo.id);
                        },
                        onSaveCompleted: () {
                          // 저장 완료 후 위젯 초기화
                          onSaveCompleted?.call(photo.id);
                        },
                        onRecordingCompleted: (
                          audioPath,
                          waveformData,
                          duration,
                        ) {
                          onVoiceCommentCompleted(
                            photo.id,
                            audioPath,
                            waveformData,
                            duration,
                          );
                        },
                        onRecordingDeleted: () {
                          onVoiceCommentDeleted(photo.id);
                        },
                        onProfileImageDragged: (offset) {
                          // 프로필 이미지 드래그 처리
                          onProfileImageDragged(photo.id, offset);
                        },
                      );
                    },
                  ),
                )
                : Container(
                  key: ValueKey('comment-icon-${photo.id}'), // 고유 키 설정
                  height: 90.h,
                  alignment: Alignment.center, // 중앙 정렬
                  child: IconButton(
                    onPressed: () => onToggleVoiceComment(photo.id),
                    icon: Image.asset(
                      width: 54.w,
                      height: 54.h,
                      'assets/comment.png',
                    ),
                  ),
                ),
      ),
    );
  }
}
