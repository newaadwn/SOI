import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';
import '../../controllers/audio_controller.dart';
import '../../controllers/comment_audio_controller.dart';
import '../../controllers/comment_record_controller.dart';
import '../../models/photo_data_model.dart';
import '../../models/comment_record_model.dart';
import '../../utils/position_converter.dart';
import '../common_widget/photo_card_widget_common.dart';

class FeedHomeScreen extends StatefulWidget {
  const FeedHomeScreen({super.key});

  @override
  State<FeedHomeScreen> createState() => _FeedHomeScreenState();
}

class _FeedHomeScreenState extends State<FeedHomeScreen> {
  // 데이터 관리
  List<Map<String, dynamic>> _allPhotos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // 프로필 정보 캐싱
  final Map<String, String> _userProfileImages = {};
  final Map<String, String> _userNames = {};
  final Map<String, bool> _profileLoadingStates = {};

  // 음성 댓글 상태 관리 (다중 댓글 지원)
  final Map<String, bool> _voiceCommentActiveStates = {};
  final Map<String, bool> _voiceCommentSavedStates = {};
  final Map<String, List<String>> _savedCommentIds = {}; // 사진별 여러 댓글 ID 저장

  // 임시 음성 댓글 데이터 (파형 클릭 시 저장용)
  final Map<String, Map<String, dynamic>> _pendingVoiceComments = {};

  // 임시 프로필 위치 (음성 댓글 저장 전 드래그된 위치)
  final Map<String, Offset> _pendingProfilePositions = {};

  // 프로필 이미지 관리 (다중 댓글 지원)
  final Map<String, Offset?> _profileImagePositions = {}; // 임시 위치용 (기존 호환성)
  final Map<String, String> _commentProfileImageUrls = {}; // 임시용 (기존 호환성)
  final Map<String, String> _droppedProfileImageUrls = {}; // 임시용 (기존 호환성)

  // 댓글별 개별 관리 (새로운 구조)
  final Map<String, Offset> _commentPositions = {}; // 댓글 ID -> 위치
  final Map<String, String> _commentProfileUrls = {}; // 댓글 ID -> 프로필 URL

  // 실시간 스트림 관리
  final Map<String, List<CommentRecordModel>> _photoComments = {};
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

  // 컨트롤러 참조
  AuthController? _authController;
  CommentAudioController? _commentAudioController;

  @override
  void initState() {
    super.initState();
    _loadUserCategoriesAndPhotos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController = Provider.of<AuthController>(context, listen: false);
      _authController!.addListener(_onAuthControllerChanged);

      // CommentAudioController 초기화
      _commentAudioController = Provider.of<CommentAudioController>(
        context,
        listen: false,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authController ??= Provider.of<AuthController>(context, listen: false);
    _commentAudioController ??= Provider.of<CommentAudioController>(
      context,
      listen: false,
    );
  }

  @override
  void dispose() {
    _authController?.removeListener(_onAuthControllerChanged);

    // CommentAudioController 정리
    _commentAudioController?.stopAllComments();

    for (var subscription in _commentStreams.values) {
      subscription.cancel();
    }
    _commentStreams.clear();
    super.dispose();
  }

  /// AuthController 변경 감지 시 프로필 이미지 캐시 업데이트
  void _onAuthControllerChanged() async {
    final currentUser = _authController?.currentUser;
    if (currentUser != null) {
      final newProfileImageUrl = await _authController!
          .getUserProfileImageUrlWithCache(currentUser.uid);
      if (_userProfileImages[currentUser.uid] != newProfileImageUrl) {
        setState(
          () => _userProfileImages[currentUser.uid] = newProfileImageUrl,
        );
      }
    }
  }

  /// 특정 사용자의 프로필 이미지 캐시 강제 리프레시
  Future<void> refreshUserProfileImage(String userId) async {
    final authController = Provider.of<AuthController>(context, listen: false);
    try {
      setState(() => _profileLoadingStates[userId] = true);
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(userId);
      setState(() {
        _userProfileImages[userId] = profileImageUrl;
        _profileLoadingStates[userId] = false;
      });
    } catch (e) {
      setState(() => _profileLoadingStates[userId] = false);
    }
  }

  /// 사용자가 속한 카테고리들과 해당 사진들을 모두 로드 (초기 로드)
  Future<void> _loadUserCategoriesAndPhotos() async {
    try {
      setState(() {
        _isLoading = true;
        _allPhotos.clear();
        _hasMoreData = true;
      });

      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );
      final photoController = Provider.of<PhotoController>(
        context,
        listen: false,
      );

      final currentUserId = authController.getUserId;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('로그인된 사용자를 찾을 수 없습니다.');
      }

      await _loadCurrentUserProfile(authController, currentUserId);

      // 사용자가 속한 카테고리들 가져오기

      await categoryController.loadUserCategories(
        currentUserId,
        forceReload: true,
      );

      final userCategories = categoryController.userCategories;

      if (userCategories.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasMoreData = false;
        });
        return;
      }

      // PhotoController의 무한 스크롤 초기 로드 사용 (5개)
      final categoryIds = userCategories.map((c) => c.id).toList();

      await photoController.loadPhotosFromAllCategoriesInitial(categoryIds);

      // PhotoController의 데이터를 UI용 형태로 변환
      final List<Map<String, dynamic>> photoDataList = [];
      for (PhotoDataModel photo in photoController.photos) {
        final category = userCategories.firstWhere(
          (c) => c.id == photo.categoryId,
          orElse: () => userCategories.first,
        );
        photoDataList.add({
          'photo': photo,
          'categoryName': category.name,
          'categoryId': category.id,
        });
      }

      setState(() {
        _allPhotos = photoDataList;
        _hasMoreData = photoController.hasMore;
        _isLoading = false;
      });

      // 로드된 사진들의 프로필 정보 및 음성 댓글 구독
      for (Map<String, dynamic> photoData in photoDataList) {
        final PhotoDataModel photo = photoData['photo'] as PhotoDataModel;
        _loadUserProfileForPhoto(photo.userID);
        _subscribeToVoiceCommentsForPhoto(photo.id, currentUserId);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasMoreData = false;
      });
    }
  }

  /// 더 많은 사진 로드 (무한 스크롤링)
  Future<void> _loadMorePhotos() async {
    if (_isLoadingMore || !_hasMoreData) return;

    try {
      setState(() => _isLoadingMore = true);

      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );
      final photoController = Provider.of<PhotoController>(
        context,
        listen: false,
      );

      final currentUserId = authController.getUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        setState(() => _isLoadingMore = false);
        return;
      }

      // 사용자가 속한 카테고리들 가져오기
      final userCategories = categoryController.userCategories;
      if (userCategories.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _hasMoreData = false;
        });
        return;
      }

      // PhotoController의 무한 스크롤 추가 로드 사용 (10개)
      final categoryIds = userCategories.map((c) => c.id).toList();

      // 로드 전 현재 사진 개수 저장
      final previousPhotoCount = photoController.photos.length;

      await photoController.loadMorePhotos(categoryIds);

      // 로드 후 새로 추가된 사진만 가져오기
      final allPhotos = photoController.photos;
      final newPhotos = allPhotos.sublist(previousPhotoCount);

      // 새로 로드된 사진들을 UI용 형태로 변환
      final List<Map<String, dynamic>> newPhotoDataList = [];
      for (PhotoDataModel photo in newPhotos) {
        final category = userCategories.firstWhere(
          (c) => c.id == photo.categoryId,
          orElse: () => userCategories.first,
        );
        newPhotoDataList.add({
          'photo': photo,
          'categoryName': category.name,
          'categoryId': category.id,
        });
      }

      setState(() {
        _allPhotos.addAll(newPhotoDataList);
        _hasMoreData = photoController.hasMore;
        _isLoadingMore = false;
      });

      // 새로 로드된 사진들의 프로필 정보 및 음성 댓글 구독
      for (Map<String, dynamic> photoData in newPhotoDataList) {
        final PhotoDataModel photo = photoData['photo'] as PhotoDataModel;
        _loadUserProfileForPhoto(photo.userID);
        _subscribeToVoiceCommentsForPhoto(photo.id, currentUserId);
      }
    } catch (e) {
      debugPrint('❌ 추가 사진 로드 실패: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  /// 현재 사용자 프로필 로드
  Future<void> _loadCurrentUserProfile(
    AuthController authController,
    String currentUserId,
  ) async {
    if (!_userProfileImages.containsKey(currentUserId)) {
      try {
        final currentUserProfileImage = await authController
            .getUserProfileImageUrlWithCache(currentUserId);
        setState(
          () => _userProfileImages[currentUserId] = currentUserProfileImage,
        );
      } catch (e) {
        debugPrint('[ERROR] 현재 사용자 프로필 이미지 로드 실패: $e');
      }
    }
  }

  /// 특정 사용자의 프로필 정보를 로드하는 메서드
  Future<void> _loadUserProfileForPhoto(String userId) async {
    if (_profileLoadingStates[userId] == true ||
        _userNames.containsKey(userId)) {
      return;
    }

    setState(() => _profileLoadingStates[userId] = true);

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(userId);
      final userInfo = await authController.getUserInfo(userId);

      if (mounted) {
        setState(() {
          _userProfileImages[userId] = profileImageUrl;
          _userNames[userId] = userInfo?.id ?? userId;
          _profileLoadingStates[userId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userNames[userId] = userId;
          _profileLoadingStates[userId] = false;
        });
      }
    }
  }

  /// 특정 사진의 음성 댓글 정보를 실시간 구독하여 프로필 위치 동기화
  void _subscribeToVoiceCommentsForPhoto(String photoId, String currentUserId) {
    try {
      _commentStreams[photoId]?.cancel();

      _commentStreams[photoId] = CommentRecordController()
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) =>
                _handleCommentsUpdate(photoId, currentUserId, comments),
          );

      // 실시간 스트림과 별개로 기존 댓글도 직접 로드
      _loadExistingCommentsForPhoto(photoId, currentUserId);
    } catch (e) {
      debugPrint('❌ Feed - 실시간 댓글 구독 시작 실패 - 사진 $photoId: $e');
    }
  }

  /// 특정 사진의 기존 댓글을 직접 로드 (실시간 스트림과 별개)
  Future<void> _loadExistingCommentsForPhoto(
    String photoId,
    String currentUserId,
  ) async {
    try {
      final commentController = CommentRecordController();
      await commentController.loadCommentRecordsByPhotoId(photoId);
      final comments = commentController.getCommentsByPhotoId(photoId);

      if (mounted && comments.isNotEmpty) {
        _handleCommentsUpdate(photoId, currentUserId, comments);
      }
    } catch (e) {
      debugPrint('❌ Feed - 기존 댓글 직접 로드 실패: $e');
    }
  }

  /// 댓글 업데이트 처리 (다중 댓글 지원)
  void _handleCommentsUpdate(
    String photoId,
    String currentUserId,
    List<CommentRecordModel> comments,
  ) {
    if (mounted) {
      setState(() {
        _photoComments[photoId] = comments;
      });
    }

    // 현재 사용자의 모든 댓글 처리 (다중 댓글 지원)
    final userComments =
        comments
            .where((comment) => comment.recorderUser == currentUserId)
            .toList();

    if (userComments.isNotEmpty) {
      if (mounted) {
        setState(() {
          // 사진별 댓글 ID 목록 업데이트 (중복 방지 및 정렬)
          final existingCommentIds = _savedCommentIds[photoId] ?? [];
          final newCommentIds = userComments.map((c) => c.id).toSet().toList();

          // 기존 댓글과 새 댓글을 합치되 중복 제거
          final allCommentIds =
              <dynamic>{...existingCommentIds, ...newCommentIds}.toList();

          // 댓글 id를 정렬하는 함수
          allCommentIds.sort();

          // 중복 제거된 댓글 ID 목록 저장
          _savedCommentIds[photoId] = allCommentIds.cast<String>();

          // 각 댓글의 위치와 프로필 정보 저장 (기존 위치 절대 덮어쓰지 않음)
          for (final comment in userComments) {
            // 기존에 위치가 저장되어 있으면 절대 변경하지 않음
            if (_commentPositions.containsKey(comment.id)) {
              continue;
            }

            // 새로운 댓글인 경우에만 위치 설정
            if (comment.relativePosition != null) {
              _commentPositions[comment.id] = comment.relativePosition!;
            } else {
              // Firestore에서 위치 정보가 없는 경우 기본값
              _commentPositions[comment.id] = Offset.zero;
            }

            // 프로필 이미지 URL 업데이트 (새 댓글인 경우에만)
            if (comment.profileImageUrl.isNotEmpty &&
                !_commentProfileUrls.containsKey(comment.id)) {
              _commentProfileUrls[comment.id] = comment.profileImageUrl;
            }
          }

          // 기존 호환성을 위해 마지막 댓글의 정보를 기존 변수에도 저장
          final lastComment = userComments.last;
          if (lastComment.profileImageUrl.isNotEmpty) {
            _commentProfileImageUrls[photoId] = lastComment.profileImageUrl;
          }

          if (lastComment.relativePosition != null) {
            // relativePosition 필드에서 상대 위치 데이터를 읽어옴
            Offset relativePosition;

            if (lastComment.relativePosition is Map<String, dynamic>) {
              // Map 형태의 상대 위치 데이터를 Offset으로 변환
              relativePosition = PositionConverter.mapToRelativePosition(
                lastComment.relativePosition as Map<String, dynamic>,
              );
            } else {
              // 이미 Offset 형태
              relativePosition = lastComment.relativePosition!;
            }

            _profileImagePositions[photoId] = relativePosition;
            _droppedProfileImageUrls[photoId] = lastComment.profileImageUrl;
          }
        });
      }
    } else {
      // 현재 사용자의 댓글이 없는 경우 상태 초기화
      if (mounted) {
        setState(() {
          _voiceCommentSavedStates[photoId] = false;
          _savedCommentIds.remove(photoId);
          _profileImagePositions[photoId] = null;
          _commentProfileImageUrls.remove(photoId);
          // 다른 사용자의 댓글은 유지하되 현재 사용자 관련 상태만 초기화
          if (comments.isEmpty) {
            _photoComments[photoId] = [];
          }
        });
      }
    }
  }

  /// 오디오 재생/일시정지 토글
  Future<void> _toggleAudio(PhotoDataModel photo) async {
    if (photo.audioUrl.isEmpty) {
      return;
    }

    try {
      await Provider.of<AudioController>(
        context,
        listen: false,
      ).toggleAudio(photo.audioUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('음성 파일을 재생할 수 없습니다: $e'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
    }
  }

  /// 음성 댓글 토글
  void _toggleVoiceComment(String photoId) {
    setState(
      () =>
          _voiceCommentActiveStates[photoId] =
              !(_voiceCommentActiveStates[photoId] ?? false),
    );
  }

  /// 음성 댓글 녹음 완료 콜백 (임시 저장)
  Future<void> _onVoiceCommentCompleted(
    String photoId,
    String? audioPath,
    List<double>? waveformData,
    int? duration,
  ) async {
    if (audioPath == null || waveformData == null || duration == null) {
      return;
    }

    // 임시 저장 (파형 클릭 시 실제 저장)
    setState(() {
      _pendingVoiceComments[photoId] = {
        'audioPath': audioPath,
        'waveformData': waveformData,
        'duration': duration,
      };
    });
  }

  /// 실제 음성 댓글 저장 (파형 클릭 시 호출)
  Future<void> _saveVoiceComment(String photoId) async {
    final pendingData = _pendingVoiceComments[photoId];
    if (pendingData == null) {
      return;
    }

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final commentRecordController = CommentRecordController();
      final currentUserId = authController.getUserId;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('로그인된 사용자를 찾을 수 없습니다.');
      }

      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(currentUserId);

      // 현재 드래그된 위치를 사용 (각 댓글마다 고유한 위치)
      final currentProfilePosition =
          _profileImagePositions[photoId] ?? _pendingProfilePositions[photoId];

      final commentRecord = await commentRecordController.createCommentRecord(
        audioFilePath: pendingData['audioPath'],
        photoId: photoId,
        recorderUser: currentUserId,
        waveformData: pendingData['waveformData'],
        duration: pendingData['duration'],
        profileImageUrl: profileImageUrl,
        relativePosition: currentProfilePosition,
      );

      if (commentRecord != null) {
        if (mounted) {
          setState(() {
            _voiceCommentSavedStates[photoId] = true;

            // 다중 댓글 지원: 기존 댓글 목록에 새 댓글 추가 (중복 방지)
            if (_savedCommentIds[photoId] == null) {
              _savedCommentIds[photoId] = [commentRecord.id];
            } else {
              // 중복 확인 후 추가
              if (!_savedCommentIds[photoId]!.contains(commentRecord.id)) {
                _savedCommentIds[photoId]!.add(commentRecord.id);
              }
            }

            // 새 댓글의 고유 위치 저장 (기존 댓글 위치에 영향 없음)
            _commentPositions[commentRecord.id] = currentProfilePosition!;
            _commentProfileUrls[commentRecord.id] = profileImageUrl;

            // 임시 데이터 삭제
            _pendingVoiceComments.remove(photoId);
            _pendingProfilePositions.remove(photoId);

            // 다음 댓글을 위해 위치 초기화 (기존 댓글은 건드리지 않음)
            _profileImagePositions[photoId] = null;
          });
        }
      } else {
        if (mounted) {
          commentRecordController.showErrorToUser(context);
        }
      }
    } catch (e) {
      debugPrint("음성 댓글 저장 중 오류 발생: $e");
    }
  }

  /// 음성 댓글 삭제 콜백
  void _onVoiceCommentDeleted(String photoId) {
    setState(() {
      _voiceCommentActiveStates[photoId] = false;
      _voiceCommentSavedStates[photoId] = false;
      _profileImagePositions[photoId] = null;
    });
  }

  /// 음성 댓글 저장 완료 후 위젯 초기화 (추가 댓글을 위한)
  void _onSaveCompleted(String photoId) {
    setState(() {
      // 저장 완료 후 다시 버튼 상태로 돌아가서 추가 댓글 녹음 가능
      _voiceCommentActiveStates[photoId] = false;
      // _voiceCommentSavedStates는 건드리지 않음 (실제 댓글이 저장되어 있으므로)
      // 임시 데이터 정리
      _pendingVoiceComments.remove(photoId);
      _pendingProfilePositions.remove(photoId);
    });
  }

  /// 프로필 이미지 드래그 처리 (절대 위치를 상대 위치로 변환하여 저장)
  void _onProfileImageDragged(String photoId, Offset absolutePosition) {
    // 이미지 크기 (ScreenUtil 기준 - PhotoDisplayWidget과 동일하게)
    final imageSize = Size(354.w, 500.h);

    // 절대 위치를 상대 위치로 변환 (0.0 ~ 1.0 범위)
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    // UI에 즉시 반영 (임시 위치)
    setState(() {
      _profileImagePositions[photoId] = relativePosition;
      _pendingProfilePositions[photoId] = relativePosition;
    });

    // 음성 댓글이 이미 저장된 경우에만 즉시 Firestore 업데이트
    final isSaved = _voiceCommentSavedStates[photoId] == true;
    if (isSaved) {
      // 가장 최근 댓글에 위치 업데이트
      final commentIds = _savedCommentIds[photoId];
      if (commentIds != null && commentIds.isNotEmpty) {
        final latestCommentId = commentIds.last;
        _updateProfilePositionInFirestore(
          photoId,
          relativePosition,
          latestCommentId,
        );
      }
    }
  }

  /// Firestore에 프로필 위치 업데이트
  Future<void> _updateProfilePositionInFirestore(
    String photoId,
    Offset position,
    String latestCommentId, {
    int retryCount = 0,
    int maxRetries = 3,
  }) async {
    try {
      final isSaved = _voiceCommentSavedStates[photoId] == true;

      if (!isSaved) {
        if (retryCount < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
          return _updateProfilePositionInFirestore(
            photoId,
            position,
            latestCommentId,
            retryCount: retryCount + 1,
          );
        } else {
          return;
        }
      }

      final commentRecordController = CommentRecordController();
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        return;
      }

      // 저장된 댓글 ID 확인 및 사용
      final savedCommentIds = _savedCommentIds[photoId];
      String targetCommentId = latestCommentId;

      if (targetCommentId.isEmpty) {
        // 파라미터가 없으면 저장된 댓글 목록에서 가장 최근 댓글 사용
        if (savedCommentIds != null && savedCommentIds.isNotEmpty) {
          targetCommentId = savedCommentIds.last;
        }
      }

      if (targetCommentId.isNotEmpty) {
        // 상대 위치를 Map 형태로 변환해서 Firestore에 저장
        PositionConverter.relativePositionToMap(position);

        final success = await commentRecordController
            .updateRelativeProfilePosition(
              commentId: targetCommentId,
              photoId: photoId,
              relativePosition: position, // 상대 위치로 전달
            );

        // 프로필 위치 업데이트 성공 후 위젯 초기화 (추가 댓글을 위한 준비)
        if (success) {
          _onSaveCompleted(photoId);
        }
        return;
      }

      // 저장된 댓글 ID가 없는 경우 재시도 또는 검색
      if (retryCount < maxRetries) {
        await Future.delayed(const Duration(seconds: 1));
        return _updateProfilePositionInFirestore(
          photoId,
          position,
          latestCommentId,
        );
      }

      // 최종적으로 캐시/서버에서 댓글 찾기
      await _findAndUpdateCommentPosition(
        commentRecordController,
        photoId,
        currentUserId,
        position,
      );
    } catch (e) {
      return;
    }
  }

  /// 댓글을 찾아서 위치 업데이트
  Future<void> _findAndUpdateCommentPosition(
    CommentRecordController commentRecordController,
    String photoId,
    String currentUserId,
    Offset position,
  ) async {
    var comments = commentRecordController.getCommentsByPhotoId(photoId);

    if (comments.isEmpty) {
      await commentRecordController.loadCommentRecordsByPhotoId(photoId);
      comments = commentRecordController.commentRecords;
    }

    final userComment =
        comments
            .where((comment) => comment.recorderUser == currentUserId)
            .firstOrNull;

    if (userComment != null) {
      await commentRecordController.updateRelativeProfilePosition(
        commentId: userComment.id,
        photoId: photoId,
        relativePosition: position,
      );

      // 프로필 위치 업데이트 성공 후 위젯 초기화 (추가 댓글을 위한 준비)

      _onSaveCompleted(photoId);
    } else {
      return;
    }
  }

  void _stopAllAudio() {
    // 1. 게시물 오디오 중지
    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );
    audioController.stopAudio();

    // 2. 음성 댓글 오디오 중지
    final commentAudioController = Provider.of<CommentAudioController>(
      context,
      listen: false,
    );
    commentAudioController.stopAllComments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_allPhotos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 80),
            SizedBox(height: 16.h),
            Text(
              '아직 사진이 없어요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '친구들과 카테고리를 만들고\n첫 번째 사진을 공유해보세요!',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserCategoriesAndPhotos,
      color: Colors.white,
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: _allPhotos.length + (_hasMoreData ? 1 : 0),
            onPageChanged: (index) {
              // 마지막에서 2번째 페이지에 도달하면 추가 로드
              if (index >= _allPhotos.length - 2 &&
                  _hasMoreData &&
                  !_isLoadingMore) {
                _loadMorePhotos();
              }

              // 페이지 변경 시 모든 오디오 중지
              _stopAllAudio();
            },
            itemBuilder: (context, index) {
              final photoData = _allPhotos[index];
              final PhotoDataModel photo = photoData['photo'] as PhotoDataModel;
              final String categoryName = photoData['categoryName'] as String;
              final String categoryId = photoData['categoryId'] as String;
              final currentUserId = _authController?.getUserId;
              final isOwner =
                  currentUserId != null && currentUserId == photo.userID;

              return PhotoCardWidgetCommon(
                photo: photo,
                categoryName: categoryName,
                categoryId: categoryId,
                index: index,
                isOwner: isOwner,
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
                onVoiceCommentCompleted: _onVoiceCommentCompleted,
                onVoiceCommentDeleted: _onVoiceCommentDeleted,
                onProfileImageDragged: _onProfileImageDragged,
                onSaveRequested: _saveVoiceComment,
                onSaveCompleted: _onSaveCompleted,
                onDeletePressed: () async {
                  try {
                    final photoController = Provider.of<PhotoController>(
                      context,
                      listen: false,
                    );
                    final authController = Provider.of<AuthController>(
                      context,
                      listen: false,
                    );
                    final userId = authController.getUserId;
                    if (userId == null) return;

                    final success = await photoController.deletePhoto(
                      categoryId: categoryId,
                      photoId: photo.id,
                      userId: userId,
                    );
                    if (success && mounted) {
                      setState(() {
                        _allPhotos.removeAt(index);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('사진이 삭제되었습니다.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else if (!success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('사진 삭제에 실패했습니다.'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    throw Exception('사진 삭제 중 오류 발생: $e');
                  }
                },
                onLikePressed: () {
                  // TODO: 좋아요 토글 구현 (서비스/컨트롤러 추가 필요)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('좋아요 기능 준비 중입니다.'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
