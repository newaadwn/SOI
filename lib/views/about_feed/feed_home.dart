import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';
import '../../controllers/audio_controller.dart';
import '../../controllers/comment_record_controller.dart';
import '../../models/photo_data_model.dart';
import '../../models/comment_record_model.dart';
import '../../utils/format_utils.dart';
import '../about_archiving/widgets/custom_waveform_widget.dart';
import 'widgets/voice_comment_widget.dart';

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

  // 음성 댓글 상태 관리
  final Map<String, bool> _voiceCommentActiveStates = {};
  final Map<String, bool> _voiceCommentSavedStates = {};
  final Map<String, String> _savedCommentIds = {};

  // 프로필 이미지 관리
  final Map<String, Offset?> _profileImagePositions = {};
  final Map<String, String> _commentProfileImageUrls = {};
  final Map<String, String> _droppedProfileImageUrls = {};

  // 실시간 스트림 관리
  final Map<String, List<CommentRecordModel>> _photoComments = {};
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

  // 컨트롤러 참조
  AuthController? _authController;

  @override
  void initState() {
    super.initState();
    _loadUserCategoriesAndPhotos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController = Provider.of<AuthController>(context, listen: false);
      _authController!.addListener(_onAuthControllerChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authController ??= Provider.of<AuthController>(context, listen: false);
  }

  @override
  void dispose() {
    _authController?.removeListener(_onAuthControllerChanged);
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
      debugPrint('🔄 [FEED] 사진 로드 시작...');
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
      debugPrint('👤 [FEED] 현재 사용자 ID 확인: $currentUserId');

      if (currentUserId == null || currentUserId.isEmpty) {
        debugPrint('❌ [FEED] 사용자 ID가 없음!');
        throw Exception('로그인된 사용자를 찾을 수 없습니다.');
      }

      debugPrint('[FEED] 현재 사용자 ID: $currentUserId');

      await _loadCurrentUserProfile(authController, currentUserId);

      // 사용자가 속한 카테고리들 가져오기
      debugPrint('📁 [FEED] 카테고리 로드 시작...');
      debugPrint(
        '📁 [FEED] 로드 전 카테고리 수: ${categoryController.userCategories.length}',
      );
      await categoryController.loadUserCategories(
        currentUserId,
        forceReload: true,
      );
      debugPrint(
        '📁 [FEED] 로드 후 즉시 카테고리 수: ${categoryController.userCategories.length}',
      );
      final userCategories = categoryController.userCategories;
      debugPrint('📁 사용자가 속한 카테고리 수: ${userCategories.length}');

      if (userCategories.isNotEmpty) {
        debugPrint('📁 카테고리 목록:');
        for (var cat in userCategories) {
          debugPrint('  - ${cat.name} (${cat.id})');
        }
      }

      if (userCategories.isEmpty) {
        debugPrint('⚠️ [FEED] 카테고리가 없음!');
        setState(() {
          _isLoading = false;
          _hasMoreData = false;
        });
        return;
      }

      // PhotoController의 무한 스크롤 초기 로드 사용 (5개)
      final categoryIds = userCategories.map((c) => c.id).toList();
      debugPrint('🖼️ [FEED] 사진 로드 시작 - 카테고리 ID: $categoryIds');
      await photoController.loadPhotosFromAllCategoriesInitial(categoryIds);

      debugPrint(
        '🖼️ [FEED] PhotoController에서 로드된 사진 수: ${photoController.photos.length}',
      );

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
        debugPrint('  - 사진 추가: ${photo.id} in ${category.name}');
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

      debugPrint('✅ 초기 사진 로드 완료: ${_allPhotos.length}개, 더 있음: $_hasMoreData');
    } catch (e, stackTrace) {
      debugPrint('❌ 사진 로드 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
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

      debugPrint(
        '✅ 추가 사진 로드 완료: +${newPhotoDataList.length}개, 총 ${_allPhotos.length}개, 더 있음: $_hasMoreData',
      );
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
        debugPrint(
          '[PROFILE] 현재 사용자 프로필 이미지 로드됨: $currentUserId -> $currentUserProfileImage',
        );
      } catch (e) {
        debugPrint('[ERROR] 현재 사용자 프로필 이미지 로드 실패: $e');
      }
    }
  }

  /// 특정 사용자의 프로필 정보를 로드하는 메서드
  Future<void> _loadUserProfileForPhoto(String userId) async {
    if (_profileLoadingStates[userId] == true || _userNames.containsKey(userId))
      return;

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
      debugPrint('프로필 정보 로드 실패 (userId: $userId): $e');
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
      debugPrint('음성 댓글 실시간 구독 시작 - 사진: $photoId, 사용자: $currentUserId');

      _commentStreams[photoId]?.cancel();

      _commentStreams[photoId] = CommentRecordController()
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) =>
                _handleCommentsUpdate(photoId, currentUserId, comments),
            onError:
                (error) => debugPrint('실시간 댓글 구독 오류 - 사진 $photoId: $error'),
          );
    } catch (e) {
      debugPrint('❌ 실시간 댓글 구독 시작 실패 - 사진 $photoId: $e');
    }
  }

  /// 댓글 업데이트 처리
  void _handleCommentsUpdate(
    String photoId,
    String currentUserId,
    List<CommentRecordModel> comments,
  ) {
    debugPrint(
      '[REALTIME] 실시간 댓글 업데이트 수신 - 사진: $photoId, 댓글 수: ${comments.length}',
    );

    if (mounted) {
      setState(() => _photoComments[photoId] = comments);
    }

    final userComment =
        comments
            .where((comment) => comment.recorderUser == currentUserId)
            .firstOrNull;

    if (userComment != null) {
      debugPrint('[REALTIME] 실시간 음성 댓글 업데이트 - ID: ${userComment.id}');

      if (mounted) {
        setState(() {
          _voiceCommentSavedStates[photoId] = true;
          _savedCommentIds[photoId] = userComment.id;

          if (userComment.profileImageUrl.isNotEmpty) {
            _commentProfileImageUrls[photoId] = userComment.profileImageUrl;
            debugPrint(
              '[REALTIME] 음성 댓글 프로필 이미지 URL 캐시됨 - photoId: $photoId, URL: ${userComment.profileImageUrl}',
            );
          }

          if (userComment.profilePosition != null) {
            _profileImagePositions[photoId] = userComment.profilePosition!;
            _droppedProfileImageUrls[photoId] = userComment.profileImageUrl;
            debugPrint('[REALTIME] 프로필 위치 및 이미지 URL 업데이트 - photoId: $photoId');
          }
        });
      }
    } else {
      debugPrint('🔍 실시간 업데이트: 사진 $photoId에 현재 사용자의 댓글 없음');

      if (mounted) {
        setState(() {
          _voiceCommentSavedStates[photoId] = false;
          _savedCommentIds.remove(photoId);
          _profileImagePositions[photoId] = null;
          _commentProfileImageUrls.remove(photoId);
          _photoComments[photoId] = [];
        });
      }
    }
  }

  /// 오디오 재생/일시정지 토글
  Future<void> _toggleAudio(PhotoDataModel photo) async {
    if (photo.audioUrl.isEmpty) {
      debugPrint('오디오 URL이 없습니다');
      return;
    }

    try {
      await Provider.of<AudioController>(
        context,
        listen: false,
      ).toggleAudio(photo.audioUrl);
    } catch (e) {
      debugPrint('오디오 재생 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('음성 파일을 재생할 수 없습니다: $e')));
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

  /// 음성 댓글 녹음 완료 콜백
  Future<void> _onVoiceCommentCompleted(
    String photoId,
    String? audioPath,
    List<double>? waveformData,
    int? duration,
  ) async {
    if (audioPath == null || waveformData == null || duration == null) {
      debugPrint('❌ 음성 댓글 데이터가 유효하지 않습니다');
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

      debugPrint(
        '🎤 음성 댓글 저장 시작 - 사진: $photoId, 사용자: $currentUserId, 시간: ${duration}ms',
      );

      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(currentUserId);
      final currentProfilePosition = _profileImagePositions[photoId];

      debugPrint('🔍 음성 댓글 저장 시 현재 프로필 위치: $currentProfilePosition');

      final commentRecord = await commentRecordController.createCommentRecord(
        audioFilePath: audioPath,
        photoId: photoId,
        recorderUser: currentUserId,
        waveformData: waveformData,
        duration: duration,
        profileImageUrl: profileImageUrl,
        profilePosition: currentProfilePosition,
      );

      if (commentRecord != null) {
        debugPrint('✅ 음성 댓글 저장 완료 - ID: ${commentRecord.id}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('음성 댓글이 저장되었습니다'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          setState(() {
            _voiceCommentSavedStates[photoId] = true;
            _savedCommentIds[photoId] = commentRecord.id;
          });

          debugPrint(
            '🎯 음성 댓글 ID 저장됨 - photoId: $photoId, commentId: ${commentRecord.id}',
          );

          // 댓글 저장 완료 후 대기 중인 프로필 위치가 있다면 업데이트
          final pendingPosition = _profileImagePositions[photoId];
          if (pendingPosition != null) {
            debugPrint(' 댓글 저장 완료 후 대기 중인 프로필 위치 업데이트: $pendingPosition');
            Future.delayed(const Duration(milliseconds: 200), () {
              _updateProfilePositionInFirestore(photoId, pendingPosition);
            });
          }
        }
      } else {
        if (mounted) {
          commentRecordController.showErrorToUser(context);
        }
      }
    } catch (e) {
      debugPrint('❌ 음성 댓글 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('음성 댓글 저장 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 음성 댓글 삭제 콜백
  void _onVoiceCommentDeleted(String photoId) {
    setState(() {
      _voiceCommentActiveStates[photoId] = false;
      _voiceCommentSavedStates[photoId] = false;
      _profileImagePositions[photoId] = null;
    });
    debugPrint('음성 댓글 삭제됨 - 사진 ID: $photoId');
  }

  /// 프로필 이미지 드래그 처리
  void _onProfileImageDragged(String photoId, Offset globalPosition) {
    debugPrint('🖼️ 프로필 이미지 드래그됨 - 사진: $photoId, 위치: $globalPosition');
    setState(() => _profileImagePositions[photoId] = globalPosition);
    _updateProfilePositionInFirestore(photoId, globalPosition);
  }

  /// Firestore에 프로필 위치 업데이트
  Future<void> _updateProfilePositionInFirestore(
    String photoId,
    Offset position, {
    int retryCount = 0,
    int maxRetries = 3,
  }) async {
    try {
      debugPrint(
        '🔍 프로필 위치 업데이트 시작 - photoId: $photoId, position: $position, retry: $retryCount',
      );

      final isSaved = _voiceCommentSavedStates[photoId] == true;
      debugPrint('🔍 음성 댓글 저장 상태 확인: isSaved = $isSaved');

      if (!isSaved) {
        if (retryCount < maxRetries) {
          debugPrint(
            '⏳ 음성 댓글이 아직 저장되지 않음 - ${retryCount + 1}초 후 재시도 (${retryCount + 1}/$maxRetries)',
          );
          await Future.delayed(const Duration(seconds: 1));
          return _updateProfilePositionInFirestore(
            photoId,
            position,
            retryCount: retryCount + 1,
          );
        } else {
          debugPrint('⚠️ 최대 재시도 횟수 초과 - 위치 업데이트를 건너뜁니다');
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
        debugPrint('❌ 현재 사용자 ID를 찾을 수 없습니다');
        return;
      }

      debugPrint('🔍 현재 사용자 ID: $currentUserId');

      // 저장된 댓글 ID 확인 및 사용
      final savedCommentId = _savedCommentIds[photoId];
      debugPrint('🔍 저장된 댓글 ID: $savedCommentId');

      if (savedCommentId != null && savedCommentId.isNotEmpty) {
        debugPrint('🔍 저장된 댓글 ID로 직접 위치 업데이트 시작');
        final success = await commentRecordController.updateProfilePosition(
          commentId: savedCommentId,
          photoId: photoId,
          profilePosition: position,
        );
        debugPrint(
          success ? '✅ 프로필 위치가 Firestore에 저장되었습니다' : '❌ 프로필 위치 저장에 실패했습니다',
        );
        return;
      }

      // 저장된 댓글 ID가 없는 경우 재시도 또는 검색
      if (retryCount < maxRetries) {
        debugPrint(
          ' 저장된 댓글 ID가 없음 - ${retryCount + 1}초 후 재시도 (${retryCount + 1}/$maxRetries)',
        );
        await Future.delayed(const Duration(seconds: 1));
        return _updateProfilePositionInFirestore(
          photoId,
          position,
          retryCount: retryCount + 1,
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
      debugPrint('❌ 프로필 위치 업데이트 중 오류 발생: $e');
    }
  }

  /// 댓글을 찾아서 위치 업데이트
  Future<void> _findAndUpdateCommentPosition(
    CommentRecordController commentRecordController,
    String photoId,
    String currentUserId,
    Offset position,
  ) async {
    debugPrint('🔍 저장된 댓글 ID가 없어 캐시/서버에서 검색 시작');

    var comments = commentRecordController.getCommentsByPhotoId(photoId);
    debugPrint('🔍 캐시에서 찾은 댓글 수: ${comments.length}');

    if (comments.isEmpty) {
      debugPrint('🔍 캐시가 비어있어 서버에서 음성 댓글 로드 시작 - photoId: $photoId');
      await commentRecordController.loadCommentRecordsByPhotoId(photoId);
      comments = commentRecordController.commentRecords;
      debugPrint('🔍 서버에서 로드된 댓글 수: ${comments.length}');
    }

    final userComment =
        comments
            .where((comment) => comment.recorderUser == currentUserId)
            .firstOrNull;
    debugPrint('🔍 현재 사용자의 댓글 찾기 결과: ${userComment?.id}');

    if (userComment != null) {
      debugPrint('🔍 프로필 위치 업데이트 호출 시작');
      final success = await commentRecordController.updateProfilePosition(
        commentId: userComment.id,
        photoId: photoId,
        profilePosition: position,
      );
      debugPrint(
        success ? '✅ 프로필 위치가 Firestore에 저장되었습니다' : '❌ 프로필 위치 저장에 실패했습니다',
      );
    } else {
      debugPrint('⚠️ 해당 사진에 대한 사용자의 음성 댓글을 찾을 수 없습니다');
    }
  }

  /// 커스텀 파형 위젯을 빌드하는 메서드 (실시간 progress 포함)
  Widget _buildWaveformWidgetWithProgress(PhotoDataModel photo) {
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
          onTap: () => _toggleAudio(photo),
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
  Widget _buildUserProfileWidget(PhotoDataModel photo) {
    final userId = photo.userID;
    final screenWidth = MediaQuery.of(context).size.width;
    final profileSize = screenWidth * 0.085;

    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final isLoading = _profileLoadingStates[userId] ?? false;
        final profileImageUrl = _userProfileImages[userId] ?? '';

        return Container(
          width: profileSize,
          height: profileSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
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
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('사진을 불러오는 중...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_allPhotos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 80),
            SizedBox(height: 16),
            Text(
              '아직 사진이 없어요',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
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
              debugPrint('📍 현재 페이지: $index / 전체: ${_allPhotos.length}');

              // 마지막에서 2번째 페이지에 도달하면 추가 로드
              if (index >= _allPhotos.length - 2 &&
                  _hasMoreData &&
                  !_isLoadingMore) {
                debugPrint(
                  '🔄 추가 로드 트리거 - index: $index, 전체: ${_allPhotos.length}',
                );
                _loadMorePhotos();
              }
            },
            itemBuilder: (context, index) {
              // 로딩 인디케이터 표시
              if (index >= _allPhotos.length) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        '더 많은 사진을 불러오는 중...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                );
              }

              final photoData = _allPhotos[index];
              return _buildPhotoCard(photoData, index);
            },
          ),

          // 추가 로딩 인디케이터 (하단)
          if (_isLoadingMore)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '추가 로딩 중...',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photoData, int index) {
    final PhotoDataModel photo = photoData['photo'] as PhotoDataModel;
    final String categoryName = photoData['categoryName'] as String;

    // 반응형 크기 계산
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
        setState(() {
          _profileImagePositions[photo.id] = localPosition;
        });

        // Firestore에 위치 업데이트 (재시도 로직 포함)
        _updateProfilePositionInFirestore(photo.id, localPosition);
      },
      builder: (context, candidateData, rejectedData) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20.5),
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
                Padding(
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
                ),

                // 오디오 컨트롤 오버레이 (photo_detail처럼)
                if (photo.audioUrl.isNotEmpty)
                  Positioned(
                    bottom: screenHeight * 0.018,
                    left: screenWidth * 0.05,
                    right: screenWidth * 0.05,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.032,
                        vertical: screenHeight * 0.01,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xff000000).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // 왼쪽 프로필 이미지 (작은 버전)
                          Container(
                            width: screenWidth * 0.085,
                            height: screenWidth * 0.085,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: ClipOval(
                              child: _buildUserProfileWidget(photo),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.032),

                          // 가운데 파형 (progress 포함)
                          Expanded(
                            child: SizedBox(
                              height: screenHeight * 0.04,
                              child: _buildWaveformWidgetWithProgress(photo),
                            ),
                          ),

                          SizedBox(width: screenWidth * 0.032),

                          // 오른쪽 재생 시간 (실시간 업데이트)
                          Consumer<AudioController>(
                            builder: (context, audioController, child) {
                              // 현재 사진의 오디오가 재생 중인지 확인
                              final isCurrentAudio =
                                  audioController.isPlaying &&
                                  audioController.currentPlayingAudioUrl ==
                                      photo.audioUrl;

                              // 실시간 재생 시간 사용
                              Duration displayDuration = Duration.zero;
                              if (isCurrentAudio) {
                                displayDuration =
                                    audioController.currentPosition;
                              }

                              return Text(
                                FormatUtils.formatDuration(displayDuration),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.032,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                // 드롭된 프로필 이미지 표시
                if (_profileImagePositions[photo.id] != null)
                  Positioned(
                    left: (_profileImagePositions[photo.id]!.dx - 13.5).clamp(
                      0,
                      cardWidth - 27,
                    ),
                    top: (_profileImagePositions[photo.id]!.dy - 13.5 - 20.5)
                        .clamp(0, cardHeight - 27), // 상단 여백 고려
                    child: Consumer<AuthController>(
                      builder: (context, authController, child) {
                        final currentUserId = authController.currentUser?.uid;

                        // 실시간 스트림에서 받은 댓글 데이터 사용 (_photoComments)
                        final comments = _photoComments[photo.id] ?? [];

                        String? profileImageUrl;
                        String? audioUrl;

                        // 드롭된 프로필 이미지 URL 사용 (간단한 플로우)
                        profileImageUrl = _droppedProfileImageUrls[photo.id];

                        // 실시간 댓글에서 audioUrl 찾기
                        for (var comment in comments) {
                          if (comment.recorderUser == currentUserId &&
                              comment.profilePosition != null) {
                            audioUrl = comment.audioUrl;
                            debugPrint(
                              '🔍 드롭된 프로필 이미지 - commentId: ${comment.id}, audioUrl: $audioUrl, profileUrl: $profileImageUrl',
                            );
                            break;
                          }
                        }

                        return InkWell(
                          onTap: () async {
                            if (audioUrl != null && audioUrl.isNotEmpty) {
                              try {
                                final audioController =
                                    Provider.of<AudioController>(
                                      context,
                                      listen: false,
                                    );
                                await audioController.toggleAudio(audioUrl);
                                debugPrint(
                                  '🎵 드롭된 프로필 이미지 클릭 - 음성 재생: $audioUrl',
                                );
                              } catch (e) {
                                debugPrint('❌ 음성 재생 실패: $e');
                              }
                            } else {
                              debugPrint('❌ 재생할 audioUrl이 없습니다');
                            }
                          },
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child:
                                profileImageUrl != null &&
                                        profileImageUrl.isNotEmpty
                                    ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: profileImageUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey[700],
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                    : Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[700],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            // 사진 정보 오버레이
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.01,
              ),
              child: Row(
                children: [
                  SizedBox(width: screenWidth * 0.032),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${_userNames[photo.userID] ?? photo.userID}', // @ 형식으로 표시
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.037,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatTimestamp(
                            photo.createdAt,
                          ), // PhotoDataModel의 실제 필드명 사용
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: screenWidth * 0.032,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 음성 댓글 UI 또는 댓글 버튼
            SizedBox(
              child:
                  _voiceCommentActiveStates[photo.id] == true
                      ? Container(
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * (30 / 852),
                        ),

                        child: Consumer<AuthController>(
                          builder: (context, authController, child) {
                            final currentUserId =
                                authController.currentUser?.uid;

                            // comment_records의 profileImageUrl 사용 (우선순위)
                            // 없으면 AuthController의 프로필 이미지 사용 (fallback)
                            final currentUserProfileImage =
                                _commentProfileImageUrls[photo.id] ??
                                (currentUserId != null
                                    ? _userProfileImages[currentUserId]
                                    : null);

                            // 이미 저장된 상태인지 확인
                            final isSaved =
                                _voiceCommentSavedStates[photo.id] == true;

                            // 이미 댓글이 있으면 저장된 프로필 이미지만 표시
                            if (isSaved && currentUserId != null) {
                              return Center(
                                child: Draggable<String>(
                                  data: 'profile_image',
                                  onDragStarted: () {
                                    debugPrint('저장된 프로필 이미지 드래그 시작 - feed');
                                  },
                                  feedback: Transform.scale(
                                    scale: 1.2,
                                    child: Opacity(
                                      opacity: 0.8,
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child:
                                              currentUserProfileImage != null &&
                                                      currentUserProfileImage
                                                          .isNotEmpty
                                                  ? Image.network(
                                                    currentUserProfileImage,
                                                    fit: BoxFit.cover,
                                                  )
                                                  : Container(
                                                    color: Colors.grey.shade600,
                                                    child: Icon(
                                                      Icons.person,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child:
                                            currentUserProfileImage != null &&
                                                    currentUserProfileImage
                                                        .isNotEmpty
                                                ? Image.network(
                                                  currentUserProfileImage,
                                                  fit: BoxFit.cover,
                                                )
                                                : Container(
                                                  color: Colors.grey.shade600,
                                                  child: Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ),
                                  onDragEnd: (details) {
                                    _onProfileImageDragged(
                                      photo.id,
                                      details.offset,
                                    );
                                  },
                                  child: GestureDetector(
                                    onTap: () async {
                                      // 현재 사용자의 댓글 찾기
                                      final currentUserId =
                                          authController.currentUser?.uid;
                                      if (currentUserId != null) {
                                        final commentRecordController =
                                            CommentRecordController();

                                        try {
                                          // 해당 사진의 댓글들 로드
                                          await commentRecordController
                                              .loadCommentRecordsByPhotoId(
                                                photo.id,
                                              );
                                          final comments =
                                              commentRecordController
                                                  .commentRecords;

                                          // 현재 사용자의 댓글 찾기
                                          final userComment =
                                              comments
                                                  .where(
                                                    (comment) =>
                                                        comment.recorderUser ==
                                                        currentUserId,
                                                  )
                                                  .firstOrNull;

                                          if (userComment != null &&
                                              userComment.audioUrl.isNotEmpty) {
                                            debugPrint(
                                              '🎵 피드에서 저장된 음성 댓글 재생: ${userComment.audioUrl}',
                                            );

                                            // AudioController를 사용하여 음성 재생
                                            final audioController =
                                                Provider.of<AudioController>(
                                                  context,
                                                  listen: false,
                                                );
                                            await audioController.toggleAudio(
                                              userComment.audioUrl,
                                            );

                                            debugPrint('✅ 음성 재생 시작됨');
                                          } else {
                                            debugPrint(
                                              '❌ 재생할 음성 댓글을 찾을 수 없습니다',
                                            );
                                          }
                                        } catch (e) {
                                          debugPrint('❌ 음성 재생 실패: $e');
                                        }
                                      }
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child:
                                            currentUserProfileImage != null &&
                                                    currentUserProfileImage
                                                        .isNotEmpty
                                                ? Image.network(
                                                  currentUserProfileImage,
                                                  fit: BoxFit.cover,
                                                )
                                                : Container(
                                                  color: Colors.grey.shade600,
                                                  child: Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            // 댓글이 없으면 VoiceCommentWidget 표시
                            return VoiceCommentWidget(
                              autoStart: !isSaved, // 저장된 상태가 아닐 때만 자동 시작
                              startAsSaved: isSaved, // 저장된 상태로 시작할지 여부
                              profileImageUrl:
                                  _commentProfileImageUrls[photo.id] ??
                                  currentUserProfileImage,
                              onRecordingCompleted: (
                                audioPath,
                                waveformData,
                                duration,
                              ) {
                                _onVoiceCommentCompleted(
                                  photo.id,
                                  audioPath,
                                  waveformData,
                                  duration,
                                );
                              },
                              onRecordingDeleted: () {
                                _onVoiceCommentDeleted(photo.id);
                              },
                              onSaved: () {
                                // 저장 완료 상태로 설정
                                setState(() {
                                  _voiceCommentSavedStates[photo.id] = true;
                                });
                                debugPrint(
                                  '🎯 음성 댓글 저장 완료 UI 표시됨 - photoId: ${photo.id}',
                                );
                                debugPrint(
                                  '🎯 _voiceCommentSavedStates 업데이트: $_voiceCommentSavedStates',
                                );
                              },
                              onProfileImageDragged: (offset) {
                                // 프로필 이미지 드래그 처리
                                _onProfileImageDragged(photo.id, offset);
                              },
                            );
                          },
                        ),
                      )
                      : Center(
                        child: IconButton(
                          onPressed: () => _toggleVoiceComment(photo.id),
                          icon: Image.asset(
                            width: 85 / 393 * screenWidth,
                            height: 85 / 852 * screenHeight,
                            'assets/comment.png',
                          ),
                        ),
                      ),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${timestamp.year}.${timestamp.month.toString().padLeft(2, '0')}.${timestamp.day.toString().padLeft(2, '0')}';
    }
  }
}
