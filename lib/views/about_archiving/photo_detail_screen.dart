import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/photo_data_model.dart';
import '../../models/auth_model.dart';
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
  late int _currentIndex;
  String _userProfileImageUrl = '';
  String _userName = '';
  bool _isLoadingProfile = true;

  // AuthController 참조 저장용
  AuthController? _authController;

  // 프로필 이미지 캐시 무효화를 위한 리프레시 카운터
  int _profileImageRefreshKey = 0;

  // 음성 댓글 관련 변수들
  final Map<String, List<CommentRecordModel>> _photoComments = {}; // 사진별 음성 댓글들
  final Map<String, Offset?> _profileImagePositions = {}; // 사진별 프로필 이미지 위치

  // 실시간 댓글 동기화를 위한 스트림 구독
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

  // 음성 댓글 저장 상태 추적 (feed_home.dart와 동일한 방식)
  final Map<String, bool> _voiceCommentSavedStates =
      {}; // 사진 ID별 음성 댓글 저장 완료 상태

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
    debugPrint('AuthController 변경 감지 - 프로필 이미지 리프레시');

    // 프로필 이미지 캐시 무효화를 위한 리프레시 키 증가
    setState(() {
      _profileImageRefreshKey++;
    });

    // 사용자 프로필 이미지 새로고침
    await _loadUserProfileImage();

    // 현재 사진의 음성 댓글 새로고침 (프로필 이미지 포함)
    _subscribeToVoiceCommentsForCurrentPhoto();
  }

  // 사용자 프로필 정보 로드 (AuthController의 캐싱 메서드 사용)
  Future<void> _loadUserProfileImage() async {
    final currentPhoto = widget.photos[_currentIndex];
    debugPrint('프로필 정보 로딩 시작 - UserID: ${currentPhoto.userID}');

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );

      // Controller의 캐싱 메서드 사용 (캐시 무효화 포함)
      // 캐시를 우회하여 최신 프로필 이미지를 가져오기 위해 직접 호출
      final profileImageUrl = await authController.getUserProfileImageUrlById(
        currentPhoto.userID,
      );

      // 사용자 정보 조회하여 이름 가져오기
      final AuthModel? userInfo = await authController.getUserInfo(
        currentPhoto.userID,
      );

      if (mounted) {
        setState(() {
          _userProfileImageUrl = profileImageUrl;
          _userName = userInfo?.id ?? currentPhoto.userID; // 이름이 없으면 userID 사용
          _isLoadingProfile = false;
        });
        debugPrint('프로필 이미지 업데이트 완료 - URL: $profileImageUrl');
      }
    } catch (e) {
      debugPrint('프로필 정보 로드 실패: $e');
      if (mounted) {
        setState(() {
          _userName = currentPhoto.userID; // 에러 시 userID 사용
          _isLoadingProfile = false;
        });
      }
    }
  }

  /// 현재 사진의 음성 댓글들과 프로필 위치 로드
  /// 현재 사진의 음성 댓글을 실시간으로 구독하여 위치 동기화
  void _subscribeToVoiceCommentsForCurrentPhoto() {
    final currentPhoto = widget.photos[_currentIndex];
    final photoId = currentPhoto.id;

    try {
      debugPrint('음성 댓글 실시간 구독 시작 - 사진: $photoId');

      // 기존 구독이 있다면 취소
      _commentStreams[photoId]?.cancel();

      final commentRecordController = CommentRecordController();

      // 실시간 스트림 구독
      _commentStreams[photoId] = commentRecordController
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) async {
              debugPrint(
                '실시간 댓글 업데이트 수신 - 사진: $photoId, 댓글 수: ${comments.length}',
              );

              // 댓글들을 저장
              if (mounted) {
                setState(() {
                  _photoComments[photoId] = comments;
                });
              }

              // 현재 사용자의 댓글이 있는지 확인하여 저장 상태 업데이트
              final currentUserId = _authController?.getUserId;

              if (currentUserId != null) {
                final hasUserComment = comments.any(
                  (comment) => comment.recorderUser == currentUserId,
                );

                if (mounted) {
                  setState(() {
                    _voiceCommentSavedStates[photoId] = hasUserComment;
                  });
                }

                debugPrint(
                  '음성 댓글 저장 상태 업데이트 - 사진: $photoId, 현재 사용자 댓글 존재: $hasUserComment',
                );
              }
              for (var comment in comments) {
                // 프로필 위치가 있으면 실시간 업데이트
                if (comment.profilePosition != null) {
                  final newPosition = comment.profilePosition!;
                  final oldPosition = _profileImagePositions[photoId];

                  // 위치가 실제로 변경된 경우에만 업데이트
                  if (oldPosition != newPosition && mounted) {
                    setState(() {
                      _profileImagePositions[photoId] = newPosition;
                    });
                    debugPrint(
                      '실시간 프로필 위치 업데이트 - photoId: $photoId, 위치: $newPosition',
                    );
                  }
                }
              }
            },
            onError: (error) {
              debugPrint('실시간 댓글 구독 오류 - 사진 $photoId: $error');
            },
          );
    } catch (e) {
      debugPrint('실시간 댓글 구독 시작 실패 - 사진 $photoId: $e');
    }
  }

  /// Firestore에 프로필 위치 업데이트
  Future<void> _updateProfilePositionInFirestore(
    String photoId,
    Offset position,
  ) async {
    try {
      debugPrint('Firestore 프로필 위치 업데이트 시작 - 사진: $photoId, 위치: $position');

      // 현재 사진의 댓글들에서 현재 사용자의 댓글 찾기
      final comments = _photoComments[photoId] ?? [];
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        debugPrint('현재 사용자 ID를 찾을 수 없습니다.');
        return;
      }

      // 현재 사용자의 댓글 찾기
      CommentRecordModel? userComment;
      for (var comment in comments) {
        if (comment.recorderUser == currentUserId) {
          userComment = comment;
          break;
        }
      }

      if (userComment == null) {
        debugPrint('현재 사용자의 음성 댓글을 찾을 수 없습니다.');
        return;
      }

      // CommentRecordController를 사용하여 위치 업데이트
      final commentRecordController = CommentRecordController();
      final success = await commentRecordController.updateProfilePosition(
        commentId: userComment.id,
        photoId: photoId,
        profilePosition: position,
      );

      if (success) {
        debugPrint('Firestore 프로필 위치 업데이트 성공');
      } else {
        debugPrint('Firestore 프로필 위치 업데이트 실패');
      }
    } catch (e) {
      debugPrint('Firestore 프로필 위치 업데이트 중 오류: $e');
    }
  }

  // 페이지가 변경될 때마다 호출되어 현재 사진을 업데이트합니다.
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _profileImageRefreshKey++; // 페이지 변경 시에도 프로필 이미지 캐시 무효화
    });
    _stopAudio(); // 기존 오디오 정지
    _loadUserProfileImage(); // 새 사용자 프로필 로드
    _subscribeToVoiceCommentsForCurrentPhoto(); // 새 사진의 음성 댓글 로드
  }

  // 오디오 재생/일시정지 (Controller 사용)
  Future<void> _toggleAudio() async {
    final currentPhoto = widget.photos[_currentIndex];

    if (currentPhoto.audioUrl.isEmpty) {
      debugPrint('오디오 URL이 없습니다');
      return;
    }

    try {
      // Controller의 재생/일시정지 메서드 사용
      await Provider.of<AudioController>(
        context,
        listen: false,
      ).toggleAudio(currentPhoto.audioUrl);
    } catch (e) {
      debugPrint('오디오 재생 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('음성 파일을 재생할 수 없습니다: $e')));
      }
    }
  }

  // 오디오 정지 (Controller 사용)
  Future<void> _stopAudio() async {
    // Controller의 정지 메서드 사용
    await Provider.of<AudioController>(context, listen: false).stopAudio();
  }

  // 커스텀 파형 위젯을 빌드하는 메서드 (실시간 progress 포함)
  Widget _buildWaveformWidgetWithProgress(PhotoDataModel photo) {
    // 오디오가 없는 경우
    if (photo.audioUrl.isEmpty ||
        photo.waveformData == null ||
        photo.waveformData!.isEmpty) {
      return Container(
        height: (MediaQuery.sizeOf(context).height * 0.038), // 반응형 높이
        alignment: Alignment.center,
        child: Text(
          '오디오 없음',
          style: TextStyle(
            color: Colors.white70,
            fontSize: (MediaQuery.sizeOf(context).width * 0.027), // 반응형 폰트
          ),
        ),
      );
    }

    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        // 현재 사진의 오디오가 재생 중인지 확인
        final isCurrentAudio =
            audioController.isPlaying &&
            audioController.currentPlayingAudioUrl == photo.audioUrl;

        // 실시간 재생 진행률 계산 (0.0 ~ 1.0)
        double progress = 0.0;
        if (isCurrentAudio &&
            audioController.currentDuration.inMilliseconds > 0) {
          progress =
              audioController.currentPosition.inMilliseconds /
              audioController.currentDuration.inMilliseconds;
          progress = progress.clamp(0.0, 1.0);
        }

        // 파형을 탭해서 재생/일시정지할 수 있도록 GestureDetector 추가
        return GestureDetector(
          onTap: _toggleAudio,
          child: Container(
            alignment: Alignment.center,
            child: CustomWaveformWidget(
              waveformData: photo.waveformData!,
              color: Color(0xff5a5a5a),
              activeColor: Colors.white, // 재생 중인 부분은 완전한 흰색
              progress: progress, // 실시간 재생 진행률 반영
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
          style: const TextStyle(color: Colors.white),
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
                borderRadius: BorderRadius.circular(
                  screenWidth * 0.043,
                ), // 반응형 반지름
                child: Builder(
                  builder: (builderContext) {
                    return DragTarget<String>(
                      onWillAcceptWithDetails: (details) {
                        debugPrint('DragTarget에 접근 중 - 데이터: ${details.data}');
                        return details.data == 'profile_image';
                      },
                      onAcceptWithDetails: (details) {
                        // 드롭된 좌표를 사진 내 상대 좌표로 변환
                        final RenderBox renderBox =
                            builderContext.findRenderObject() as RenderBox;
                        final localPosition = renderBox.globalToLocal(
                          details.offset,
                        );

                        debugPrint('프로필 이미지가 사진 영역에 드롭됨');
                        debugPrint('- 글로벌 좌표: ${details.offset}');
                        debugPrint('- 로컬 좌표: $localPosition');
                        debugPrint('- 드래그 데이터: ${details.data}');

                        // 사진 영역 내 상대 좌표로 저장
                        setState(() {
                          _profileImagePositions[photo.id] = localPosition;
                        });

                        debugPrint(
                          '로컬 상태 업데이트 완료: ${_profileImagePositions[photo.id]}',
                        );

                        // Firestore에 위치 업데이트
                        _updateProfilePositionInFirestore(
                          photo.id,
                          localPosition,
                        );
                      },
                      builder: (context, candidateData, rejectedData) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // 사진 이미지
                            SizedBox(
                              width: screenWidth * 0.9, // 반응형 너비
                              height: screenHeight * 0.65, // 반응형 높이
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

                            // 드롭된 프로필 이미지 표시
                            if (_profileImagePositions[photo.id] != null)
                              Positioned(
                                left: (_profileImagePositions[photo.id]!.dx -
                                        13.5)
                                    .clamp(0, (screenWidth * 0.9) - 27),
                                top: (_profileImagePositions[photo.id]!.dy -
                                        13.5)
                                    .clamp(0, (screenHeight * 0.65) - 27),
                                child: Consumer<AuthController>(
                                  builder: (context, authController, child) {
                                    // 해당 사진의 댓글들 확인
                                    final comments =
                                        _photoComments[photo.id] ?? [];
                                    String? profileImageUrl;

                                    // 프로필 위치가 있는 댓글의 작성자 찾기
                                    for (var comment in comments) {
                                      if (comment.profilePosition != null) {
                                        // comment_records의 profileImageUrl 직접 사용
                                        profileImageUrl =
                                            comment.profileImageUrl;
                                        break;
                                      }
                                    }

                                    return Consumer<AuthController>(
                                      builder: (
                                        context,
                                        authController,
                                        child,
                                      ) {
                                        return Container(
                                          width: 27,
                                          height: 27,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child:
                                              profileImageUrl != null &&
                                                      profileImageUrl.isNotEmpty
                                                  ? ClipOval(
                                                    child: CachedNetworkImage(
                                                      imageUrl: profileImageUrl,
                                                      key: ValueKey(
                                                        'detail_profile_${profileImageUrl}_$_profileImageRefreshKey',
                                                      ), // 리프레시 키를 사용한 캐시 무효화
                                                      fit: BoxFit.cover,
                                                      placeholder:
                                                          (
                                                            context,
                                                            url,
                                                          ) => Container(
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
                                                                  Colors.white,
                                                              size: 14,
                                                            ),
                                                          ),
                                                      errorWidget:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => Container(
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
                                                                  Colors.white,
                                                              size: 14,
                                                            ),
                                                          ),
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
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),

                            // 오디오 컨트롤 오버레이 (하단에 배치)
                            if (photo.audioUrl.isNotEmpty)
                              Positioned(
                                bottom: (screenWidth * 0.054), // 반응형 하단 여백
                                left: (screenWidth * 0.054), // 반응형 좌측 여백
                                right: (screenWidth * 0.054), // 반응형 우측 여백
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: (screenWidth * 0.032), // 반응형 패딩
                                    vertical: (screenWidth * 0.021), // 반응형 패딩
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(
                                      0xff000000,
                                    ).withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(
                                      (screenWidth * 0.067),
                                    ), // 반응형 반지름
                                  ),
                                  child: Row(
                                    children: [
                                      // 왼쪽 프로필 이미지
                                      Container(
                                        width: (screenWidth * 0.086), // 반응형 너비
                                        height: (screenWidth * 0.086), // 반응형 높이
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width:
                                                (screenWidth *
                                                    0.004), // 반응형 테두리
                                          ),
                                        ),
                                        child: Builder(
                                          builder: (context) {
                                            // comment_records의 profileImageUrl 우선 사용
                                            final comments =
                                                _photoComments[photo.id] ?? [];
                                            String profileImageToShow =
                                                _userProfileImageUrl;

                                            // 현재 사용자의 댓글이 있으면 그 댓글의 profileImageUrl 사용
                                            final currentUserId =
                                                _authController?.getUserId;
                                            if (currentUserId != null) {
                                              for (var comment in comments) {
                                                if (comment.recorderUser ==
                                                    currentUserId) {
                                                  profileImageToShow =
                                                      comment
                                                              .profileImageUrl
                                                              .isNotEmpty
                                                          ? comment
                                                              .profileImageUrl
                                                          : _userProfileImageUrl;
                                                  break;
                                                }
                                              }
                                            }

                                            return _isLoadingProfile
                                                ? CircleAvatar(
                                                  radius:
                                                      (screenWidth *
                                                          0.038), // 반응형 반지름
                                                  backgroundColor: Colors.grey,
                                                  child: SizedBox(
                                                    width:
                                                        (screenWidth *
                                                            0.043), // 반응형 너비
                                                    height:
                                                        (screenWidth *
                                                            0.043), // 반응형 높이
                                                    child: CircularProgressIndicator(
                                                      strokeWidth:
                                                          (screenWidth *
                                                              0.0054), // 반응형 선 두께
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
                                                            radius:
                                                                (screenWidth *
                                                                    0.038), // 반응형 반지름
                                                            backgroundImage:
                                                                imageProvider,
                                                          ),
                                                      placeholder:
                                                          (
                                                            context,
                                                            url,
                                                          ) => CircleAvatar(
                                                            radius:
                                                                (screenWidth *
                                                                    0.038), // 반응형 반지름
                                                            backgroundColor:
                                                                Colors.grey,
                                                            child: SizedBox(
                                                              width:
                                                                  (screenWidth *
                                                                      0.043), // 반응형 너비
                                                              height:
                                                                  (screenWidth *
                                                                      0.043), // 반응형 높이
                                                              child: CircularProgressIndicator(
                                                                strokeWidth:
                                                                    (screenWidth *
                                                                        0.0054), // 반응형 선 두께
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
                                                            radius:
                                                                (screenWidth *
                                                                    0.038), // 반응형 반지름
                                                            backgroundColor:
                                                                Colors.grey,
                                                            child: Icon(
                                                              Icons.person,
                                                              color:
                                                                  Colors.white,
                                                              size:
                                                                  (screenWidth *
                                                                      0.043), // 반응형 아이콘 크기
                                                            ),
                                                          ),
                                                    );
                                                  },
                                                )
                                                : CircleAvatar(
                                                  radius:
                                                      (screenWidth *
                                                          0.038), // 반응형 반지름
                                                  backgroundColor: Colors.grey,
                                                  child: Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                    size:
                                                        (screenWidth *
                                                            0.043), // 반응형 아이콘 크기
                                                  ),
                                                );
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: (screenWidth * 0.032),
                                      ), // 반응형 간격
                                      // 가운데 파형 (progress 포함)
                                      Expanded(
                                        child: SizedBox(
                                          height:
                                              (screenWidth * 0.086), // 반응형 높이
                                          child:
                                              _buildWaveformWidgetWithProgress(
                                                photo,
                                              ),
                                        ),
                                      ),

                                      SizedBox(
                                        width: (screenWidth * 0.032),
                                      ), // 반응형 간격
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
                                              fontSize: (screenWidth * 0.032),
                                              fontWeight: FontWeight.w500,
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
              SizedBox(height: (screenHeight * (11.5 / 852))), // 반응형 간격
              // 사진 아래 정보 섹션 (닉네임과 날짜만)
              Row(
                mainAxisAlignment: MainAxisAlignment.start,

                children: [
                  SizedBox(width: (screenWidth * (45 / 852))), // 반응형 간격
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 사용자 닉네임
                      Text(
                        '@${_userName.isNotEmpty ? _userName : photo.userID}',
                        style: TextStyle(
                          color: Color(0xfff9f9f9),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      // 날짜
                      Text(
                        FormatUtils.formatDate(photo.createdAt),
                        style: TextStyle(
                          color: Color(0xffcccccc),
                          fontSize: 14, // 반응형 폰트 크기
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: (screenHeight * (29.6 / 852))), // 반응형 간격
              Consumer<AuthController>(
                builder: (context, authController, child) {
                  // 이미 저장된 상태인지 확인
                  final isSaved = _voiceCommentSavedStates[photo.id] == true;

                  // 이미 댓글이 있으면 저장된 프로필 이미지 표시
                  if (isSaved) {
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
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
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
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
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
                                          size: 14,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                        onDragEnd: (details) {
                          // DragTarget에서 이미 처리하므로 여기서는 로깅만
                          debugPrint(
                            '🚀 프로필 이미지 드래그 종료 - 글로벌 위치: ${details.offset}',
                          );
                          debugPrint('📍 DragTarget에서 상대 좌표 변환 처리됨');
                        },
                        child: GestureDetector(
                          onTap: () async {
                            // 클릭하면 저장된 오디오 재생
                            if (userComment!.audioUrl.isNotEmpty) {
                              debugPrint(
                                '🎵 저장된 음성 댓글 재생: ${userComment.audioUrl}',
                              );
                              try {
                                final audioController =
                                    Provider.of<AudioController>(
                                      context,
                                      listen: false,
                                    );
                                await audioController.toggleAudio(
                                  userComment.audioUrl,
                                );
                                debugPrint('✅ 음성 재생 시작됨');
                              } catch (e) {
                                debugPrint('❌ 음성 재생 실패: $e');
                              }
                            }
                          },
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
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
                                          size: 14,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                      );
                    }
                  }

                  // 댓글이 없으면 AudioRecorderWidget 표시
                  return AudioRecorderWidget(
                    photoId: photo.id,
                    onCommentSaved: (commentRecord) {
                      debugPrint('새로운 음성 댓글 저장됨: ${commentRecord.id}');
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
