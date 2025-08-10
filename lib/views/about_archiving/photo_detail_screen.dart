import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/photo_data_model.dart';
import '../../models/comment_record_model.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/audio_controller.dart';
import '../../controllers/comment_record_controller.dart';
import '../../utils/format_utils.dart';
import 'widgets/custom_waveform_widget.dart';
import '../about_camera/widgets/audio_recorder_widget.dart';

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
  AudioController? _audioController;

  // 음성 댓글 관련 맵들
  final Map<String, List<CommentRecordModel>> _photoComments = {};
  final Map<String, Offset?> _profileImagePositions =
      {}; // 현재 사용자의 드래그 위치만 임시 저장
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};
  final Map<String, bool> _voiceCommentSavedStates = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
    // Start loading profile information for the current photo's user

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
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
        // Profile image URL successfully retrieved and state updated
      }
    } catch (e) {
      // Failed to load profile information - will use default user ID
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
    // Starting real-time subscription for voice comments on this photo

    try {
      _commentStreams[photoId]?.cancel();

      _commentStreams[photoId] = CommentRecordController()
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) => _handleCommentsUpdate(photoId, comments),
            onError:
                (error) => {
                  /* Real-time comment subscription error for photo $photoId: $error */
                },
          );
    } catch (e) {
      // Failed to start real-time comment subscription for photo: $e
    }
  }

  /// 댓글 업데이트 처리
  void _handleCommentsUpdate(
    String photoId,
    List<CommentRecordModel> comments,
  ) async {
    // Received real-time comment update - photo: $photoId, comment count: ${comments.length}

    if (!mounted) return;

    setState(() {
      _photoComments[photoId] = comments;

      // 현재 사용자가 댓글을 올렸는지만 확인 (다른 사용자 댓글과 무관)
      final currentUserId = _authController?.getUserId;
      if (currentUserId != null) {
        _voiceCommentSavedStates[photoId] = comments.any(
          (comment) => comment.recorderUser == currentUserId,
        );
      }

      // 댓글에서 프로필 위치는 각 댓글 객체에서 직접 사용하므로 별도 저장 불필요
    });
  }

  /// Firestore에 프로필 위치 업데이트
  Future<void> _updateProfilePositionInFirestore(
    String photoId,
    Offset position,
  ) async {
    try {
      // Starting Firestore update for profile position - photo: $photoId, position: $position

      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        // Current user ID not found - cannot update profile position
        return;
      }

      // 현재 사용자의 댓글 찾기
      final comments = _photoComments[photoId] ?? [];
      final userComment =
          comments
              .where((comment) => comment.recorderUser == currentUserId)
              .firstOrNull;

      if (userComment == null) {
        // Current user's voice comment not found - cannot update position
        return;
      }

      await CommentRecordController().updateProfilePosition(
        commentId: userComment.id,
        photoId: photoId,
        profilePosition: position,
      );

      // Profile position update result: ${success ? 'successful' : 'failed'}
    } catch (e) {
      // Error updating profile position in Firestore: $e
    }
  }

  // 페이지 변경 시 호출
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
    if (currentPhoto.audioUrl.isEmpty) {
      // No audio URL available for this photo
      return;
    }

    try {
      await Provider.of<AudioController>(
        context,
        listen: false,
      ).toggleAudio(currentPhoto.audioUrl);
    } catch (e) {
      // Error playing audio: $e
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('음성 파일을 재생할 수 없습니다: $e')));
      }
    }
  }

  // 오디오 정지
  Future<void> _stopAudio() async {
    await Provider.of<AudioController>(context, listen: false).stopAudio();
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
    final screenHeight = MediaQuery.sizeOf(context).height;

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
        controller: PageController(initialPage: widget.initialIndex),
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
                        return details.data == 'profile_image';
                      },
                      onAcceptWithDetails: (details) {
                        // 드롭된 좌표를 사진 내 상대 좌표로 변환
                        final RenderBox renderBox =
                            builderContext.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.offset,
                        );

                        // 사진 영역 내 상대 좌표로 저장
                        setState(() {
                          _profileImagePositions[photo.id] = localPosition;
                        });

                        // Firestore에 위치 업데이트
                        _updateProfilePositionInFirestore(
                          photo.id,
                          localPosition,
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

                            // 모든 댓글의 드롭된 프로필 이미지들 표시
                            ...(_photoComments[photo.id] ?? [])
                                .where(
                                  (comment) => comment.profilePosition != null,
                                )
                                .map(
                                  (comment) => Positioned(
                                    left: (comment.profilePosition!.dx - 13.5)
                                        .clamp(0, (screenWidth * 0.9) - 27),
                                    top: (comment.profilePosition!.dy - 13.5)
                                        .clamp(0, (screenHeight * 0.65) - 27),
                                    child: Consumer<AuthController>(
                                      builder: (
                                        context,
                                        authController,
                                        child,
                                      ) {
                                        return InkWell(
                                          onTap: () async {
                                            _audioController =
                                                Provider.of<AudioController>(
                                                  context,
                                                  listen: false,
                                                );
                                            // 해당 댓글의 오디오 재생
                                            if (comment.audioUrl.isNotEmpty) {
                                              await _audioController!
                                                  .toggleAudio(
                                                    comment.audioUrl,
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
                                  ),
                                ),

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
                                        width: 27, // 반응형 너비
                                        height: 27, // 반응형 높이
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
                                          height: 35.h, // 반응형 높이
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
                mainAxisAlignment: MainAxisAlignment.start,

                children: [
                  SizedBox(width: 25.w), // 반응형 간격
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // 사용자 닉네임
                      Text(
                        '@${_userName.isNotEmpty ? _userName : photo.userID}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontFamily: "Pretendard",
                          fontWeight: FontWeight.w600,
                          height: (1.3).h,
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
                ],
              ),
              SizedBox(height: (31.6).h),
              Consumer<AuthController>(
                builder: (context, authController, child) {
                  // 현재 사용자가 이미 댓글을 올렸는지 확인
                  final currentUserHasComment =
                      _voiceCommentSavedStates[photo.id] == true;

                  // 현재 사용자가 이미 댓글을 올렸으면 프로필 이미지 표시
                  if (currentUserHasComment) {
                    final comments = _photoComments[photo.id] ?? [];
                    final currentUserId = authController.currentUser?.uid;

                    // 현재 사용자의 댓글 찾기
                    CommentRecordModel? userComment;
                    for (var comment in comments) {
                      if (comment.recorderUser == currentUserId) {
                        userComment = comment;
                        break;
                      }
                    }

                    if (userComment != null) {
                      // comment_records의 profileImageUrl 직접 사용
                      final currentUserProfileImage =
                          userComment.profileImageUrl;

                      return Draggable<String>(
                        data: 'profile_image',
                        feedback: Transform.scale(
                          scale: 1.2,
                          child: Opacity(
                            opacity: 0.8,
                            child: Container(
                              width: 27,
                              height: 27,
                              decoration: BoxDecoration(shape: BoxShape.circle),
                              child: ClipOval(
                                child:
                                    currentUserProfileImage.isNotEmpty
                                        ? CachedNetworkImage(
                                          imageUrl: currentUserProfileImage,
                                          fit: BoxFit.cover,
                                        )
                                        : Container(
                                          color: Colors.grey.shade600,
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(shape: BoxShape.circle),
                            child: ClipOval(
                              child:
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
                                        ),
                                      ),
                            ),
                          ),
                        ),

                        child: GestureDetector(
                          onTap: () async {
                            // 클릭하면 저장된 오디오 재생
                            if (userComment!.audioUrl.isNotEmpty) {
                              // Playing saved voice comment: ${userComment.audioUrl}
                              try {
                                final audioController =
                                    Provider.of<AudioController>(
                                      context,
                                      listen: false,
                                    );
                                await audioController.toggleAudio(
                                  userComment.audioUrl,
                                );
                                // Voice playback started successfully
                              } catch (e) {
                                // Voice playback failed: $e
                              }
                            }
                          },
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(shape: BoxShape.circle),
                            child: ClipOval(
                              child:
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
                                          size: 14.sp,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                      );
                    }
                  }

                  // 현재 사용자가 댓글을 올리지 않았으면 AudioRecorderWidget 표시
                  return AudioRecorderWidget(
                    photoId: photo.id,
                    isCommentMode: true, // 명시적으로 댓글 모드 설정
                    profileImagePosition:
                        _profileImagePositions[photo.id], // 현재 저장된 프로필 위치 전달
                    getProfileImagePosition:
                        () =>
                            _profileImagePositions[photo.id], // 최신 위치를 가져오는 콜백
                    onProfileImageDragged: (Offset position) {
                      // 프로필 이미지 드래그 처리
                      setState(() {
                        _profileImagePositions[photo.id] = position;
                      });

                      // Firestore에 위치 업데이트
                      _updateProfilePositionInFirestore(photo.id, position);
                    },
                    onCommentSaved: (commentRecord) {
                      // New voice comment saved with ID: ${commentRecord.id}
                      // 저장 상태 업데이트
                      setState(() {
                        _voiceCommentSavedStates[photo.id] = true;
                      });
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
