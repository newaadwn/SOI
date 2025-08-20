import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/audio_controller.dart';
import '../../../controllers/comment_audio_controller.dart';
import '../../../models/photo_data_model.dart';
import '../../../models/comment_record_model.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/position_converter.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

/// 사진 표시 위젯
///
/// 피드에서 사진 이미지와 관련된 모든 UI를 담당합니다.
/// 사진, 카테고리 정보, 오디오 컨트롤, 드롭된 프로필 이미지 등을 포함합니다.
class PhotoDisplayWidget extends StatelessWidget {
  final PhotoDataModel photo;
  final String categoryName;
  final Map<String, Offset?> profileImagePositions;
  final Map<String, String> droppedProfileImageUrls;
  final Map<String, List<CommentRecordModel>> photoComments;
  final Map<String, String> userProfileImages;
  final Map<String, bool> profileLoadingStates;
  final Function(String, Offset) onProfileImageDragged;
  final Function(PhotoDataModel) onToggleAudio;

  const PhotoDisplayWidget({
    super.key,
    required this.photo,
    required this.categoryName,
    required this.profileImagePositions,
    required this.droppedProfileImageUrls,
    required this.photoComments,
    required this.userProfileImages,
    required this.profileLoadingStates,
    required this.onProfileImageDragged,
    required this.onToggleAudio,
  });

  /// 커스텀 파형 위젯을 빌드하는 메서드 (실시간 progress 포함)
  Widget _buildWaveformWidgetWithProgress() {
    if (photo.audioUrl.isEmpty ||
        photo.waveformData == null ||
        photo.waveformData!.isEmpty) {
      return Container(
        height: 32,
        alignment: Alignment.center,
        child: const Text(
          '오디오 없음',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      );
    }

    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isCurrentAudio =
            audioController.isPlaying &&
            audioController.currentPlayingAudioUrl == photo.audioUrl;

        double progress = 0.0;
        if (isCurrentAudio &&
            audioController.currentDuration.inMilliseconds > 0) {
          progress = (audioController.currentPosition.inMilliseconds /
                  audioController.currentDuration.inMilliseconds)
              .clamp(0.0, 1.0);
        }

        return GestureDetector(
          onTap: () => onToggleAudio(photo),
          child: Container(
            alignment: Alignment.center,
            child: CustomWaveformWidget(
              waveformData: photo.waveformData!,
              color: const Color(0xff5a5a5a),
              activeColor: Colors.white,
              progress: progress,
            ),
          ),
        );
      },
    );
  }

  /// 사용자 프로필 이미지 위젯 빌드
  Widget _buildUserProfileWidget(BuildContext context) {
    final userId = photo.userID;
    final screenWidth = MediaQuery.of(context).size.width;
    final profileSize = screenWidth * 0.085;

    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final isLoading = profileLoadingStates[userId] ?? false;
        final profileImageUrl = userProfileImages[userId] ?? '';

        return Container(
          width: profileSize,
          height: profileSize,
          decoration: BoxDecoration(shape: BoxShape.circle),
          child:
              isLoading
                  ? CircleAvatar(
                    radius: profileSize / 2 - 2,
                    backgroundColor: Colors.grey[700],
                    child: SizedBox(
                      width: profileSize * 0.4,
                      height: profileSize * 0.4,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                  : ClipOval(
                    child:
                        profileImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: profileImageUrl,
                              width: profileSize - 4,
                              height: profileSize - 4,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) =>
                                      _buildPlaceholder(profileSize),
                              errorWidget:
                                  (context, url, error) =>
                                      _buildPlaceholder(profileSize),
                            )
                            : _buildPlaceholder(profileSize),
                  ),
        );
      },
    );
  }

  /// 플레이스홀더 아바타 빌드
  Widget _buildPlaceholder(double profileSize) {
    return Container(
      width: profileSize - 4,
      height: profileSize - 4,
      color: Colors.grey[700],
      child: Icon(Icons.person, color: Colors.white, size: profileSize * 0.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기에 맞춘 반응형 이미지 크기 계산

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 이미지 영역에만 DragTarget 적용 - Builder Pattern 사용
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Builder(
            builder: (builderContext) {
              return DragTarget<String>(
                onWillAcceptWithDetails: (details) {
                  // DragTarget is being approached with data: ${details.data}
                  // commentId 문자열이 들어오면 허용
                  return (details.data).isNotEmpty;
                },
                onAcceptWithDetails: (details) {
                  // 드롭된 좌표를 사진 내 상대 좌표로 변환
                  final RenderBox renderBox =
                      builderContext.findRenderObject() as RenderBox;
                  final localPosition = renderBox.globalToLocal(details.offset);

                  // 프로필 이미지 크기(27x27)의 절반만큼 보정하여 중심점으로 조정
                  final adjustedPosition = Offset(
                    localPosition.dx + 32,
                    localPosition.dy + 32,
                  );

                  onProfileImageDragged(photo.id, adjustedPosition);
                },
                builder: (context, candidateData, rejectedData) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // 배경 이미지
                      CachedNetworkImage(
                        imageUrl: photo.imageUrl,
                        fit: BoxFit.cover,
                        width: 354.w, // 실제 이미지 너비
                        height: 500.h, // 실제 이미지 높이
                        placeholder: (context, url) {
                          return Container(
                            width: 354.w,
                            height: 500.h,
                            color: Colors.grey[900],
                            child: const Center(),
                          );
                        },
                      ),
                      // 카테고리 정보
                      Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: IntrinsicWidth(
                          child: Container(
                            // width 제거 - 텍스트 길이에 따라 동적으로 조정
                            height: 32.h,
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            constraints: BoxConstraints(
                              minWidth: 60.w, // 최소 너비
                              maxWidth: 354.w * 0.8, // 최대 너비 제한
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1, // 한 줄로 제한
                            ),
                          ),
                        ),
                      ),

                      // 오디오 컨트롤 오버레이 (photo_detail처럼)
                      if (photo.audioUrl.isNotEmpty)
                        Positioned(
                          bottom: 16.h,
                          left: 20.w,
                          right: 20.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xff000000).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              children: [
                                // 왼쪽 프로필 이미지 (작은 버전)
                                Container(
                                  width: 33.w,
                                  height: 33.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: _buildUserProfileWidget(context),
                                  ),
                                ),
                                SizedBox(width: 12.w),

                                // 가운데 파형 (progress 포함)
                                Expanded(
                                  child: SizedBox(
                                    height: 34.h,
                                    child: _buildWaveformWidgetWithProgress(),
                                  ),
                                ),

                                SizedBox(width: 12.w),

                                // 오른쪽 재생 시간 (실시간 업데이트)
                                Consumer<AudioController>(
                                  builder: (context, audioController, child) {
                                    // 현재 사진의 오디오가 재생 중인지 확인
                                    final isCurrentAudio =
                                        audioController.isPlaying &&
                                        audioController
                                                .currentPlayingAudioUrl ==
                                            photo.audioUrl;

                                    // 실시간 재생 시간 사용
                                    Duration displayDuration = Duration.zero;
                                    if (isCurrentAudio) {
                                      displayDuration =
                                          audioController.currentPosition;
                                    }

                                    return Text(
                                      FormatUtils.formatDuration(
                                        displayDuration,
                                      ),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 모든 댓글의 드롭된 프로필 이미지들 표시 (상대 좌표 사용)
                      ...(() {
                        final comments = photoComments[photo.id] ?? [];

                        final commentsWithPosition =
                            comments
                                .where(
                                  (comment) => comment.relativePosition != null,
                                )
                                .toList();

                        return commentsWithPosition.map((comment) {
                          // 상대 좌표를 절대 좌표로 변환 (실제 렌더링 크기 사용)
                          final actualImageSize = Size(
                            354.w.toDouble(),
                            500.h.toDouble(),
                          );
                          Offset absolutePosition;

                          if (comment.relativePosition != null) {
                            // 새로운 상대 좌표 사용
                            absolutePosition =
                                PositionConverter.toAbsolutePosition(
                                  comment.relativePosition!,
                                  actualImageSize,
                                );
                          } else {
                            return Container(); // 위치 정보가 없으면 빈 컨테이너
                          }

                          // 프로필 이미지가 화면을 벗어나지 않도록 위치 조정
                          final clampedPosition =
                              PositionConverter.clampPosition(
                                absolutePosition,
                                actualImageSize,
                              );

                          return Positioned(
                            left: clampedPosition.dx - 13.5,
                            top: clampedPosition.dy - 13.5,
                            child: Consumer2<
                              AuthController,
                              CommentAudioController
                            >(
                              builder: (
                                context,
                                authController,
                                commentAudioController,
                                child,
                              ) {
                                // 현재 댓글이 재생 중인지 확인
                                final isCurrentCommentPlaying =
                                    commentAudioController.isCommentPlaying(
                                      comment.id,
                                    );

                                return InkWell(
                                  onTap: () async {
                                    if (comment.audioUrl.isNotEmpty) {
                                      try {
                                        // CommentAudioController 사용하여 개별 댓글 재생
                                        await commentAudioController
                                            .toggleComment(
                                              comment.id,
                                              comment.audioUrl,
                                            );
                                      } catch (e) {
                                        debugPrint('❌ Feed - 음성 댓글 재생 실패: $e');
                                      }
                                    }
                                  },
                                  child: Container(
                                    width: 27,
                                    height: 27,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      // 재생 중인 댓글은 흰색 테두리 표시
                                      border:
                                          isCurrentCommentPlaying
                                              ? Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              )
                                              : null,
                                    ),
                                    child:
                                        comment.profileImageUrl.isNotEmpty
                                            ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl:
                                                    comment.profileImageUrl,
                                                width: 27,
                                                height: 27,
                                                fit: BoxFit.cover,
                                                placeholder:
                                                    (context, url) => Container(
                                                      width: 27,
                                                      height: 27,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[700],
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      width: 27,
                                                      height: 27,
                                                      decoration: BoxDecoration(
                                                        color: Colors.grey[700],
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                              ),
                                            )
                                            : Container(
                                              width: 27,
                                              height: 27,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[700],
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                  ),
                                );
                              },
                            ),
                          );
                        });
                      })(),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
