import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/audio_controller.dart';
import '../../../controllers/comment_record_controller.dart';
import '../../../models/photo_data_model.dart';
import '../widgets/voice_comment_widget.dart';
import '../widgets/photo_info_overlay.dart';
import '../widgets/dropped_profile_widget.dart';
import '../widgets/feed_audio_control.dart';
import '../managers/feed_data_manager.dart';
import '../managers/voice_comment_handler.dart';

/// 📷 개별 피드 사진 카드 위젯
/// 사진, 오디오 컨트롤, 음성 댓글 UI를 포함합니다.
class FeedPhotoCard extends StatelessWidget {
  final PhotoDataModel photo;
  final String categoryName;
  final FeedDataManager dataManager;
  final int index;

  const FeedPhotoCard({
    super.key,
    required this.photo,
    required this.categoryName,
    required this.dataManager,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 화면 너비의 90%를 사용하되, 최대 400px, 최소 300px로 제한
    final cardWidth = (screenWidth * (354 / 393)).clamp(300.0, 400.0);

    // 화면 높이의 60%를 사용하되, 최대 600px, 최소 400px로 제한
    final cardHeight = (screenHeight * (500 / 852)).clamp(400.0, 600.0);

    return DragTarget<String>(
      onAcceptWithDetails: (details) async {
        // 드롭된 좌표를 사진 내 상대 좌표로 변환
        final RenderBox renderBox = context.findRenderObject() as RenderBox;
        final localPosition = renderBox.globalToLocal(details.offset);

        debugPrint('✅ 프로필 이미지가 사진 영역에 드롭됨');
        debugPrint('📍 글로벌 좌표: ${details.offset}');
        debugPrint('📍 로컬 좌표: $localPosition');

        // 사진 영역 내 좌표로 저장
        dataManager.updateProfileImagePosition(photo.id, localPosition);

        // Firestore에 위치 업데이트 (재시도 로직 포함)
        VoiceCommentHandler.updateProfilePositionInFirestore(
          context,
          photo.id,
          localPosition,
          dataManager,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20.5),

            // 📷 메인 사진 스택
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // 배경 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: photo.imageUrl,
                    fit: BoxFit.cover,
                    width: cardWidth,
                    height: cardHeight,
                    placeholder: (context, url) {
                      return Container(
                        width: cardWidth,
                        height: cardHeight,
                        color: Colors.grey[900],
                        child: const Center(),
                      );
                    },
                  ),
                ),

                // 카테고리 정보
                _buildCategoryInfo(
                  context,
                  categoryName,
                  cardWidth,
                  screenWidth,
                  screenHeight,
                ),

                // 오디오 컨트롤 오버레이
                FeedAudioControl(photo: photo, dataManager: dataManager),

                // 드롭된 프로필 이미지 표시
                if (dataManager.profileImagePositions[photo.id] != null)
                  DroppedProfileWidget(
                    photo: photo,
                    position: dataManager.profileImagePositions[photo.id]!,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    photoComments: dataManager.photoComments,
                    commentProfileImageUrls:
                        dataManager.commentProfileImageUrls,
                  ),
              ],
            ),

            // 📝 사진 정보 오버레이
            PhotoInfoOverlay(
              photo: photo,
              userId: dataManager.userIds,
              onUserTap: () {
                debugPrint('사용자 프로필 탭: ${photo.userID}');
              },
            ),

            // 🎤 음성 댓글 UI 또는 댓글 버튼
            _buildVoiceCommentSection(context, screenWidth, screenHeight),
          ],
        );
      },
    );
  }

  /// 카테고리 정보 위젯
  Widget _buildCategoryInfo(
    BuildContext context,
    String categoryName,
    double cardWidth,
    double screenWidth,
    double screenHeight,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: screenHeight * 0.02),
      child: Container(
        width: cardWidth * 0.3,
        height: screenHeight * 0.038,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          categoryName,
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth * 0.032,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// 음성 댓글 섹션 위젯
  Widget _buildVoiceCommentSection(
    BuildContext context,
    double screenWidth,
    double screenHeight,
  ) {
    final isCommentActive =
        dataManager.voiceCommentActiveStates[photo.id] == true;
    final isCommentSaved =
        dataManager.voiceCommentSavedStates[photo.id] == true;

    if (isCommentSaved || isCommentActive) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: screenHeight * (30 / 852)),
        child: Consumer<AuthController>(
          builder: (context, authController, child) {
            final currentUserId = authController.currentUser?.uid;

            // comment_records의 profileImageUrl 사용 (우선순위)
            // 없으면 AuthController의 프로필 이미지 사용 (fallback)
            final currentUserProfileImage =
                dataManager.commentProfileImageUrls[photo.id] ??
                (currentUserId != null
                    ? dataManager.userProfileImages[currentUserId]
                    : null);

            // 이미 댓글이 있으면 저장된 프로필 이미지만 표시
            if (isCommentSaved && currentUserId != null) {
              return _buildSavedProfileImage(
                context,
                currentUserId,
                currentUserProfileImage,
              );
            }

            // 댓글이 없으면 VoiceCommentWidget 표시
            return VoiceCommentWidget(
              autoStart: !isCommentSaved,
              startAsSaved: isCommentSaved,
              profileImageUrl: currentUserProfileImage,
              onRecordingCompleted: (audioPath, waveformData, duration) {
                VoiceCommentHandler.handleVoiceCommentCompleted(
                  context,
                  photo.id,
                  audioPath,
                  waveformData,
                  duration,
                  dataManager,
                );
              },
              onRecordingDeleted: () {
                VoiceCommentHandler.handleVoiceCommentDeleted(
                  photo.id,
                  dataManager,
                );
              },
              onSaved: () {
                dataManager.setVoiceCommentSaved(photo.id, true);
                debugPrint('🎯 음성 댓글 저장 완료 UI 표시됨 - photoId: ${photo.id}');
              },
              onProfileImageDragged: (offset) {
                VoiceCommentHandler.handleProfileImageDragged(
                  context,
                  photo.id,
                  offset,
                  dataManager,
                );
              },
            );
          },
        ),
      );
    }

    // 기본 댓글 버튼
    return Center(
      child: IconButton(
        onPressed: () => dataManager.toggleVoiceCommentActive(photo.id),
        icon: Image.asset(
          width: 85 / 393 * screenWidth,
          height: 85 / 852 * screenHeight,
          'assets/comment.png',
        ),
      ),
    );
  }

  /// 저장된 프로필 이미지 위젯
  Widget _buildSavedProfileImage(
    BuildContext context,
    String currentUserId,
    String? currentUserProfileImage,
  ) {
    return Center(
      child: Draggable<String>(
        data: 'profile_image',
        onDragStarted: () {
          debugPrint('저장된 프로필 이미지 드래그 시작 - feed');
        },
        feedback: _buildDraggableFeedback(currentUserProfileImage),
        childWhenDragging: _buildDraggingChild(currentUserProfileImage),
        onDragEnd: (details) {
          VoiceCommentHandler.handleProfileImageDragged(
            context,
            photo.id,
            details.offset,
            dataManager,
          );
        },
        child: GestureDetector(
          onTap: () => _handleProfileImageTap(context, currentUserId),
          child: _buildProfileContainer(currentUserProfileImage),
        ),
      ),
    );
  }

  /// 드래그 피드백 위젯
  Widget _buildDraggableFeedback(String? profileImageUrl) {
    return Transform.scale(
      scale: 1.2,
      child: Opacity(
        opacity: 0.8,
        child: _buildProfileContainer(profileImageUrl),
      ),
    );
  }

  /// 드래그 중일 때 보여질 위젯
  Widget _buildDraggingChild(String? profileImageUrl) {
    return Opacity(
      opacity: 0.3,
      child: _buildProfileContainer(profileImageUrl),
    );
  }

  /// 프로필 컨테이너 위젯
  Widget _buildProfileContainer(String? profileImageUrl) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: ClipOval(
        child:
            profileImageUrl != null && profileImageUrl.isNotEmpty
                ? Image.network(profileImageUrl, fit: BoxFit.cover)
                : Container(
                  color: Colors.grey.shade600,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
      ),
    );
  }

  /// 프로필 이미지 탭 처리
  Future<void> _handleProfileImageTap(
    BuildContext context,
    String currentUserId,
  ) async {
    try {
      final commentRecordController = CommentRecordController();

      // 해당 사진의 댓글들 로드
      await commentRecordController.loadCommentRecordsByPhotoId(photo.id);
      final comments = commentRecordController.commentRecords;

      // 현재 사용자의 댓글 찾기
      final userComment =
          comments
              .where((comment) => comment.recorderUser == currentUserId)
              .firstOrNull;

      if (userComment != null && userComment.audioUrl.isNotEmpty) {
        debugPrint('🎵 피드에서 저장된 음성 댓글 재생: ${userComment.audioUrl}');

        // AudioController를 사용하여 음성 재생
        final audioController = Provider.of<AudioController>(
          context,
          listen: false,
        );
        await audioController.toggleAudio(userComment.audioUrl);

        debugPrint('✅ 음성 재생 시작됨');
      } else {
        debugPrint('❌ 재생할 음성 댓글을 찾을 수 없습니다');
      }
    } catch (e) {
      debugPrint('❌ 음성 재생 실패: $e');
    }
  }
}
