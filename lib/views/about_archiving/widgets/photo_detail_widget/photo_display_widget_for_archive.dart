import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../controllers/audio_controller.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../models/comment_record_model.dart';
import '../../../../models/photo_data_model.dart';
import '../../../../utils/format_utils.dart';
import '../../../../utils/position_converter.dart';
import '../wave_form_widget/custom_waveform_widget.dart';

class PhotoDisplayWidget extends StatelessWidget {
  final PhotoDataModel photo;
  final List<CommentRecordModel> comments;
  final String userProfileImageUrl;
  final bool isLoadingProfile;
  final int profileImageRefreshKey;
  final Function(String commentId, Offset position) onProfilePositionUpdate;
  final String? currentUserId; // 현재 사용자 ID 추가

  const PhotoDisplayWidget({
    super.key,
    required this.photo,
    required this.comments,
    required this.userProfileImageUrl,
    required this.isLoadingProfile,
    required this.profileImageRefreshKey,
    required this.onProfilePositionUpdate,
    this.currentUserId, // 현재 사용자 ID 추가
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Builder(
        builder: (builderContext) {
          return DragTarget<String>(
            onWillAcceptWithDetails: (details) {
              return (details.data).isNotEmpty;
            },
            onAcceptWithDetails: (details) {
              // 드롭된 좌표를 사진 내 상대 좌표로 변환
              final RenderBox renderBox =
                  builderContext.findRenderObject() as RenderBox;
              final localPosition = renderBox.globalToLocal(details.offset);

              // 프로필 크기(64)의 반지름만큼 보정하여 중심점으로 조정
              final adjustedPosition = Offset(
                localPosition.dx + 32,
                localPosition.dy + 32,
              );

              // 위치 업데이트 콜백 호출
              onProfilePositionUpdate(details.data, adjustedPosition);
            },
            builder: (context, candidateData, rejectedData) {
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // 사진 이미지
                  SizedBox(
                    width: 354.w,
                    height: 500.h,
                    child: CachedNetworkImage(
                      imageUrl: photo.imageUrl,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Container(color: Colors.grey[900]),
                      errorWidget:
                          (context, url, error) =>
                              const Icon(Icons.error, color: Colors.white),
                    ),
                  ),

                  // 현재 사용자의 댓글만 프로필 이미지로 표시 (아카이브는 단일 사용자 댓글만)
                  ...comments
                      .where(
                        (comment) =>
                            comment.relativePosition != null &&
                            currentUserId != null &&
                            comment.recorderUser == currentUserId,
                      )
                      .map((comment) => _buildCommentProfileImage(comment)),

                  // 오디오 컨트롤 오버레이 (하단에 배치)
                  if (photo.audioUrl.isNotEmpty)
                    Positioned(
                      bottom: 14.h,
                      left: 20.w,
                      right: 56.w,
                      child: _buildAudioControlOverlay(screenWidth),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// 댓글 프로필 이미지 위젯 생성
  Widget _buildCommentProfileImage(CommentRecordModel comment) {
    // 🎯 위치가 없으면 표시하지 않음 (Feed와 동일한 방식)
    if (comment.relativePosition == null) {
      return Container(); // 위치 정보가 없으면 빈 컨테이너 반환
    }

    // 상대 좌표를 절대 좌표로 변환
    final imageSize = Size(354.w, 500.h);
    final absolutePosition = PositionConverter.toAbsolutePosition(
      comment.relativePosition!,
      imageSize,
    );
    final clampedPosition = PositionConverter.clampPosition(
      absolutePosition,
      imageSize,
    );

    return Positioned(
      left: clampedPosition.dx - 13.5,
      top: clampedPosition.dy - 13.5,
      child: Consumer<AuthController>(
        builder: (context, authController, child) {
          return InkWell(
            onTap: () async {
              final audioController = Provider.of<AudioController>(
                context,
                listen: false,
              );
              if (comment.audioUrl.isNotEmpty) {
                await audioController.toggleAudio(
                  comment.audioUrl,
                  commentId: comment.id,
                );
              }
            },
            child: Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child:
                  comment.profileImageUrl.isNotEmpty
                      ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: comment.profileImageUrl,
                          width: 27,
                          height: 27,
                          key: ValueKey(
                            'detail_profile_${comment.profileImageUrl}_$profileImageRefreshKey',
                          ),
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Container(
                                width: 27,
                                height: 27,
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 14.sp,
                                ),
                              ),
                          errorWidget:
                              (context, error, stackTrace) => Container(
                                width: 27,
                                height: 27,
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 14.sp,
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
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 14.sp,
                        ),
                      ),
            ),
          );
        },
      ),
    );
  }

  /// 오디오 컨트롤 오버레이 위젯
  Widget _buildAudioControlOverlay(double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Color(0xff000000).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(13.6),
      ),
      child: Row(
        children: [
          // 왼쪽 프로필 이미지
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(shape: BoxShape.circle),
            child: _buildAudioProfileImage(screenWidth),
          ),
          SizedBox(width: (13.79).w),

          // 가운데 파형 (progress 포함)
          Expanded(
            child: SizedBox(
              height: 35.h,
              child: _buildWaveformWidgetWithProgress(),
            ),
          ),

          // 오른쪽 재생 시간 (실시간 업데이트)
          Consumer<AudioController>(
            builder: (context, audioController, child) {
              final isCurrentAudio =
                  audioController.isPlaying &&
                  audioController.currentPlayingAudioUrl == photo.audioUrl;

              Duration displayDuration = Duration.zero;
              if (isCurrentAudio) {
                displayDuration = audioController.currentPosition;
              }

              return Text(
                FormatUtils.formatDuration(displayDuration),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: (11.86).sp,
                  fontWeight: FontWeight.w500,
                  fontFamily: GoogleFonts.inter().fontFamily,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 오디오 프로필 이미지 위젯
  Widget _buildAudioProfileImage(double screenWidth) {
    return isLoadingProfile
        ? CircleAvatar(
          radius: (screenWidth * 0.038),
          backgroundColor: Colors.grey,
          child: SizedBox(
            width: 27,
            height: 27,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        )
        : userProfileImageUrl.isNotEmpty
        ? Consumer<AuthController>(
          builder: (context, authController, child) {
            return CachedNetworkImage(
              imageUrl: userProfileImageUrl,
              key: ValueKey(
                'audio_profile_${userProfileImageUrl}_$profileImageRefreshKey',
              ),
              imageBuilder:
                  (context, imageProvider) =>
                      CircleAvatar(radius: 16, backgroundImage: imageProvider),
              placeholder:
                  (context, url) => CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey,
                    child: SizedBox(
                      width: 27,
                      height: 27,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
              errorWidget:
                  (context, url, error) => CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey,
                    child: SizedBox(
                      width: 27,
                      height: 27,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
            );
          },
        )
        : CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey,
          child: SizedBox(
            width: 27,
            height: 27,
            child: Icon(Icons.person, color: Colors.white),
          ),
        );
  }

  /// 파형 위젯 생성
  Widget _buildWaveformWidgetWithProgress() {
    if (photo.audioUrl.isEmpty ||
        photo.waveformData == null ||
        photo.waveformData!.isEmpty) {
      return Container(
        height: 35.h,
        alignment: Alignment.center,
        child: Text(
          '오디오 없음',
          style: TextStyle(color: Colors.white70, fontSize: 12.sp),
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
          onTap: () => _toggleAudio(context),
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

  /// 오디오 재생/일시정지
  Future<void> _toggleAudio(BuildContext context) async {
    if (photo.audioUrl.isEmpty) return;

    try {
      final audioController = Provider.of<AudioController>(
        context,
        listen: false,
      );
      await audioController.toggleAudio(photo.audioUrl);
    } catch (e) {
      // 에러 처리는 상위 위젯에서 담당
      debugPrint('오디오 재생 오류: $e');
    }
  }
}
