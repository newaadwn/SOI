import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/photo_data_model.dart';
import '../../../models/comment_record_model.dart';
import 'user_info_row_widget.dart';
import '../about_voice_comment/voice_recording_widget.dart';
import 'photo_display_widget.dart';

class PhotoCardWidgetCommon extends StatefulWidget {
  final PhotoDataModel photo;
  final String categoryName;
  final String categoryId;
  final int index;
  final bool isOwner;
  // Archive 화면 여부 (Archive에서는 상단 여백 제거)
  final bool isArchive;
  // 카테고리 화면 여부 (카테고리에서는 하단 여백 추가)
  final bool isCategory;

  // 상태 관리 관련
  final Map<String, Offset?> profileImagePositions;
  final Map<String, String> droppedProfileImageUrls;
  final Map<String, List<CommentRecordModel>> photoComments;
  final Map<String, String> userProfileImages;
  final Map<String, bool> profileLoadingStates;
  final Map<String, String> userNames;
  final Map<String, bool> voiceCommentActiveStates;
  final Map<String, bool> voiceCommentSavedStates;
  final Map<String, String> commentProfileImageUrls;

  // 콜백 함수들
  final Function(PhotoDataModel) onToggleAudio;
  final Function(String) onToggleVoiceComment;
  final Function(String, String?, List<double>?, int?) onVoiceCommentCompleted;
  final Function(String) onVoiceCommentDeleted;
  final Function(String, Offset) onProfileImageDragged;
  final Future<void> Function(String) onSaveRequested; // 프로필 배치 저장 콜백
  final Function(String) onSaveCompleted;
  final VoidCallback onDeletePressed;
  final VoidCallback onLikePressed;

  const PhotoCardWidgetCommon({
    super.key,
    required this.photo,
    required this.categoryName,
    required this.categoryId,
    required this.index,
    required this.isOwner,
    this.isArchive = false,
    this.isCategory = false,
    required this.profileImagePositions,
    required this.droppedProfileImageUrls,
    required this.photoComments,
    required this.userProfileImages,
    required this.profileLoadingStates,
    required this.userNames,
    required this.voiceCommentActiveStates,
    required this.voiceCommentSavedStates,
    required this.commentProfileImageUrls,
    required this.onToggleAudio,
    required this.onToggleVoiceComment,
    required this.onVoiceCommentCompleted,
    required this.onVoiceCommentDeleted,
    required this.onProfileImageDragged,
    required this.onSaveRequested,
    required this.onSaveCompleted,
    required this.onDeletePressed,
    required this.onLikePressed,
  });

  @override
  State<PhotoCardWidgetCommon> createState() => _PhotoCardWidgetCommonState();
}

class _PhotoCardWidgetCommonState extends State<PhotoCardWidgetCommon> {
  bool _isTextFieldFocused = false;

  /// 텍스트 댓글 생성 후 프로필 배치를 위한 핸들러
  void _handleTextCommentCreated(String commentId) {
    // 텍스트 댓글이 생성되면 voiceCommentActiveStates를 true로 설정하여
    // VoiceCommentWidget이 활성화되도록 함
    // 부모 위젯에서 관리하는 상태를 직접 변경할 수 없으므로
    // onToggleVoiceComment를 호출하여 상태 변경 요청
    widget.onToggleVoiceComment(widget.photo.id);
  }

  @override
  Widget build(BuildContext context) {
    // 텍스트 필드 포커스 상태로 키보드 여부 판단
    final isKeyboardVisible = _isTextFieldFocused;

    // 키보드가 올라오면 10, 아니면 isCategory에 따라 50 또는 10
    final bottomPadding =
        isKeyboardVisible ? 10.0 : (widget.isCategory ? 55.0 : 10.0);

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!widget.isArchive) SizedBox(height: 90.h),

              // 사진 표시 위젯
              PhotoDisplayWidget(
                key: ValueKey(widget.photo.id),
                photo: widget.photo,
                categoryName: widget.categoryName,
                isArchive: widget.isArchive,
                profileImagePositions: widget.profileImagePositions,
                droppedProfileImageUrls: widget.droppedProfileImageUrls,
                photoComments: widget.photoComments,
                userProfileImages: widget.userProfileImages,
                profileLoadingStates: widget.profileLoadingStates,
                onProfileImageDragged: widget.onProfileImageDragged,
                onToggleAudio: widget.onToggleAudio,
              ),
              SizedBox(height: 12.h),

              // 사용자 정보 위젯 (아이디와 날짜)
              UserInfoWidget(
                photo: widget.photo,
                userNames: widget.userNames,
                isCurrentUserPhoto: widget.isOwner,
                onDeletePressed: widget.onDeletePressed,
                onLikePressed: widget.onLikePressed,
              ),
              SizedBox(height: 10.h),

              // 음성 녹음 위젯을 위한 공간 확보
              SizedBox(height: 90.h),
            ],
          ),
        ),

        // 음성 녹음 위젯을 Stack 위에 배치
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding,
          child: VoiceRecordingWidget(
            photo: widget.photo,
            voiceCommentActiveStates: widget.voiceCommentActiveStates,
            voiceCommentSavedStates: widget.voiceCommentSavedStates,
            commentProfileImageUrls: widget.commentProfileImageUrls,
            userProfileImages: widget.userProfileImages,
            photoComments: widget.photoComments,
            onToggleVoiceComment: widget.onToggleVoiceComment,
            onVoiceCommentCompleted: widget.onVoiceCommentCompleted,
            onVoiceCommentDeleted: widget.onVoiceCommentDeleted,
            onProfileImageDragged: widget.onProfileImageDragged,
            onSaveRequested: widget.onSaveRequested,
            onSaveCompleted: widget.onSaveCompleted,
            onTextFieldFocusChanged: (isFocused) {
              setState(() {
                _isTextFieldFocused = isFocused;
              });
            },
            onTextCommentCreated: _handleTextCommentCreated, // 텍스트 댓글 생성 콜백 연결
          ),
        ),
      ],
    );
  }
}
