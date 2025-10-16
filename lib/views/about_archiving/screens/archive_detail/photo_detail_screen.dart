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
import '../../../common_widget/abput_photo/photo_card_widget_common.dart';

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
  final Map<String, bool> _pendingTextComments = {}; // 텍스트 댓글 pending 상태
  final Map<String, List<String>> _savedCommentIds = {};
  final Map<String, Offset> _commentPositions = {};
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

  static const List<Offset> _autoPlacementPattern = [
    Offset(0.5, 0.5),
    Offset(0.62, 0.5),
    Offset(0.38, 0.5),
    Offset(0.5, 0.62),
    Offset(0.5, 0.38),
    Offset(0.62, 0.62),
    Offset(0.38, 0.62),
    Offset(0.62, 0.38),
    Offset(0.38, 0.38),
  ];

  final Map<String, int> _autoPlacementIndices = {};

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
      resizeToAvoidBottomInset: true, // 키보드가 올라올 때 레이아웃 조정
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
            isCategory: true,
            profileImagePositions: _profileImagePositions,
            droppedProfileImageUrls: _droppedProfileImageUrls,
            photoComments: _photoComments,
            userProfileImages: _userProfileImages,
            profileLoadingStates: _profileLoadingStates,
            userNames: _userNames,
            voiceCommentActiveStates: _voiceCommentActiveStates,
            voiceCommentSavedStates: _voiceCommentSavedStates,
            commentProfileImageUrls: _commentProfileImageUrls,
            pendingTextComments: _pendingTextComments, // 텍스트 댓글 pending 상태 전달
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
            onTextCommentCompleted: (photoId, text) async {
              // 텍스트 댓글을 pending 상태로 저장
              await _onTextCommentCreated(photoId, text);
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
            onDeletePressed: () => _deletePhoto(photo),
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

        for (final comment in userComments) {
          final relative = _extractRelativeOffset(comment.relativePosition);
          if (relative != null) {
            _commentPositions[comment.id] = relative;
          }
          if (comment.profileImageUrl.isNotEmpty) {
            _commentProfileImageUrls[photoId] = comment.profileImageUrl;
          }
        }

        final lastComment = userComments.last;
        final lastPosition = _extractRelativeOffset(
          lastComment.relativePosition,
        );
        if (lastComment.profileImageUrl.isNotEmpty) {
          _droppedProfileImageUrls[photoId] = lastComment.profileImageUrl;
        }
        if (lastPosition != null) {
          _profileImagePositions[photoId] = lastPosition;
        }
      } else {
        _voiceCommentSavedStates[photoId] = false;
        final previousIds = _savedCommentIds[photoId] ?? const <String>[];
        _savedCommentIds.remove(photoId);
        _profileImagePositions.remove(photoId);
        _commentProfileImageUrls.remove(photoId);
        _droppedProfileImageUrls.remove(photoId);
        _pendingProfilePositions.remove(photoId);
        _autoPlacementIndices.remove(photoId);
        for (final commentId in previousIds) {
          _commentPositions.remove(commentId);
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
      if (mounted) {
        setState(() {
          _commentPositions[commentId] = relativePosition;
        });
      } else {
        _commentPositions[commentId] = relativePosition;
      }
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
      _voiceCommentActiveStates[photoId] =
          !(_voiceCommentActiveStates[photoId] ?? false);
    });
  }

  Future<void> _onTextCommentCreated(String photoId, String text) async {
    try {
      final userId = _authController?.currentUser?.uid;
      if (userId == null) return;

      // 1. 텍스트 댓글을 pending 상태로 저장
      final autoPosition = _generateAutoProfilePosition(photoId);
      final currentUserProfileImageUrl = await _authController!
          .getUserProfileImageUrlWithCache(userId);

      _pendingVoiceComments[photoId] = CommentRecordModel(
        id: 'pending_text',
        text: text,
        type: CommentType.text,
        audioUrl: '', // 텍스트 댓글은 오디오 없음
        waveformData: [], // 텍스트 댓글은 파형 데이터 없음
        duration: 0, // 텍스트 댓글은 duration 없음
        recorderUser: userId,
        photoId: photoId,
        profileImageUrl: currentUserProfileImageUrl,
        createdAt: DateTime.now(),
        relativePosition: autoPosition,
      );
      _pendingProfilePositions[photoId] = autoPosition;

      debugPrint('✅ 텍스트 댓글 임시 저장 완료');

      // 2. pending 상태 업데이트
      if (mounted) {
        setState(() {
          _pendingTextComments[photoId] = true;
          _voiceCommentSavedStates[photoId] = false;
          _profileImagePositions[photoId] = autoPosition;
          _commentProfileImageUrls[photoId] = currentUserProfileImageUrl;
        });
      }
    } catch (e) {
      debugPrint('❌ 텍스트 댓글 임시 저장 실패: $e');
    }
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

      final autoPosition = _generateAutoProfilePosition(photoId);

      _pendingVoiceComments[photoId] = CommentRecordModel(
        id: 'pending',
        audioUrl: audioPath,
        recorderUser: userId,
        photoId: photoId,
        waveformData: waveformData,
        duration: duration,
        profileImageUrl: currentUserProfileImageUrl, // 현재 사용자 프로필 이미지 사용
        createdAt: DateTime.now(),
        relativePosition: autoPosition,
      );
      _pendingProfilePositions[photoId] = autoPosition;
      if (mounted) {
        setState(() {
          _voiceCommentSavedStates[photoId] = false;
          _voiceCommentActiveStates[photoId] = true; // 위젯 유지
          _profileImagePositions[photoId] = autoPosition;
          _commentProfileImageUrls[photoId] = currentUserProfileImageUrl;
        });
      }
    } catch (e) {
      debugPrint('음성 댓글 임시 저장 준비 실패: $e');
    }
  }

  Future<void> _onSaveRequested(String photoId) async {
    final pending = _pendingVoiceComments[photoId];
    if (pending == null) {
      throw StateError('임시 댓글이 없습니다. photoId: $photoId');
    }

    try {
      final userId = _authController?.currentUser?.uid;
      if (userId == null) {
        throw StateError('로그인된 사용자를 찾을 수 없습니다.');
      }

      final currentUserProfileImageUrl = await _authController!
          .getUserProfileImageUrlWithCache(userId);

      final relativePosition =
          _pendingProfilePositions[photoId] ??
          pending.relativePosition ??
          _generateAutoProfilePosition(photoId);

      _pendingProfilePositions[photoId] = relativePosition;

      final controller = CommentRecordController();

      // 텍스트 댓글인지 음성 댓글인지 확인
      final comment =
          pending.type == CommentType.text
              ? await controller.createTextComment(
                text: pending.text ?? '',
                photoId: photoId,
                recorderUser: userId,
                profileImageUrl: currentUserProfileImageUrl,
                relativePosition: relativePosition,
              )
              : await controller.createCommentRecord(
                audioFilePath: pending.audioUrl,
                photoId: photoId,
                recorderUser: userId,
                waveformData: pending.waveformData,
                duration: pending.duration,
                profileImageUrl: currentUserProfileImageUrl,
                relativePosition: relativePosition,
              );

      if (comment == null) {
        if (mounted) {
          controller.showErrorToUser(context);
        }
        throw Exception('댓글 저장에 실패했습니다. photoId: $photoId');
      }

      _commentPositions[comment.id] =
          comment.relativePosition ?? relativePosition;
      _voiceCommentSavedStates[photoId] = true;

      final existingIds = _savedCommentIds[photoId] ?? const <String>[];
      final updatedIds = <String>[
        ...existingIds.where((id) => id != comment.id),
        comment.id,
      ];

      void applyUpdates() {
        _savedCommentIds[photoId] = updatedIds;
        _commentProfileImageUrls[photoId] = comment.profileImageUrl;
        _droppedProfileImageUrls[photoId] = comment.profileImageUrl;
        _profileImagePositions.remove(photoId);
        _pendingProfilePositions.remove(photoId);
        _pendingVoiceComments.remove(photoId);
        _pendingTextComments.remove(photoId); // 텍스트 댓글 pending 상태 제거

        /// 추가: 저장 직후 다시 아이콘 모드로 돌려주기
        _voiceCommentActiveStates[photoId] = false;
      }

      if (mounted) {
        setState(applyUpdates);
      } else {
        applyUpdates();
      }

      unawaited(_loadCommentsForPhoto(photoId));
    } catch (e) {
      debugPrint('❌ 댓글 저장 실패(사용자 요청): $e');
      rethrow;
    }
  }

  void _onSaveCompleted(String photoId) {
    // 저장 후 액티브 종료 및 pending 정리
    setState(() {
      _voiceCommentActiveStates[photoId] = false;
      _pendingVoiceComments.remove(photoId);
      _pendingTextComments.remove(photoId); // 텍스트 댓글 pending 상태 제거
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

  Offset _generateAutoProfilePosition(String photoId) {
    final occupiedPositions = <Offset>[];

    final comments = _photoComments[photoId] ?? const <CommentRecordModel>[];
    for (final comment in comments) {
      final position = _extractRelativeOffset(comment.relativePosition);
      if (position != null) {
        occupiedPositions.add(position);
      }
    }

    final savedCommentIds = _savedCommentIds[photoId] ?? const <String>[];
    for (final commentId in savedCommentIds) {
      final cachedPosition = _commentPositions[commentId];
      if (cachedPosition != null) {
        occupiedPositions.add(cachedPosition);
      }
    }

    final previewPosition = _profileImagePositions[photoId];
    if (previewPosition != null) {
      occupiedPositions.add(previewPosition);
    }

    final pendingPosition = _pendingProfilePositions[photoId];
    if (pendingPosition != null) {
      occupiedPositions.add(pendingPosition);
    }

    const maxAttempts = 30;
    final patternLength = _autoPlacementPattern.length;
    final startingIndex = _autoPlacementIndices[photoId] ?? 0;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final rawIndex = startingIndex + attempt;
      final baseOffset = _autoPlacementPattern[rawIndex % patternLength];
      final loop = rawIndex ~/ patternLength;
      final candidate = _applyJitter(baseOffset, loop, attempt);

      if (!_isPositionTooClose(candidate, occupiedPositions)) {
        _autoPlacementIndices[photoId] = rawIndex + 1;
        return candidate;
      }
    }

    _autoPlacementIndices[photoId] = startingIndex + 1;
    return const Offset(0.5, 0.5);
  }

  Offset _applyJitter(Offset base, int loop, int attempt) {
    if (loop <= 0) {
      return _clampOffset(base);
    }

    final double step = (0.02 * loop).clamp(0.02, 0.08).toDouble();
    final double dxDirection = (attempt % 2 == 0) ? 1 : -1;
    final double dyDirection = ((attempt ~/ 2) % 2 == 0) ? 1 : -1;

    final offsetWithJitter = Offset(
      base.dx + (step * dxDirection),
      base.dy + (step * dyDirection),
    );

    return _clampOffset(offsetWithJitter);
  }

  Offset _clampOffset(Offset offset) {
    const double min = 0.05;
    const double max = 0.95;
    return Offset(
      offset.dx.clamp(min, max).toDouble(),
      offset.dy.clamp(min, max).toDouble(),
    );
  }

  bool _isPositionTooClose(Offset candidate, List<Offset> occupied) {
    const double threshold = 0.04;
    for (final existing in occupied) {
      if ((candidate.dx - existing.dx).abs() < threshold &&
          (candidate.dy - existing.dy).abs() < threshold) {
        return true;
      }
    }
    return false;
  }

  void _onLikePressed() {}

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
        permanentDelete: false, // 소프트 삭제로 변경
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
