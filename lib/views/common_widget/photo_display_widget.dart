import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:soi/controllers/comment_record_controller.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/audio_controller.dart';
import '../../controllers/comment_audio_controller.dart';
import '../../controllers/category_controller.dart';
import '../../models/photo_data_model.dart';
import '../../models/comment_record_model.dart';
import '../../utils/format_utils.dart';
import '../../utils/position_converter.dart';
import '../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';
import '../about_archiving/screens/archive_detail/category_photos_screen.dart';

/// 사진 표시 위젯
///
/// 피드에서 사진 이미지와 관련된 모든 UI를 담당합니다.
/// 사진, 카테고리 정보, 오디오 컨트롤, 드롭된 프로필 이미지 등을 포함합니다.
class PhotoDisplayWidget extends StatefulWidget {
  final PhotoDataModel photo;
  final String categoryName;
  // Archive 여부에 따라 카테고리 라벨 숨김
  final bool isArchive;
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
    this.isArchive = false,
    required this.profileImagePositions,
    required this.droppedProfileImageUrls,
    required this.photoComments,
    required this.userProfileImages,
    required this.profileLoadingStates,
    required this.onProfileImageDragged,
    required this.onToggleAudio,
  });

  @override
  State<PhotoDisplayWidget> createState() => _PhotoDisplayWidgetState();
}

class _PhotoDisplayWidgetState extends State<PhotoDisplayWidget> {
  // 선택된(롱프레스) 음성 댓글 ID 및 위치
  String? _selectedCommentId;
  Offset? _selectedCommentPosition; // 스택(이미지) 내부 좌표 (아바타 중심)
  bool _showActionOverlay = false; // 선택된 댓글 아래로 마스킹 & 팝업 표시 여부
  // 해당 사진(위젯 인스턴스)에서 음성 댓글 프로필 표시 여부
  bool _isShowingComments = false; // 기본은 숨김
  bool _autoOpenedOnce = false; // 최초 자동 열림 1회 제어

  final CommentRecordController _commentRecordController =
      CommentRecordController();

  /// 카테고리 화면으로 이동
  void _navigateToCategory() async {
    final categoryId = widget.photo.categoryId;
    if (categoryId.isEmpty) {
      debugPrint('카테고리 ID가 없습니다');
      return;
    }

    try {
      final categoryController = context.read<CategoryController>();
      final category = await categoryController.getCategory(categoryId);
      if (category == null) {
        debugPrint('카테고리를 찾을 수 없습니다: $categoryId');
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return CategoryPhotosScreen(category: category);
            },
          ),
        );
        debugPrint('카테고리로 이동: $categoryId');
      }
    } catch (e) {
      debugPrint('카테고리 로드 실패: $e');
    }
  }

  /// 커스텀 파형 위젯을 빌드하는 메서드 (실시간 progress 포함)
  Widget _buildWaveformWidgetWithProgress() {
    if (widget.photo.audioUrl.isEmpty ||
        widget.photo.waveformData == null ||
        widget.photo.waveformData!.isEmpty) {
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
            audioController.currentPlayingAudioUrl == widget.photo.audioUrl;

        double progress = 0.0;
        if (isCurrentAudio &&
            audioController.currentDuration.inMilliseconds > 0) {
          progress = (audioController.currentPosition.inMilliseconds /
                  audioController.currentDuration.inMilliseconds)
              .clamp(0.0, 1.0);
        }

        return Container(
          alignment: Alignment.center,
          child: CustomWaveformWidget(
            waveformData: widget.photo.waveformData!,
            color: (isCurrentAudio) ? Color(0xff5a5a5a) : Color(0xffffffff),
            activeColor: Colors.white,
            progress: progress,
          ),
        );
      },
    );
  }

  /// 사용자 프로필 이미지 위젯 빌드
  Widget _buildUserProfileWidget(BuildContext context) {
    final userId = widget.photo.userID;
    final screenWidth = MediaQuery.of(context).size.width;
    final profileSize = screenWidth * 0.085;

    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final isLoading = widget.profileLoadingStates[userId] ?? false;
        final profileImageUrl = widget.userProfileImages[userId] ?? '';

        return isLoading
            ? CircleAvatar(
              radius: 100,
              backgroundColor: Colors.grey[700],
              child: SizedBox(
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
                        fit: BoxFit.cover,
                        // 메모리 최적화: 프로필 이미지 크기 제한
                        memCacheHeight: (profileSize * 2.5).toInt(),
                        memCacheWidth: (profileSize * 2.5).toInt(),
                        maxHeightDiskCache: 150,
                        maxWidthDiskCache: 150,
                        placeholder:
                            (context, url) =>
                                Container(color: Colors.grey[700]),
                        errorWidget:
                            (context, url, error) =>
                                Container(color: Colors.grey[700]),
                      )
                      : Container(color: Colors.grey[700]),
            );
      },
    );
  }

  @override
  void didUpdateWidget(covariant PhotoDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 최초로 현재 사용자 댓글이 생긴 시점에 한 번만 자동 표시
    if (!_autoOpenedOnce) {
      try {
        final authController = context.read<AuthController?>();
        final uid = authController?.currentUser?.uid;
        if (uid != null) {
          final comments =
              widget.photoComments[widget.photo.id] ??
              const <CommentRecordModel>[];
          final hasUserComment = comments.any((c) => c.recorderUser == uid);
          if (hasUserComment) {
            setState(() {
              _isShowingComments = true; // 한번 자동으로 켜기
              _autoOpenedOnce = true; // 재자동 방지
            });
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
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

                  widget.onProfileImageDragged(
                    widget.photo.id,
                    adjustedPosition,
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // 🔥 메모리 최적화: 배경 이미지 크기 제한
                      CachedNetworkImage(
                        imageUrl: widget.photo.imageUrl,
                        fit: BoxFit.cover,
                        width: 354.w, // 실제 이미지 너비
                        height: 500.h, // 실제 이미지 높이
                        // 🔥 메모리 최적화: 디코딩 크기 제한으로 메모리 사용량 대폭 감소
                        memCacheHeight:
                            (500 * 1.2).toInt(), // 화면 크기보다 약간 큰 정도로 제한
                        memCacheWidth:
                            (354 * 1.2).toInt(), // 화면 크기보다 약간 큰 정도로 제한
                        maxHeightDiskCache: 1000, // 디스크 캐시도 제한
                        maxWidthDiskCache: 700, // 디스크 캐시도 제한
                        placeholder: (context, url) {
                          return Container(
                            width: 354.w,
                            height: 500.h,
                            color: Colors.grey[900],
                            child: const Center(),
                          );
                        },
                      ),
                      // 댓글 보기 토글 시(롱프레스 액션 오버레이 아닐 때) 살짝 어둡게 마스킹하여 아바타 대비 확보
                      if (_isShowingComments && !_showActionOverlay)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      // 선택된 댓글이 있을 때 전체 마스킹 (선택된 것만 위에 남김)
                      if (_showActionOverlay)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showActionOverlay = false;
                                _selectedCommentId = null;
                                _selectedCommentPosition = null;
                              });
                            },
                            child: Container(
                              color: Color(0xffd9d9d9).withValues(alpha: .3),
                            ),
                          ),
                        ),

                      // 카테고리 정보
                      if (!widget.isArchive)
                        GestureDetector(
                          onTap: () => _navigateToCategory(),
                          child: Padding(
                            padding: EdgeInsets.only(top: 16.h),
                            child: IntrinsicWidth(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: 15.w,
                                      right: 15.w,
                                      top: 1.h,
                                    ),
                                    child: Text(
                                      widget.categoryName,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: "Pretendard",
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1, // 한 줄로 제한
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 오디오 컨트롤 오버레이 (photo_detail처럼)
                      Positioned(
                        left: 20.w,
                        bottom: 7.h,
                        child: SizedBox(
                          height: 50.h,
                          child: Row(
                            children: [
                              // 오디오 영역 (고정 width)
                              SizedBox(
                                width: 278.w,
                                child:
                                    widget.photo.audioUrl.isNotEmpty
                                        ? GestureDetector(
                                          onTap:
                                              () => widget.onToggleAudio(
                                                widget.photo,
                                              ),
                                          child: Container(
                                            width: 278.w,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Color(
                                                0xff000000,
                                              ).withValues(alpha: 0.4),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                // 왼쪽 프로필 이미지 (작은 버전)
                                                Container(
                                                  width: 27,
                                                  height: 27,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: ClipOval(
                                                    child:
                                                        _buildUserProfileWidget(
                                                          context,
                                                        ),
                                                  ),
                                                ),
                                                SizedBox(width: (17).w),

                                                // 가운데 파형 (progress 포함)
                                                SizedBox(
                                                  width: (144.62).w,
                                                  height: 32.h,
                                                  child:
                                                      _buildWaveformWidgetWithProgress(),
                                                ),

                                                SizedBox(width: (17).w),

                                                // 오른쪽 재생 시간 (실시간 업데이트)
                                                SizedBox(
                                                  width: 45.w,
                                                  child: Consumer<
                                                    AudioController
                                                  >(
                                                    builder: (
                                                      context,
                                                      audioController,
                                                      child,
                                                    ) {
                                                      // 현재 사진의 오디오가 재생 중인지 확인
                                                      final isCurrentAudio =
                                                          audioController
                                                              .isPlaying &&
                                                          audioController
                                                                  .currentPlayingAudioUrl ==
                                                              widget
                                                                  .photo
                                                                  .audioUrl;

                                                      // 실시간 재생 시간 사용
                                                      Duration displayDuration =
                                                          Duration.zero;
                                                      if (isCurrentAudio) {
                                                        displayDuration =
                                                            audioController
                                                                .currentPosition;
                                                      }

                                                      return Text(
                                                        FormatUtils.formatDuration(
                                                          (isCurrentAudio)
                                                              ? displayDuration
                                                              : widget
                                                                  .photo
                                                                  .duration,
                                                        ),
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12.sp,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        : Container(), // 오디오가 없으면 빈 컨테이너
                              ),

                              // 댓글 아이콘 영역 (고정 width)
                              SizedBox(
                                width: 60.w,
                                child:
                                    (widget.photoComments[widget.photo.id] ??
                                                [])
                                            .isNotEmpty
                                        ? Center(
                                          child: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _isShowingComments =
                                                    !_isShowingComments;
                                              });
                                            },
                                            icon: Image.asset(
                                              "assets/comment_profile_icon.png",
                                              width: 25.w,
                                              height: 25.h,
                                            ),
                                          ),
                                        )
                                        : Container(), // 댓글이 없으면 빈 컨테이너
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 모든 댓글의 드롭된 프로필 이미지들 표시 (상대 좌표 사용)
                      ...(() {
                        if (!_isShowingComments) {
                          return <Widget>[]; // 숨김 상태에서는 아무 것도 렌더링하지 않음
                        }
                        final comments =
                            widget.photoComments[widget.photo.id] ?? [];

                        final commentsWithPosition =
                            comments
                                .where(
                                  (comment) => comment.relativePosition != null,
                                )
                                .toList();

                        return commentsWithPosition.map((comment) {
                          // 오버레이 중이면 선택된 댓글 외에는 숨김
                          if (_showActionOverlay &&
                              _selectedCommentId != null &&
                              comment.id != _selectedCommentId) {
                            return const SizedBox.shrink();
                          }
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
                            child: GestureDetector(
                              onLongPress: () {
                                // 롱프레스 시 선택 & 마스킹 + 액션 팝업 노출
                                setState(() {
                                  _selectedCommentId = comment.id;
                                  _selectedCommentPosition = clampedPosition;
                                  _showActionOverlay = true;
                                });
                                debugPrint(
                                  'Long press detected on comment: ${comment.id}',
                                );
                              },
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
                                  final isSelected =
                                      _showActionOverlay &&
                                      _selectedCommentId == comment.id;

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
                                          debugPrint(
                                            '❌ Feed - 음성 댓글 재생 실패: $e',
                                          );
                                        }
                                      }
                                    },
                                    child: Container(
                                      width: 27,
                                      height: 27,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow:
                                            isSelected
                                                ? [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.45,
                                                        ),
                                                    blurRadius: 6,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                                : null,
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : isCurrentCommentPlaying
                                                  ? Colors.white
                                                  : Colors.transparent,
                                          width: isSelected ? 2.2 : 1,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          ClipOval(
                                            child:
                                                comment
                                                        .profileImageUrl
                                                        .isNotEmpty
                                                    ? CachedNetworkImage(
                                                      imageUrl:
                                                          comment
                                                              .profileImageUrl,
                                                      width: 27,
                                                      height: 27,
                                                      fit: BoxFit.cover,
                                                      memCacheHeight:
                                                          (27 * 3).toInt(),
                                                      memCacheWidth:
                                                          (27 * 3).toInt(),
                                                      maxHeightDiskCache: 100,
                                                      maxWidthDiskCache: 100,
                                                      placeholder:
                                                          (
                                                            context,
                                                            url,
                                                          ) => Container(
                                                            width: 27,
                                                            height: 27,
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors
                                                                      .grey[700],
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
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
                                                              color:
                                                                  Colors
                                                                      .grey[700],
                                                              shape:
                                                                  BoxShape
                                                                      .circle,
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
                                                      child: const Icon(
                                                        Icons.person,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                    ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        });
                      })(),
                      // 선택된 댓글에 대한 작은 액션 팝업 (삭제 등) - 이미지 영역 안에 직접 렌더
                      if (_showActionOverlay &&
                          _selectedCommentId != null &&
                          _selectedCommentPosition != null)
                        Builder(
                          builder: (context) {
                            final imageWidth = 354.w.toDouble();
                            final popupWidth = 180.0;

                            // 기본 위치: 선택된 아바타 오른쪽 살짝 아래
                            double left = _selectedCommentPosition!.dx;
                            double top = _selectedCommentPosition!.dy + 20;
                            // 화면 밖으로 나가지 않도록 클램프
                            if (left + popupWidth > imageWidth) {
                              left = imageWidth - popupWidth - 8;
                            }

                            return Positioned(
                              left: left,
                              top: top,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width: 173.w,
                                  height: 45.h,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1C1C),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () async {
                                      if (_selectedCommentId == null) return;
                                      final targetId = _selectedCommentId!;
                                      try {
                                        await _commentRecordController
                                            .hardDeleteCommentRecord(
                                              targetId,
                                              widget.photo.id,
                                            );
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('댓글 삭제 실패: $e'),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            // 오버레이 및 선택 해제 + 기본 화면 복귀 위해 댓글 표시도 종료
                                            _showActionOverlay = false;
                                            _selectedCommentId = null;
                                            _selectedCommentPosition = null;
                                            _isShowingComments = false; // 배경 원복
                                          });
                                        }
                                      }
                                    },
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        SizedBox(width: 13.96.w),
                                        Image.asset(
                                          "assets/trash_red.png",
                                          width: 11.2.w,
                                          height: 12.6.h,
                                        ),
                                        SizedBox(width: 12.59.w),
                                        Text(
                                          '댓글 삭제',
                                          style: TextStyle(
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xffff0000),
                                            fontFamily: 'Pretendard',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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
