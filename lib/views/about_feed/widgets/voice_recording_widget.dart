import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/audio_controller.dart';
import '../../../controllers/comment_record_controller.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90.h, // 고정된 높이 설정
      child:
          voiceCommentActiveStates[photo.id] == true
              ? Container(
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

                    // 실시간 댓글이 있으면서 현재 사용자의 댓글이면 저장된 프로필 이미지 표시
                    if (hasRealTimeComment && currentUserId != null) {
                      return Center(
                        child: Draggable<String>(
                          data: 'profile_image',
                          onDragStarted: () {
                            debugPrint('저장된 프로필 이미지 드래그 시작 - feed');
                          },
                          feedback: Transform.scale(
                            scale: 1.2,
                            child: Opacity(
                              opacity: 0.8,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child:
                                      currentUserProfileImage != null &&
                                              currentUserProfileImage.isNotEmpty
                                          ? Image.network(
                                            currentUserProfileImage,
                                            fit: BoxFit.cover,
                                          )
                                          : Container(
                                            color: Colors.grey.shade600,
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(shape: BoxShape.circle),
                              child: ClipOval(
                                child:
                                    currentUserProfileImage != null &&
                                            currentUserProfileImage.isNotEmpty
                                        ? Image.network(
                                          currentUserProfileImage,
                                          fit: BoxFit.cover,
                                        )
                                        : Container(
                                          color: Colors.grey.shade600,
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                          onDragEnd: (details) {
                            onProfileImageDragged(photo.id, details.offset);
                          },
                          child: GestureDetector(
                            onTap: () async {
                              // 현재 사용자의 댓글 찾기
                              final currentUserId =
                                  authController.currentUser?.uid;
                              if (currentUserId != null) {
                                final commentRecordController =
                                    CommentRecordController();

                                try {
                                  // 해당 사진의 댓글들 로드
                                  await commentRecordController
                                      .loadCommentRecordsByPhotoId(photo.id);
                                  final comments =
                                      commentRecordController.commentRecords;

                                  // 현재 사용자의 댓글 찾기
                                  final userComment =
                                      comments
                                          .where(
                                            (comment) =>
                                                comment.recorderUser ==
                                                currentUserId,
                                          )
                                          .firstOrNull;

                                  if (userComment != null &&
                                      userComment.audioUrl.isNotEmpty) {
                                    // AudioController를 사용하여 음성 재생
                                    final audioController =
                                        Provider.of<AudioController>(
                                          context,
                                          listen: false,
                                        );
                                    await audioController.toggleAudio(
                                      userComment.audioUrl,
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('❌ 음성 재생 실패: $e');
                                }
                              }
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(shape: BoxShape.circle),
                              child: ClipOval(
                                child:
                                    currentUserProfileImage != null &&
                                            currentUserProfileImage.isNotEmpty
                                        ? Image.network(
                                          currentUserProfileImage,
                                          fit: BoxFit.cover,
                                        )
                                        : Container(
                                          color: Colors.grey.shade600,
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    // 댓글이 없으면 VoiceCommentWidget 표시
                    return VoiceCommentWidget(
                      autoStart: !hasRealTimeComment, // 실시간 댓글이 없을 때만 자동 시작
                      startAsSaved:
                          hasRealTimeComment, // 실시간 댓글이 있으면 저장된 상태로 시작
                      profileImageUrl:
                          commentProfileImageUrls[photo.id] ??
                          currentUserProfileImage,
                      onSaveRequested: () {
                        // 파형 클릭 시 저장 요청
                        onSaveRequested?.call(photo.id);
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
    );
  }
}
