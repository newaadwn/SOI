import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../controllers/audio_controller.dart';
import '../../../../controllers/auth_controller.dart';
import '../../../../controllers/comment_record_controller.dart';
import '../../../../controllers/photo_controller.dart';
import '../../../../models/comment_record_model.dart';
import '../../../../models/photo_data_model.dart';
import '../../../../utils/position_converter.dart';
import '../../../about_share/share_screen.dart';
import '../../../common_widget/photo_card_widget_common.dart';

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
  late final PageController _pageController;
  late int _currentIndex;

  // 사용자 프로필 관련
  String _userProfileImageUrl = '';
  String _userName = '';
  bool _isLoadingProfile = true;
  int _profileImageRefreshKey = 0;

  // 컨트롤러
  AuthController? _authController;

  // 상태 맵 (Feed 구조와 동일)
  final Map<String, List<CommentRecordModel>> _photoComments = {};
  final Map<String, Offset?> _profileImagePositions = {};
  final Map<String, String> _droppedProfileImageUrls = {};
  final Map<String, bool> _voiceCommentActiveStates = {};
  final Map<String, bool> _voiceCommentSavedStates = {};
  final Map<String, String> _commentProfileImageUrls = {};
  final Map<String, String> _userProfileImages = {};
  final Map<String, bool> _profileLoadingStates = {};
  final Map<String, String> _userNames = {};
  final Map<String, CommentRecordModel> _pendingVoiceComments = {};
  final Map<String, Offset> _pendingProfilePositions = {};
  final Map<String, List<String>> _savedCommentIds = {};
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _authController = Provider.of<AuthController>(context, listen: false);
    _authController?.addListener(_onAuthControllerChanged);
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
    _loadCommentsForPhoto(widget.photos[_currentIndex].id);
  }

  @override
  void dispose() {
    for (final sub in _commentStreams.values) {
      sub.cancel();
    }
    _commentStreams.clear();
    _authController?.removeListener(_onAuthControllerChanged);
    _pageController.dispose();

    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
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
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 23.w),
            child: IconButton(
              onPressed: () async {
                final currentPhoto = widget.photos[_currentIndex];
                Duration audioDuration = currentPhoto.duration;
                if (currentPhoto.audioUrl.isNotEmpty) {
                  final audioController = _getAudioController;
                  if (audioController.currentPlayingAudioUrl ==
                      currentPhoto.audioUrl) {
                    audioDuration = audioController.currentDuration;
                  }
                }
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ShareScreen(
                          imageUrl: currentPhoto.imageUrl,
                          waveformData: currentPhoto.waveformData,
                          audioDuration: audioDuration,
                          categoryName: widget.categoryName,
                        ),
                  ),
                );
              },
              icon: Image.asset(
                'assets/share_icon.png',
                width: 20.w,
                height: 20.h,
              ),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,

        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          final authController = _getAuthController;
          final currentUserId = authController.getUserId;
          final isOwner = currentUserId == photo.userID;

          // 사용자 캐시 채우기
          if (!_userProfileImages.containsKey(photo.userID)) {
            _userProfileImages[photo.userID] = _userProfileImageUrl;
            _profileLoadingStates[photo.userID] = _isLoadingProfile;
            _userNames[photo.userID] = _userName;
          }

          return PhotoCardWidgetCommon(
            photo: photo,
            categoryName: widget.categoryName,
            categoryId: widget.categoryId,
            index: index,
            isOwner: isOwner,
            isArchive: true,
            profileImagePositions: _profileImagePositions,
            droppedProfileImageUrls: _droppedProfileImageUrls,
            photoComments: _photoComments,
            userProfileImages: _userProfileImages,
            profileLoadingStates: _profileLoadingStates,
            userNames: _userNames,
            voiceCommentActiveStates: _voiceCommentActiveStates,
            voiceCommentSavedStates: _voiceCommentSavedStates,
            commentProfileImageUrls: _commentProfileImageUrls,
            onToggleAudio: _toggleAudio,
            onToggleVoiceComment: _toggleVoiceComment,
            onVoiceCommentCompleted: (
              photoId,
              audioPath,
              waveformData,
              duration,
            ) {
              if (audioPath != null &&
                  waveformData != null &&
                  duration != null) {
                _onVoiceCommentRecordingFinished(
                  photoId,
                  audioPath,
                  waveformData,
                  duration,
                );
              }
            },
            onVoiceCommentDeleted: (photoId) {
              setState(() {
                _voiceCommentActiveStates[photoId] = false;
                _pendingVoiceComments.remove(photoId);
                _pendingProfilePositions.remove(photoId);
              });
            },
            onProfileImageDragged: (photoId, absolutePosition) {
              String? latestCommentId;
              final list = _photoComments[photoId];
              if (list != null) {
                final userComments =
                    list
                        .where(
                          (comment) => comment.recorderUser == currentUserId,
                        )
                        .toList();
                if (userComments.isNotEmpty) {
                  latestCommentId = userComments.last.id;
                }
              }
              _onProfileImageDragged(
                photoId,
                absolutePosition,
                commentId: latestCommentId,
              );
            },
            onSaveRequested: _onSaveRequested,
            onSaveCompleted: _onSaveCompleted,
            onDeletePressed: () => _showDeleteDialog(photo),
            onLikePressed: _onLikePressed,
          );
        },
      ),
    );
  }

  // ================= Logic =================
  void _onPageChanged(int index) {
    final newPhotoId = widget.photos[index].id;
    setState(() {
      _currentIndex = index;
      _profileImageRefreshKey++;
    });
    _stopAudio();
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
    _loadCommentsForPhoto(newPhotoId);
  }

  Future<void> _loadCommentsForPhoto(String photoId) async {
    try {
      final controller = CommentRecordController();
      await controller.loadCommentRecordsByPhotoId(photoId);
      final comments = controller.getCommentsByPhotoId(photoId);
      final currentUserId = _authController?.currentUser?.uid;
      if (currentUserId != null) {
        _handleCommentsUpdate(photoId, currentUserId, comments);
      }
    } catch (e) {
      debugPrint('❌ 댓글 직접 로드 실패: $e');
    }
  }

  void _onAuthControllerChanged() {
    if (!mounted) return;
    setState(() => _profileImageRefreshKey++);
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
  }

  Future<void> _loadUserProfileImage() async {
    final currentPhoto = widget.photos[_currentIndex];
    try {
      final auth = _getAuthController;
      final profileImageUrl = await auth.getUserProfileImageUrlById(
        currentPhoto.userID,
      );
      final userInfo = await auth.getUserInfo(currentPhoto.userID);
      if (!mounted) return;
      setState(() {
        _userProfileImageUrl = profileImageUrl;
        _userName = userInfo?.id ?? currentPhoto.userID;
        _isLoadingProfile = false;
        _userProfileImages[currentPhoto.userID] = profileImageUrl;
        _profileLoadingStates[currentPhoto.userID] = false;
        _userNames[currentPhoto.userID] = _userName;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userName = currentPhoto.userID;
        _isLoadingProfile = false;
        _userProfileImages[currentPhoto.userID] = '';
        _profileLoadingStates[currentPhoto.userID] = false;
        _userNames[currentPhoto.userID] = currentPhoto.userID;
      });
    }
  }

  void _subscribeToVoiceCommentsForCurrentPhoto() {
    final photoId = widget.photos[_currentIndex].id;
    try {
      _commentStreams[photoId]?.cancel();
      final currentUserId = _authController?.currentUser?.uid;
      if (currentUserId == null) return;
      _commentStreams[photoId] = CommentRecordController()
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) =>
                _handleCommentsUpdate(photoId, currentUserId, comments),
          );
    } catch (e) {
      debugPrint('❌ 실시간 댓글 구독 실패($photoId): $e');
    }
  }

  void _handleCommentsUpdate(
    String photoId,
    String currentUserId,
    List<CommentRecordModel> comments,
  ) {
    if (!mounted) return;

    final userComments =
        comments
            .where((comment) => comment.recorderUser == currentUserId)
            .toList();

    setState(() {
      _photoComments[photoId] = comments;

      if (userComments.isNotEmpty) {
        _voiceCommentSavedStates[photoId] = true;

        final updatedIds = userComments.map((c) => c.id).toList();
        _savedCommentIds[photoId] = updatedIds;

        final lastComment = userComments.last;
        final lastPosition = _extractRelativeOffset(
          lastComment.relativePosition,
        );
        if (lastComment.profileImageUrl.isNotEmpty) {
          _commentProfileImageUrls[photoId] = lastComment.profileImageUrl;
          _droppedProfileImageUrls[photoId] = lastComment.profileImageUrl;
        }
        if (lastPosition != null) {
          _profileImagePositions[photoId] = lastPosition;
        }
      } else {
        _voiceCommentSavedStates[photoId] = false;
        _savedCommentIds.remove(photoId);
        _profileImagePositions.remove(photoId);
        _commentProfileImageUrls.remove(photoId);
        _droppedProfileImageUrls.remove(photoId);
        _pendingProfilePositions.remove(photoId);
        if (comments.isEmpty) {
          _photoComments[photoId] = [];
        }
      }
    });
  }

  void _onProfileImageDragged(
    String photoId,
    Offset absolutePosition, {
    String? commentId,
  }) {
    final imageSize = Size(354.w, 500.h);
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    if (mounted) {
      setState(() {
        _profileImagePositions[photoId] = relativePosition;
      });
    }

    _pendingProfilePositions[photoId] = relativePosition;

    final pending = _pendingVoiceComments[photoId];
    if (pending != null) {
      _pendingVoiceComments[photoId] = pending.copyWith(
        relativePosition: relativePosition,
      );
    }

    if (commentId != null && commentId.isNotEmpty) {
      _updateProfilePositionInFirestore(photoId, commentId, relativePosition);
    }
  }

  Future<void> _updateProfilePositionInFirestore(
    String photoId,
    String commentId,
    Offset relativePosition,
  ) async {
    try {
      if (commentId.isEmpty) return;
      await CommentRecordController().updateRelativeProfilePosition(
        commentId: commentId,
        photoId: photoId,
        relativePosition: relativePosition,
      );
    } catch (e) {
      debugPrint('❌ 프로필 위치 업데이트 실패: $e');
    }
  }

  void _toggleAudio(PhotoDataModel photo) async {
    if (photo.audioUrl.isEmpty) return;
    try {
      await _getAudioController.toggleAudio(photo.audioUrl);
    } catch (e) {
      debugPrint('❌ 오디오 토글 실패: $e');
    }
  }

  void _toggleVoiceComment(String photoId) {
    setState(() {
      final nextState = !(_voiceCommentActiveStates[photoId] ?? false);
      _voiceCommentActiveStates[photoId] = nextState;
      if (nextState) {
        _voiceCommentSavedStates[photoId] = false;
        _pendingVoiceComments.remove(photoId);
        _pendingProfilePositions.remove(photoId);
        _profileImagePositions.remove(photoId);
        _droppedProfileImageUrls.remove(photoId);
      }
    });
    debugPrint(
      'toggleVoiceComment photo:$photoId -> ${_voiceCommentActiveStates[photoId]}',
    );
  }

  Future<void> _onVoiceCommentRecordingFinished(
    String photoId,
    String audioPath,
    List<double> waveformData,
    int duration,
  ) async {
    // Feed와 동일하게: 녹음 완료 시 즉시 저장하지 않고, 사용자가 파형을 눌러 저장하도록 대기.
    try {
      final userId = _authController?.currentUser?.uid;
      if (userId == null) return;

      // 현재 로그인한 사용자의 프로필 이미지 URL 가져오기
      final currentUserProfileImageUrl = await _authController!
          .getUserProfileImageUrlWithCache(userId);

      _pendingVoiceComments[photoId] = CommentRecordModel(
        id: 'pending',
        audioUrl: audioPath,
        recorderUser: userId,
        photoId: photoId,
        waveformData: waveformData,
        duration: duration,
        profileImageUrl: currentUserProfileImageUrl, // 현재 사용자 프로필 이미지 사용
        createdAt: DateTime.now(),
        relativePosition: null,
      );
      _pendingProfilePositions.remove(photoId);
      if (mounted) {
        setState(() {
          _voiceCommentSavedStates[photoId] = false;
          _voiceCommentActiveStates[photoId] = true; // 위젯 유지
          _profileImagePositions.remove(photoId);
          _commentProfileImageUrls[photoId] = currentUserProfileImageUrl;
          _droppedProfileImageUrls.remove(photoId);
        });
      }
      debugPrint(
        'onVoiceCommentRecordingFinished photo:$photoId pending ready',
      );
    } catch (e) {
      debugPrint('❌ 음성 댓글 임시 저장 준비 실패: $e');
    }
  }

  void _onSaveRequested(String photoId) async {
    // 사용자가 파형을 눌러 저장하려 할 때 호출. pending 있으면 실제 저장.
    final pending = _pendingVoiceComments[photoId];
    if (pending == null) return;
    try {
      final userId = _authController?.currentUser?.uid;
      if (userId == null) return;

      final relativePosition = _pendingProfilePositions[photoId];
      if (relativePosition == null) {
        debugPrint(
          'onSaveRequested blocked photo:$photoId reason:no-drop-position',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사진 위 원하는 위치에 프로필을 먼저 놓아주세요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 현재 로그인한 사용자의 프로필 이미지 URL 가져오기
      final currentUserProfileImageUrl = await _authController!
          .getUserProfileImageUrlWithCache(userId);

      final controller = CommentRecordController();
      final comment = await controller.createCommentRecord(
        audioFilePath: pending.audioUrl,
        photoId: photoId,
        recorderUser: userId,
        waveformData: pending.waveformData,
        duration: pending.duration,
        profileImageUrl: currentUserProfileImageUrl, // 현재 사용자 프로필 이미지 사용
        relativePosition: relativePosition,
      );

      if (comment != null) {
        _voiceCommentSavedStates[photoId] = true;

        if (mounted) {
          setState(() {
            final existingIds = _savedCommentIds[photoId] ?? const <String>[];
            final updatedIds = <String>[
              ...existingIds.where((id) => id != comment.id),
              comment.id,
            ];
            _savedCommentIds[photoId] = updatedIds;
            _commentProfileImageUrls[photoId] = comment.profileImageUrl;
            _droppedProfileImageUrls[photoId] = comment.profileImageUrl;
            _profileImagePositions.remove(photoId);
            _pendingProfilePositions.remove(photoId);
            _pendingVoiceComments.remove(photoId);
          });
        } else {
          final existingIds = _savedCommentIds[photoId] ?? const <String>[];
          _savedCommentIds[photoId] = <String>[
            ...existingIds.where((id) => id != comment.id),
            comment.id,
          ];
          _commentProfileImageUrls[photoId] = comment.profileImageUrl;
          _droppedProfileImageUrls[photoId] = comment.profileImageUrl;
          _profileImagePositions.remove(photoId);
          _pendingProfilePositions.remove(photoId);
          _pendingVoiceComments.remove(photoId);
        }
        debugPrint(
          'onSaveRequested photo:$photoId comment:${comment.id} position:$relativePosition mounted:$mounted',
        );
      }
    } catch (e) {
      debugPrint('❌ 음성 댓글 저장 실패(사용자 요청): $e');
    }
  }

  void _onSaveCompleted(String photoId) {
    // 저장 후 액티브 종료 및 pending 정리
    setState(() {
      _voiceCommentActiveStates[photoId] = false;
      _pendingVoiceComments.remove(photoId);
      _pendingProfilePositions.remove(photoId);
      _profileImagePositions.remove(photoId);
    });
  }

  Offset? _extractRelativeOffset(dynamic relativePosition) {
    if (relativePosition == null) {
      return null;
    }
    if (relativePosition is Offset) {
      return relativePosition;
    }
    if (relativePosition is Map<String, dynamic>) {
      return PositionConverter.mapToRelativePosition(relativePosition);
    }
    return null;
  }

  void _onLikePressed() {}

  void _showDeleteDialog(PhotoDataModel photo) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xff323232),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 17.h),
                Text(
                  '사진 삭제',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500,
                    fontSize: 19.8.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  '사진 삭제하면 더 이상 해당 카테고리에서 확인할 수 없으며 삭제 후 복구가 \n불가능합니다.',
                  style: TextStyle(
                    color: const Color(0xfff9f9f9),
                    fontFamily: 'Pretendard',
                    fontSize: 15.8.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                SizedBox(
                  width: 185.5.w,
                  height: 38.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _deletePhoto(photo);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xfff5f5f5),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.2),
                      ),
                    ),
                    child: Text(
                      '삭제',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                        fontSize: 17.8.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 13.h),
                SizedBox(
                  width: (185.5).w,
                  height: 38.h,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff5a5a5a),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.2),
                      ),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                        fontSize: (17.8).sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
              ],
            ),
          ),
    );
  }

  Future<void> _deletePhoto(PhotoDataModel photo) async {
    try {
      final auth = _getAuthController;
      final currentUserId = auth.getUserId;
      if (currentUserId == null) {
        _showSnackBar('사용자 인증이 필요합니다.');
        return;
      }
      final success = await PhotoController().deletePhoto(
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

  void _handleSuccessfulDeletion(PhotoDataModel photo) {
    if (widget.photos.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      widget.photos.removeWhere((p) => p.id == photo.id);
      if (_currentIndex >= widget.photos.length) {
        _currentIndex = widget.photos.length - 1;
      }
    });
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();
  }

  Future<void> _stopAudio() async {
    await _getAudioController.stopAudio();
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          height: 30.h,
          alignment: Alignment.center,
          child: Text(
            message,
            style: TextStyle(fontFamily: 'Pretendard', fontSize: 14.sp),
          ),
        ),
        backgroundColor: backgroundColor ?? const Color(0xFF5A5A5A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  // Getters
  AuthController get _getAuthController =>
      Provider.of<AuthController>(context, listen: false);
  AudioController get _getAudioController =>
      Provider.of<AudioController>(context, listen: false);
}
