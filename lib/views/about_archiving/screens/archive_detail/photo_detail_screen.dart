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
import '../../../about_camera/widgets/audio_recorder_widget.dart';
import '../../widgets/photo_detail_widget/photo_display_widget.dart';
import '../../widgets/photo_detail_widget/user_info_row_widget.dart';

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
  final Map<String, Offset?> _profileImagePositions = {};
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

  // Feed와 동일한 음성 댓글 상태 관리 변수들 추가
  final Map<String, bool> _voiceCommentSavedStates = {};
  final Map<String, String> _savedCommentIds = {};
  final Map<String, String> _commentProfileImageUrls = {};
  final Map<String, String> _droppedProfileImageUrls = {};

  // PageController를 상태로 유지 (build마다 새로 생성 방지)
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();

    // 초기 사진의 댓글도 직접 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCommentsForPhoto(widget.photos[_currentIndex].id);
    });
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

      // 현재 사용자 ID 가져오기
      final currentUserId = _authController?.currentUser?.uid;
      if (currentUserId == null) {
        return;
      }

      _commentStreams[photoId] = CommentRecordController()
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) =>
                _handleCommentsUpdate(photoId, currentUserId, comments),
          );
    } catch (e) {
      debugPrint('❌ Photo Detail - 실시간 댓글 구독 시작 실패 - 사진 $photoId: $e');
    }
  }

  /// 댓글 업데이트 처리
  void _handleCommentsUpdate(
    String photoId,
    String currentUserId,
    List<CommentRecordModel> comments,
  ) {
    if (!mounted) return;

    setState(() {
      _photoComments[photoId] = comments;
    });

    // 현재 사용자의 댓글 찾기 (Feed와 동일한 로직)
    final userComment =
        comments
            .where((comment) => comment.recorderUser == currentUserId)
            .firstOrNull;

    if (userComment != null) {
      if (mounted) {
        setState(() {
          _voiceCommentSavedStates[photoId] = true;
          _savedCommentIds[photoId] = userComment.id;

          if (userComment.profileImageUrl.isNotEmpty) {
            _commentProfileImageUrls[photoId] = userComment.profileImageUrl;
          }

          // relativePosition 필드 우선 사용 (Feed와 동일한 로직)
          if (userComment.relativePosition != null) {
            Offset relativePosition;

            if (userComment.relativePosition is Map<String, dynamic>) {
              relativePosition = PositionConverter.mapToRelativePosition(
                userComment.relativePosition as Map<String, dynamic>,
              );
            } else {
              relativePosition = userComment.relativePosition!;
            }

            _profileImagePositions[photoId] = relativePosition;
            _droppedProfileImageUrls[photoId] = userComment.profileImageUrl;
          }
        });
      }
    } else {
      // 현재 사용자의 댓글이 없는 경우 상태 초기화 (Feed와 동일한 로직)
      if (mounted) {
        setState(() {
          _voiceCommentSavedStates[photoId] = false;
          _savedCommentIds.remove(photoId);
          _profileImagePositions[photoId] = null;
          _commentProfileImageUrls.remove(photoId);
          _droppedProfileImageUrls.remove(photoId);
        });
      }
    }
  }

  /// Firestore에 프로필 위치 업데이트 (상대 좌표 사용)
  /// 이제 recorderUser 단일 댓글이 아닌 특정 commentId 에 대해 위치를 저장하도록 개선
  Future<void> _updateProfilePositionInFirestore(
    String photoId,
    String commentId,
    Offset absolutePosition,
  ) async {
    try {
      if (commentId.isEmpty) {
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

  // AuthController 인스턴스 가져오기
  AuthController get _getAuthController =>
      Provider.of<AuthController>(context, listen: false);

  // AudioController 인스턴스 가져오기
  AudioController get _getAudioController =>
      Provider.of<AudioController>(context, listen: false);

  // SnackBar 표시 헬퍼
  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          height: 30.h,
          alignment: Alignment.center,
          child: Text(
            message,
            style: TextStyle(fontFamily: "Pretendard", fontSize: 14.sp),
          ),
        ),
        backgroundColor: backgroundColor ?? const Color(0xFF5A5A5A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }

  // ...existing code...

  // ==================== Core Methods ====================
  void _onPageChanged(int index) {
    final newPhotoId = widget.photos[index].id;

    setState(() {
      _currentIndex = index;
      _profileImageRefreshKey++;
    });
    _stopAudio();
    _loadUserProfileImage();
    _subscribeToVoiceCommentsForCurrentPhoto();

    // 새 페이지의 댓글을 강제로 한 번 로드
    _loadCommentsForPhoto(newPhotoId);
  }

  /// 특정 사진의 댓글을 직접 로드 (실시간 스트림과 별개)
  Future<void> _loadCommentsForPhoto(String photoId) async {
    try {
      final commentController = CommentRecordController();
      await commentController.loadCommentRecordsByPhotoId(photoId);
      final comments = commentController.getCommentsByPhotoId(photoId);

      if (mounted) {
        final currentUserId = _authController?.currentUser?.uid;
        if (currentUserId != null) {
          _handleCommentsUpdate(photoId, currentUserId, comments);
        }
      }
    } catch (e) {
      debugPrint('❌ Photo Detail - 댓글 직접 로드 실패: $e');
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
            fontFamily: "Pretendard",
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return Column(
            children: [
              // 사진 이미지 + 오디오 오버레이 (PhotoDisplayWidget으로 분리)
              PhotoDisplayWidget(
                photo: photo,
                comments: _photoComments[photo.id] ?? [],
                userProfileImageUrl: _userProfileImageUrl,
                isLoadingProfile: _isLoadingProfile,
                profileImageRefreshKey: _profileImageRefreshKey,
                onProfilePositionUpdate: (commentId, position) {
                  // 사진 영역 내 상대 좌표로 저장
                  setState(() {
                    _profileImagePositions[photo.id] = position;
                  });

                  // Firestore에 위치 업데이트
                  _updateProfilePositionInFirestore(
                    photo.id,
                    commentId,
                    position,
                  );
                },
              ),
              SizedBox(height: (11.5).h), // 반응형 간격
              // 사진 아래 정보 섹션 (UserInfoRowWidget으로 분리)
              UserInfoRowWidget(
                photo: photo,
                userName: _userName,
                onDeletePressed: () => _showDeleteDialog(photo),
              ),
              SizedBox(height: (31.6).h),

              Consumer<AuthController>(
                builder: (context, authController, child) {
                  final currentUserId = authController.getUserId;
                  final isCurrentUserPhoto = currentUserId == photo.userID;

                  // 항상 AudioRecorderWidget 표시 (여러 댓글 허용)
                  return AudioRecorderWidget(
                    photoId: photo.id,
                    isCommentMode: true, // 명시적으로 댓글 모드 설정
                    isCurrentUserPhoto: isCurrentUserPhoto, // 현재 사용자 사진 여부 전달
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
