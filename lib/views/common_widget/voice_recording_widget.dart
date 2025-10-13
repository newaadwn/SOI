import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../models/photo_data_model.dart';
import '../../models/comment_record_model.dart';
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
  final Future<void> Function(String)? onSaveRequested; // 프로필 배치 확정 시 저장
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
    this.onSaveCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90.h,
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
                        onSaveRequested: () async {
                          // 파형 배치 확정 시 저장 요청
                          if (onSaveRequested != null) {
                            await onSaveRequested!(photo.id);
                          }
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
                  width: 353,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xff161616),
                    borderRadius: BorderRadius.circular(21.5),
                    border: Border.all(
                      color: const Color(0x66D9D9D9),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.only(left: 11.w),
                  child: Row(
                    children: [
                      SizedBox(
                        child: InkWell(
                          onTap: () => onToggleVoiceComment(photo.id),
                          child: Center(
                            child: Image.asset(
                              'assets/mic_icon.png',
                              width: 36,
                              height: 36,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,

                            hintText: '댓글 추가 ....',
                            hintStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w200,
                              letterSpacing: -1.14,
                            ),
                          ),
                          cursorColor: Colors.white,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w200,
                            letterSpacing: -1.14,
                          ),
                          textAlignVertical: TextAlignVertical.center,
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Image.asset(
                          'assets/send_icon.png',
                          width: 17,
                          height: 17,
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
