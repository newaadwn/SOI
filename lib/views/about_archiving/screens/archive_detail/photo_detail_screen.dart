import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../controllers/audio_controller.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/comment_record_controller.dart';
import '../../../../controllers/photo_controller.dart';
import '../../../../models/comment_record_model.dart';
import '../../../../models/photo_data_model.dart';
import '../../../../utils/format_utils.dart';
import '../../../../utils/position_converter.dart';
import '../../../about_camera/widgets/audio_recorder_widget.dart';
import '../../widgets/wave_form_widget/custom_waveform_widget.dart';

class PhotoDetailScreen extends StatefulWidget {
  final List<PhotoDataModel> photos;
  final int initialIndex;
  final String categoryName;
  final String categoryId;

  const PhotoDetailScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  // 상태 관리 변수들
  late int _currentIndex;
  String _userProfileImageUrl = '';
  String _userName = '';
  bool _isLoadingProfile = true;
  int _profileImageRefreshKey = 0;

  // 컨트롤러 참조
  AuthController? _authController;

  // 음성 댓글 관련 맵들
  final Map<String, List<CommentRecordModel>> _photoComments = {};
  final Map<String, Offset?> _profileImagePositions =
      {}; // 현재 사용자의 드래그 위치만 임시 저장
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};
  // (필요 시 확장) 댓글 저장 여부 맵 제거됨 – UI에서 사용하지 않아 정리

  // PageController를 상태로 유지 (build마다 새로 생성 방지)
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // AuthController 참조 저장 및 리스너 등록
    if (_authController == null) {
      _authController = Provider.of<AuthController>(context, listen: false);
      _authController!.addListener(_onAuthControllerChanged);
    }
  }

  @override
  void dispose() {
    // 모든 스트림 구독 취소
    for (final subscription in _commentStreams.values) {
      subscription.cancel();
    }
    _commentStreams.clear();

    // AuthController 리스너 제거 (저장된 참조 사용)
    _authController?.removeListener(_onAuthControllerChanged);
    super.dispose();
  }

  /// AuthController 변경 감지 시 프로필 이미지 리프레시
  void _onAuthControllerChanged() async {
    // AuthController has changed - refresh profile images to reflect updates
    setState(() => _profileImageRefreshKey++);
    await _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
  }

  // 사용자 프로필 정보 로드
  Future<void> _loadUserProfileImage() async {
    final currentPhoto = widget.photos[_currentIndex];

    try {
      final authController = _getAuthController;
      final profileImageUrl = await authController.getUserProfileImageUrlById(
        currentPhoto.userID,
      );
      final userInfo = await authController.getUserInfo(currentPhoto.userID);

      if (mounted) {
        setState(() {
          _userProfileImageUrl = profileImageUrl;
          _userName = userInfo?.id ?? currentPhoto.userID;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = currentPhoto.userID;
          _isLoadingProfile = false;
        });
      }
    }
  }

  /// 현재 사진의 음성 댓글을 실시간으로 구독하여 위치 동기화
  void _subscribeToVoiceCommentsForCurrentPhoto() {
    final photoId = widget.photos[_currentIndex].id;

    try {
      _commentStreams[photoId]?.cancel();

      _commentStreams[photoId] = CommentRecordController()
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) => _handleCommentsUpdate(photoId, comments),
            onError: (error) {
              // Real-time comment subscription error
            },
          );
    } catch (e) {
      // Failed to start real-time comment subscription
    }
  }

  /// 댓글 업데이트 처리
  void _handleCommentsUpdate(
    String photoId,
    List<CommentRecordModel> comments,
  ) {
    if (!mounted) return;

    setState(() {
      _photoComments[photoId] = comments;
    });
  }

  /// Firestore에 프로필 위치 업데이트 (상대 좌표 사용)
  /// 이제 recorderUser 단일 댓글이 아닌 특정 commentId 에 대해 위치를 저장하도록 개선
  Future<void> _updateProfilePositionInFirestore(
    String photoId,
    String commentId,
    Offset absolutePosition,
  ) async {
    try {
      debugPrint('=== 프로필 위치 업데이트 시작 ===');
      debugPrint('photoId: $photoId');
      debugPrint('commentId: $commentId');
      debugPrint('입력 절대 위치: $absolutePosition');

      if (commentId.isEmpty) {
        debugPrint('❌ 댓글 ID가 비어있음');
        return;
      }

      final imageSize = Size(354.w, 500.h);

      final relativePosition = PositionConverter.toRelativePosition(
        absolutePosition,
        imageSize,
      );

      await CommentRecordController().updateRelativeProfilePosition(
        commentId: commentId,
        photoId: photoId,
        relativePosition: relativePosition,
      );
    } catch (e) {
      debugPrint('❌ 프로필 위치 업데이트 오류: $e');
    }
  }

  // ==================== Helper Methods ====================

  /// AuthController 인스턴스 가져오기
  AuthController get _getAuthController =>
      Provider.of<AuthController>(context, listen: false);

  /// AudioController 인스턴스 가져오기
  AudioController get _getAudioController =>
      Provider.of<AudioController>(context, listen: false);

  /// SnackBar 표시 헬퍼
  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: "Pretendard")),
        backgroundColor: backgroundColor ?? const Color(0xFF5A5A5A),
      ),
    );
  }

  // ==================== Core Methods ====================
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _profileImageRefreshKey++;
    });
    _stopAudio();
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
  }

  // 오디오 재생/일시정지
  Future<void> _toggleAudio() async {
    final currentPhoto = widget.photos[_currentIndex];
    if (currentPhoto.audioUrl.isEmpty) return;

    try {
      await _getAudioController.toggleAudio(currentPhoto.audioUrl);
    } catch (e) {
      _showSnackBar('음성 파일을 재생할 수 없습니다: $e');
    }
  }

  // 오디오 정지
  Future<void> _stopAudio() async {
    await _getAudioController.stopAudio();
  }

  // 삭제 다이얼로그 표시
  void _showDeleteDialog(PhotoDataModel photo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xff323232),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 17.h),
              // 제목
              Text(
                '사진 삭제',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: "Pretendard",
                  fontWeight: FontWeight.w500,
                  fontSize: 19.8.sp,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              // 설명
              Text(
                '사진 삭제하면 더 이상 해당 카테고리에서 확인할 수 없으며 삭제 후 복구가 \n불가능합니다.',
                style: TextStyle(
                  color: Color(0xfff9f9f9),
                  fontFamily: "Pretendard",
                  fontSize: 15.8.sp,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              // 버튼들
              SizedBox(
                width: (185.5).w,
                height: 38.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deletePhoto(photo);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xfff5f5f5),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.2),
                    ),
                  ),

                  child: Text(
                    '삭제',
                    style: TextStyle(
                      fontFamily: "Pretendard",
                      fontWeight: FontWeight.w600,
                      fontSize: (17.8).sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 13.h),
              SizedBox(
                width: (185.5).w,
                height: 38.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xff5a5a5a),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.2),
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      fontFamily: "Pretendard",
                      fontWeight: FontWeight.w500,
                      fontSize: (17.8).sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
            ],
          ),
        );
      },
    );
  }

  // 사진 삭제 실행
  Future<void> _deletePhoto(PhotoDataModel photo) async {
    try {
      final authController = _getAuthController;
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        _showSnackBar('사용자 인증이 필요합니다.');
        return;
      }

      // PhotoController를 통해 사진 삭제
      final photoController = PhotoController();
      final success = await photoController.deletePhoto(
        categoryId: widget.categoryId,
        photoId: photo.id,
        userId: currentUserId,
        permanentDelete: true,
      );

      if (!mounted) return;

      if (success) {
        _showSnackBar('사진이 삭제되었습니다.');
        _handleSuccessfulDeletion(photo);
      } else {
        _showSnackBar('삭제 중 오류가 발생했습니다.');
      }
    } catch (e) {
      _showSnackBar('삭제 중 오류가 발생했습니다: $e');
    }
  }

  /// 성공적인 삭제 후 UI 처리
  void _handleSuccessfulDeletion(PhotoDataModel photo) {
    // 마지막 사진인 경우 이전 화면으로 돌아가기
    if (widget.photos.length <= 1) {
      Navigator.of(context).pop();
      return;
    }

    // 다른 사진들이 남아있는 경우 현재 사진을 목록에서 제거하고 페이지 조정
    setState(() {
      widget.photos.removeWhere((p) => p.id == photo.id);
      if (_currentIndex >= widget.photos.length) {
        _currentIndex = widget.photos.length - 1;
      }
    });

    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
  }

  // 파형 위젯 빌드
  Widget _buildWaveformWidgetWithProgress(PhotoDataModel photo) {
    if (photo.audioUrl.isEmpty ||
        photo.waveformData == null ||
        photo.waveformData!.isEmpty) {
      return Container(
        height: MediaQuery.sizeOf(context).height * 0.038,
        alignment: Alignment.center,
        child: Text(
          '오디오 없음',
          style: TextStyle(
            color: Colors.white70,
            fontSize: MediaQuery.sizeOf(context).width * 0.027,
          ),
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
          onTap: _toggleAudio,
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.black,
        title: Text(
          widget.categoryName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontFamily: "Pretendard",
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged, // 페이지 변경 감지
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return Column(
            children: [
              // 사진 이미지 + 오디오 오버레이
              ClipRRect(
                borderRadius: BorderRadius.circular(16), // 반응형 반지름
                child: Builder(
                  builder: (builderContext) {
                    return DragTarget<String>(
                      onWillAcceptWithDetails: (details) {
                        // DragTarget is being approached with data: ${details.data}
                        // commentId 문자열이 들어오면 허용
                        return (details.data).isNotEmpty;
                      },
                      onAcceptWithDetails: (details) {
                        debugPrint(
                          'DragTarget에서 드롭 처리 시작 - 전역 위치: ${details.offset}',
                        );

                        // 드롭된 좌표를 사진 내 상대 좌표로 변환
                        final RenderBox renderBox =
                            builderContext.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.offset,
                        );

                        debugPrint('변환된 로컬 위치: $localPosition');

                        // 프로필 이미지 크기(27x27)의 절반만큼 보정하여 중심점으로 조정
                        final adjustedPosition = Offset(
                          localPosition.dx,
                          localPosition.dy,
                        );

                        debugPrint('보정된 최종 위치: $adjustedPosition');

                        // 사진 영역 내 상대 좌표로 저장
                        setState(() {
                          _profileImagePositions[photo.id] = adjustedPosition;
                        });

                        // Firestore에 위치 업데이트
                        final droppedCommentId = details.data;
                        _updateProfilePositionInFirestore(
                          photo.id,
                          droppedCommentId,
                          adjustedPosition,
                        );
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // 사진 이미지
                            SizedBox(
                              width: 354.w, // 반응형 너비
                              height: 500.h, // 반응형 높이
                              child: CachedNetworkImage(
                                imageUrl: photo.imageUrl,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) =>
                                        Container(color: Colors.grey[900]),
                                errorWidget:
                                    (context, url, error) => const Icon(
                                      Icons.error,
                                      color: Colors.white,
                                    ),
                              ),
                            ),

                            // 모든 댓글의 드롭된 프로필 이미지들 표시 (상대 좌표 사용)
                            ...(_photoComments[photo.id] ?? [])
                                .where(
                                  (comment) =>
                                      comment.relativePosition != null ||
                                      comment.profilePosition != null,
                                )
                                .map((comment) {
                                  // 상대 좌표를 절대 좌표로 변환
                                  final imageSize = Size(354.w, 500.h);
                                  Offset absolutePosition;

                                  if (comment.relativePosition != null) {
                                    // 새로운 상대 좌표 사용
                                    absolutePosition =
                                        PositionConverter.toAbsolutePosition(
                                          comment.relativePosition!,
                                          imageSize,
                                        );
                                    debugPrint(
                                      '🔍 댓글 ${comment.id} 상대 위치: ${comment.relativePosition} → 절대 위치: $absolutePosition',
                                    );
                                  } else if (comment.profilePosition != null) {
                                    // 기존 절대 좌표 사용 (하위호환성)
                                    absolutePosition = comment.profilePosition!;
                                    debugPrint(
                                      '🔍 댓글 ${comment.id} 기존 절대 위치: $absolutePosition',
                                    );
                                  } else {
                                    return Container(); // 위치 정보가 없으면 빈 컨테이너
                                  }

                                  // 프로필 이미지가 화면을 벗어나지 않도록 위치 조정
                                  final clampedPosition =
                                      PositionConverter.clampPosition(
                                        absolutePosition,
                                        imageSize,
                                      );

                                  return Positioned(
                                    left: clampedPosition.dx - 13.5,
                                    top: clampedPosition.dy - 13.5,
                                    child: Consumer<AuthController>(
                                      builder: (
                                        context,
                                        authController,
                                        child,
                                      ) {
                                        return InkWell(
                                          onTap: () async {
                                            final audioController =
                                                Provider.of<AudioController>(
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
                                          child: SizedBox(
                                            width: 27,
                                            height: 27,
                                            child:
                                                comment
                                                        .profileImageUrl
                                                        .isNotEmpty
                                                    ? ClipOval(
                                                      child: CachedNetworkImage(
                                                        imageUrl:
                                                            comment
                                                                .profileImageUrl,
                                                        width: 27,
                                                        height: 27,
                                                        key: ValueKey(
                                                          'detail_profile_${comment.profileImageUrl}_$_profileImageRefreshKey',
                                                        ),
                                                        fit: BoxFit.cover,
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
                                                              child: Icon(
                                                                Icons.person,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                size: 14.sp,
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
                                                              child: Icon(
                                                                Icons.person,
                                                                color:
                                                                    Colors
                                                                        .white,
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
                                }),

                            // 오디오 컨트롤 오버레이 (하단에 배치)
                            if (photo.audioUrl.isNotEmpty)
                              Positioned(
                                bottom: 14.h,
                                left: 20.w,
                                right: 56.w,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.w,
                                    vertical: 5.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(
                                      0xff000000,
                                    ).withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(13.6),
                                  ),
                                  // 사진을 찍은 사용자가 녹음한 오디오의 파형을 비롯한 여러가지 정보를 표시하는 부분
                                  child: Row(
                                    children: [
                                      // 왼쪽 프로필 이미지
                                      Container(
                                        width: 27,
                                        height: 27,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                        ),
                                        child: Builder(
                                          builder: (context) {
                                            // 파형을 표시하는 부분에서는 사진을 올린 사용자의 프로필 이미지가 나오게 함
                                            String profileImageToShow =
                                                _userProfileImageUrl;

                                            return _isLoadingProfile
                                                ? CircleAvatar(
                                                  radius: (screenWidth * 0.038),
                                                  backgroundColor: Colors.grey,
                                                  child: SizedBox(
                                                    width: 27,
                                                    height: 27,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                )
                                                : profileImageToShow.isNotEmpty
                                                ? Consumer<AuthController>(
                                                  builder: (
                                                    context,
                                                    authController,
                                                    child,
                                                  ) {
                                                    return CachedNetworkImage(
                                                      imageUrl:
                                                          profileImageToShow,
                                                      key: ValueKey(
                                                        'audio_profile_${profileImageToShow}_$_profileImageRefreshKey',
                                                      ), // 리프레시 키를 사용한 캐시 무효화
                                                      imageBuilder:
                                                          (
                                                            context,
                                                            imageProvider,
                                                          ) => CircleAvatar(
                                                            radius: 16,
                                                            backgroundImage:
                                                                imageProvider,
                                                          ),
                                                      placeholder:
                                                          (
                                                            context,
                                                            url,
                                                          ) => CircleAvatar(
                                                            radius: 16,
                                                            backgroundColor:
                                                                Colors.grey,
                                                            child: SizedBox(
                                                              width: 27,
                                                              height: 27,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                            ),
                                                          ),
                                                      errorWidget:
                                                          (
                                                            context,
                                                            url,
                                                            error,
                                                          ) => CircleAvatar(
                                                            radius: 16,
                                                            backgroundColor:
                                                                Colors.grey,
                                                            child: SizedBox(
                                                              width: 27,
                                                              height: 27,
                                                              child: Icon(
                                                                Icons.person,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                              ),
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
                                                    child: Icon(
                                                      Icons.person,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                );
                                          },
                                        ),
                                      ),
                                      SizedBox(width: (13.79).w),
                                      // 가운데 파형 (progress 포함)
                                      Expanded(
                                        child: SizedBox(
                                          height: 35.h,
                                          child:
                                              _buildWaveformWidgetWithProgress(
                                                photo,
                                              ),
                                        ),
                                      ),

                                      // 오른쪽 재생 시간 (실시간 업데이트)
                                      Consumer<AudioController>(
                                        builder: (
                                          context,
                                          audioController,
                                          child,
                                        ) {
                                          // 현재 사진의 오디오가 재생 중인지 확인
                                          final isCurrentAudio =
                                              audioController.isPlaying &&
                                              audioController
                                                      .currentPlayingAudioUrl ==
                                                  photo.audioUrl;

                                          // 실시간 재생 시간 사용
                                          Duration displayDuration =
                                              Duration.zero;
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
                                              fontSize: (11.86).sp,
                                              fontWeight: FontWeight.w500,
                                              fontFamily:
                                                  GoogleFonts.inter()
                                                      .fontFamily,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: (11.5).h), // 반응형 간격
              // 사진 아래 정보 섹션 (닉네임과 날짜만)
              Row(
                children: [
                  SizedBox(width: 25.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // 사용자 닉네임
                      Container(
                        height: 22.h,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '@${_userName.isNotEmpty ? _userName : photo.userID}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontFamily: "Pretendard",
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // 날짜
                      Text(
                        FormatUtils.formatDate(photo.createdAt),
                        style: TextStyle(
                          color: Color(0xffcccccc),
                          fontSize: 14.sp,
                          fontFamily: "Pretendard",
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  Spacer(), // 남은 공간을 채우기 위한 Spacer
                  MenuAnchor(
                    style: MenuStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      shadowColor: WidgetStatePropertyAll(Colors.transparent),
                      surfaceTintColor: WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      elevation: WidgetStatePropertyAll(0),
                      side: WidgetStatePropertyAll(BorderSide.none),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9.14),
                        ),
                      ),
                    ),
                    builder: (
                      BuildContext context,
                      MenuController controller,
                      Widget? child,
                    ) {
                      return IconButton(
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        icon: Icon(
                          Icons.more_vert,
                          size: 25.sp,
                          color: Color(0xfff9f9f9),
                        ),
                      );
                    },
                    menuChildren: [
                      MenuItemButton(
                        onPressed: () {
                          _showDeleteDialog(photo);
                        },
                        style: ButtonStyle(
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9.14),
                              side: BorderSide.none,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 173.w,
                          height: 45.h,
                          padding: EdgeInsets.only(left: 13.96.w),
                          decoration: BoxDecoration(
                            color: Color(0xff323232),
                            borderRadius: BorderRadius.circular(9.14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/trash_red.png',
                                color: Colors.red,
                                width: 11.16.sp,
                                height: 12.56.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                '삭제',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 15.3517.sp,
                                  fontFamily: "Pretendard",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: (31.6).h),

              Consumer<AuthController>(
                builder: (context, authController, child) {
                  // 항상 AudioRecorderWidget 표시 (여러 댓글 허용)
                  return AudioRecorderWidget(
                    photoId: photo.id,
                    isCommentMode: true, // 명시적으로 댓글 모드 설정
                    profileImagePosition: _profileImagePositions[photo.id],
                    getProfileImagePosition:
                        () => _profileImagePositions[photo.id],
                    // 위치 드래그 콜백은 UI 반영만 (commentId 없이 Firestore 호출 금지)
                    onProfileImageDragged: (Offset position) {
                      setState(() {
                        _profileImagePositions[photo.id] = position;
                      });
                    },
                    onCommentSaved: (commentRecord) {
                      // 새 댓글이 저장되면 음성 댓글 목록 새로고침
                      _subscribeToVoiceCommentsForCurrentPhoto();
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
