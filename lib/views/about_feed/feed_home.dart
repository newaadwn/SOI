import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';
import '../../controllers/audio_controller.dart';
import '../../controllers/comment_record_controller.dart';
import '../../models/category_data_model.dart';
import '../../models/photo_data_model.dart';
import '../../models/auth_model.dart';
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
  List<Map<String, dynamic>> _allPhotos = []; // 카테고리 정보와 함께 저장
  bool _isLoading = true;

  // 프로필 정보 캐싱
  final Map<String, String> _userProfileImages = {};
  final Map<String, String> _userNames = {};
  final Map<String, bool> _profileLoadingStates = {};

  // 음성 댓글 상태 관리
  final Map<String, bool> _voiceCommentActiveStates = {}; // 사진 ID별 음성 댓글 활성화 상태
  final Map<String, bool> _voiceCommentSavedStates =
      {}; // 사진 ID별 음성 댓글 저장 완료 상태
  final Map<String, String> _savedCommentIds = {}; // 사진 ID별 저장된 댓글 ID

  // 프로필 이미지 위치 관리
  final Map<String, Offset?> _profileImagePositions = {}; // 사진 ID별 프로필 이미지 위치

  // 음성 댓글의 프로필 이미지 URL 캐시 (comment_records에서 가져온 것)
  final Map<String, String> _commentProfileImageUrls =
      {}; // 사진 ID별 음성 댓글 프로필 이미지 URL

  // 실시간 스트림 구독 관리
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

  // AuthController 참조 저장
  AuthController? _authController;

  @override
  void initState() {
    super.initState();
    _loadUserCategoriesAndPhotos();
    // AuthController의 변경사항을 감지하여 프로필 이미지 캐시 업데이트
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController = Provider.of<AuthController>(context, listen: false);
      _authController!.addListener(_onAuthControllerChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AuthController 참조를 안전하게 저장
    _authController ??= Provider.of<AuthController>(context, listen: false);
  }

  @override
  void dispose() {
    _authController?.removeListener(_onAuthControllerChanged);

    // 모든 댓글 스트림 구독 해제
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
      // 현재 사용자의 최신 프로필 이미지 URL 가져오기
      final newProfileImageUrl = await _authController!
          .getUserProfileImageUrlWithCache(currentUser.uid);

      if (_userProfileImages[currentUser.uid] != newProfileImageUrl) {
        setState(() {
          _userProfileImages[currentUser.uid] = newProfileImageUrl;
        });
      }
    }
  }

  /// 특정 사용자의 프로필 이미지 캐시 강제 리프레시
  Future<void> refreshUserProfileImage(String userId) async {
    final authController = Provider.of<AuthController>(context, listen: false);

    try {
      setState(() {
        _profileLoadingStates[userId] = true;
      });

      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(userId);

      setState(() {
        _userProfileImages[userId] = profileImageUrl;
        _profileLoadingStates[userId] = false;
      });
    } catch (e) {
      setState(() {
        _profileLoadingStates[userId] = false;
      });
    }
  }

  /// 사용자가 속한 카테고리들과 해당 사진들을 모두 로드
  Future<void> _loadUserCategoriesAndPhotos() async {
    try {
      setState(() {
        _isLoading = true;
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

      // 현재 로그인한 사용자 ID 가져오기
      final currentUserId = authController.getUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('로그인된 사용자를 찾을 수 없습니다.');
      }

      debugPrint('[STREAM] 현재 사용자 ID: $currentUserId');

      // 현재 사용자의 프로필 이미지를 미리 로드
      if (!_userProfileImages.containsKey(currentUserId)) {
        try {
          final currentUserProfileImage = await authController
              .getUserProfileImageUrlWithCache(currentUserId);
          setState(() {
            _userProfileImages[currentUserId] = currentUserProfileImage;
          });
          debugPrint(
            '[PROFILE] 현재 사용자 프로필 이미지 로드됨: $currentUserId -> $currentUserProfileImage',
          );
        } catch (e) {
          debugPrint('[ERROR] 현재 사용자 프로필 이미지 로드 실패: $e');
        }
      }

      // 사용자가 속한 카테고리들 가져오기
      await categoryController.loadUserCategories(currentUserId);
      final userCategories = categoryController.userCategories;

      debugPrint('📁 사용자가 속한 카테고리 수: ${userCategories.length}');

      List<Map<String, dynamic>> allPhotos = [];

      // 각 카테고리에서 사진들 가져오기
      for (CategoryDataModel category in userCategories) {
        debugPrint('📸 카테고리 "${category.name}" (${category.id})에서 사진 로딩 중...');

        try {
          // PhotoController의 공개 메서드 사용
          await photoController.loadPhotosByCategory(category.id);
          final categoryPhotos = photoController.photos;

          // 각 사진에 카테고리 정보 추가
          for (PhotoDataModel photo in categoryPhotos) {
            allPhotos.add({
              'photo': photo,
              'categoryName': category.name,
              'categoryId': category.id,
            });
          }

          debugPrint(
            '📸 카테고리 "${category.name}"에서 ${categoryPhotos.length}개 사진 로드됨',
          );
        } catch (e) {
          debugPrint('❌ 카테고리 "${category.name}" 사진 로드 실패: $e');
        }
      }

      // 최신 순으로 정렬 (createdAt 기준)
      allPhotos.sort((a, b) {
        final PhotoDataModel photoA = a['photo'] as PhotoDataModel;
        final PhotoDataModel photoB = b['photo'] as PhotoDataModel;
        return photoB.createdAt.compareTo(photoA.createdAt);
      });

      debugPrint('🎉 전체 사진 로드 완료: ${allPhotos.length}개');

      setState(() {
        _allPhotos = allPhotos;
        _isLoading = false;
      });

      // 모든 사진의 사용자 프로필 정보 로드
      for (Map<String, dynamic> photoData in allPhotos) {
        final PhotoDataModel photo = photoData['photo'] as PhotoDataModel;
        _loadUserProfileForPhoto(photo.userID);
      }

      // 모든 사진의 음성 댓글 실시간 구독 시작 (프로필 위치 동기화)
      for (Map<String, dynamic> photoData in allPhotos) {
        final PhotoDataModel photo = photoData['photo'] as PhotoDataModel;
        _subscribeToVoiceCommentsForPhoto(photo.id, currentUserId);
      }
    } catch (e) {
      debugPrint('❌ 사진 로드 실패: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 특정 사용자의 프로필 정보를 로드하는 메서드
  Future<void> _loadUserProfileForPhoto(String userId) async {
    // 이미 로딩 중이거나 로드 완료된 경우 스킵
    if (_profileLoadingStates[userId] == true ||
        _userNames.containsKey(userId)) {
      return;
    }

    setState(() {
      _profileLoadingStates[userId] = true;
    });

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );

      // 프로필 이미지 URL 가져오기 (캐싱 메서드 사용)
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(userId);

      // 사용자 정보 조회하여 이름 가져오기
      final AuthModel? userInfo = await authController.getUserInfo(userId);

      if (mounted) {
        setState(() {
          _userProfileImages[userId] = profileImageUrl;
          _userNames[userId] = userInfo?.id ?? userId; // 이름이 없으면 userID 사용
          _profileLoadingStates[userId] = false;
        });
      }
    } catch (e) {
      debugPrint('프로필 정보 로드 실패 (userId: $userId): $e');
      if (mounted) {
        setState(() {
          _userNames[userId] = userId; // 에러 시 userID 사용
          _profileLoadingStates[userId] = false;
        });
      }
    }
  }

  /// 특정 사진의 음성 댓글 정보를 실시간 구독하여 프로필 위치 동기화
  void _subscribeToVoiceCommentsForPhoto(String photoId, String currentUserId) {
    try {
      debugPrint('음성 댓글 실시간 구독 시작 - 사진: $photoId, 사용자: $currentUserId');

      // 기존 구독이 있다면 취소
      _commentStreams[photoId]?.cancel();

      final commentRecordController = CommentRecordController();

      // 실시간 스트림 구독
      _commentStreams[photoId] = commentRecordController
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) {
              debugPrint(
                '[REALTIME] 실시간 댓글 업데이트 수신 - 사진: $photoId, 댓글 수: ${comments.length}',
              );

              // 현재 사용자의 댓글 찾기
              final userComment =
                  comments
                      .where((comment) => comment.recorderUser == currentUserId)
                      .firstOrNull;

              if (userComment != null) {
                debugPrint('[REALTIME] 실시간 음성 댓글 업데이트 - ID: ${userComment.id}');

                // 저장된 상태로 설정
                if (mounted) {
                  setState(() {
                    _voiceCommentSavedStates[photoId] = true;
                    _savedCommentIds[photoId] = userComment.id;

                    // comment_records에서 가져온 프로필 이미지 URL 캐시
                    if (userComment.profileImageUrl.isNotEmpty) {
                      _commentProfileImageUrls[photoId] =
                          userComment.profileImageUrl;
                      debugPrint(
                        '[REALTIME] 음성 댓글 프로필 이미지 URL 캐시됨 - photoId: $photoId, URL: ${userComment.profileImageUrl}',
                      );
                    }

                    // 프로필 위치가 있으면 실시간 업데이트
                    if (userComment.profilePosition != null) {
                      final newPosition = userComment.profilePosition!;
                      final oldPosition = _profileImagePositions[photoId];

                      // 위치가 실제로 변경된 경우에만 업데이트
                      if (oldPosition != newPosition) {
                        _profileImagePositions[photoId] = newPosition;
                        debugPrint(
                          '[REALTIME] 실시간 프로필 위치 업데이트 - photoId: $photoId, 위치: $newPosition',
                        );
                      }
                    }
                  });
                }
              } else {
                debugPrint('🔍 실시간 업데이트: 사진 $photoId에 현재 사용자의 댓글 없음');

                // 댓글이 삭제된 경우 상태 초기화
                if (mounted) {
                  setState(() {
                    _voiceCommentSavedStates[photoId] = false;
                    _savedCommentIds.remove(photoId);
                    _profileImagePositions[photoId] = null;
                    _commentProfileImageUrls.remove(
                      photoId,
                    ); // 프로필 이미지 URL 캐시도 제거
                  });
                }
              }
            },
            onError: (error) {
              debugPrint('실시간 댓글 구독 오류 - 사진 $photoId: $error');
            },
          );
    } catch (e) {
      debugPrint('❌ 실시간 댓글 구독 시작 실패 - 사진 $photoId: $e');
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
    setState(() {
      _voiceCommentActiveStates[photoId] =
          !(_voiceCommentActiveStates[photoId] ?? false);
    });
  }

  /// 음성 댓글 녹음 완료 콜백
  Future<void> _onVoiceCommentCompleted(
    String photoId,
    String? audioPath,
    List<double>? waveformData,
    int? duration, // duration 매개변수 추가
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

      // CommentRecordController를 직접 생성하여 사용 (Provider 문제 해결용)
      final commentRecordController = CommentRecordController();

      final currentUserId = authController.getUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('로그인된 사용자를 찾을 수 없습니다.');
      }

      debugPrint(
        '🎤 음성 댓글 저장 시작 - 사진: $photoId, 사용자: $currentUserId, 시간: ${duration}ms',
      );

      // 현재 사용자의 프로필 이미지 URL 가져오기
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(currentUserId);

      // 현재 프로필 이미지 위치 가져오기 (있는 경우)
      final currentProfilePosition = _profileImagePositions[photoId];
      debugPrint('🔍 음성 댓글 저장 시 현재 프로필 위치: $currentProfilePosition');

      // CommentRecordController를 통해 저장
      final commentRecord = await commentRecordController.createCommentRecord(
        audioFilePath: audioPath,
        photoId: photoId,
        recorderUser: currentUserId,
        waveformData: waveformData,
        duration: duration,
        profileImageUrl: profileImageUrl, // 프로필 이미지 URL 전달
        profilePosition: currentProfilePosition, // 현재 프로필 위치 전달
      );

      if (commentRecord != null) {
        debugPrint('✅ 음성 댓글 저장 완료 - ID: ${commentRecord.id}');

        // 성공 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('음성 댓글이 저장되었습니다'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // 저장 완료 상태로 설정
          setState(() {
            _voiceCommentSavedStates[photoId] = true;
            _savedCommentIds[photoId] = commentRecord.id; // 댓글 ID 저장
          });

          debugPrint(
            '🎯 음성 댓글 ID 저장됨 - photoId: $photoId, commentId: ${commentRecord.id}',
          );

          // 댓글 저장 완료 후 대기 중인 프로필 위치가 있다면 업데이트
          final pendingPosition = _profileImagePositions[photoId];
          if (pendingPosition != null) {
            debugPrint(' 댓글 저장 완료 후 대기 중인 프로필 위치 업데이트: $pendingPosition');
            // 짧은 지연 후 위치 업데이트 (setState 완료 대기)
            Future.delayed(Duration(milliseconds: 200), () {
              _updateProfilePositionInFirestore(photoId, pendingPosition);
            });
          }
        }
      } else {
        // 에러 메시지는 CommentRecordController에서 처리됨
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
      _voiceCommentSavedStates[photoId] = false; // 저장 상태도 초기화
      _profileImagePositions[photoId] = null; // 프로필 이미지 위치도 초기화
    });
    debugPrint('음성 댓글 삭제됨 - 사진 ID: $photoId');
  }

  /// 프로필 이미지 드래그 처리
  void _onProfileImageDragged(String photoId, Offset globalPosition) {
    debugPrint('🖼️ 프로필 이미지 드래그됨 - 사진: $photoId, 위치: $globalPosition');
    debugPrint('🔍 현재 저장 상태: ${_voiceCommentSavedStates[photoId]}');
    debugPrint('🔍 현재 댓글 ID: ${_savedCommentIds[photoId]}');

    // 로컬 상태 업데이트
    setState(() {
      _profileImagePositions[photoId] = globalPosition;
    });

    // Firestore에 위치 저장
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

      // 음성 댓글이 저장된 상태에서만 위치 업데이트
      final isSaved = _voiceCommentSavedStates[photoId] == true;
      debugPrint('🔍 음성 댓글 저장 상태 확인: isSaved = $isSaved');

      if (!isSaved) {
        if (retryCount < maxRetries) {
          debugPrint(
            '⏳ 음성 댓글이 아직 저장되지 않음 - ${retryCount + 1}초 후 재시도 (${retryCount + 1}/$maxRetries)',
          );
          await Future.delayed(Duration(seconds: 1));
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

      // 현재 사용자의 음성 댓글 찾기 (photoId로 검색)
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

      // 저장된 댓글 ID가 있는지 확인
      final savedCommentId = _savedCommentIds[photoId];
      debugPrint('🔍 저장된 댓글 ID: $savedCommentId');

      if (savedCommentId != null && savedCommentId.isNotEmpty) {
        // 저장된 댓글 ID를 직접 사용
        debugPrint('🔍 저장된 댓글 ID로 직접 위치 업데이트 시작');
        final success = await commentRecordController.updateProfilePosition(
          commentId: savedCommentId,
          photoId: photoId,
          profilePosition: position,
        );

        if (success) {
          debugPrint('✅ 프로필 위치가 Firestore에 저장되었습니다');
        } else {
          debugPrint('❌ 프로필 위치 저장에 실패했습니다');
        }
        return; // 성공적으로 처리했으므로 종료
      }

      // 저장된 댓글 ID가 없는 경우 재시도 로직
      if (retryCount < maxRetries) {
        debugPrint(
          ' 저장된 댓글 ID가 없음 - ${retryCount + 1}초 후 재시도 (${retryCount + 1}/$maxRetries)',
        );
        await Future.delayed(Duration(seconds: 1));
        return _updateProfilePositionInFirestore(
          photoId,
          position,
          retryCount: retryCount + 1,
        );
      }

      // 저장된 댓글 ID가 없으면 기존 방식으로 댓글 찾기
      debugPrint('🔍 저장된 댓글 ID가 없어 캐시/서버에서 검색 시작');

      // 먼저 캐시에서 댓글 찾기
      final cachedComments = commentRecordController.getCommentsByPhotoId(
        photoId,
      );
      debugPrint('🔍 캐시에서 찾은 댓글 수: ${cachedComments.length}');

      List<CommentRecordModel> comments = cachedComments;

      // 캐시에 없거나 비어있으면 서버에서 로드
      if (comments.isEmpty) {
        debugPrint('🔍 캐시가 비어있어 서버에서 음성 댓글 로드 시작 - photoId: $photoId');
        await commentRecordController.loadCommentRecordsByPhotoId(photoId);
        comments = commentRecordController.commentRecords;
        debugPrint('🔍 서버에서 로드된 댓글 수: ${comments.length}');
      }

      for (var comment in comments) {
        debugPrint('🔍 댓글 - ID: ${comment.id}, 사용자: ${comment.recorderUser}');
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

        if (success) {
          debugPrint('✅ 프로필 위치가 Firestore에 저장되었습니다');
        } else {
          debugPrint('❌ 프로필 위치 저장에 실패했습니다');
        }
      } else {
        debugPrint('⚠️ 해당 사진에 대한 사용자의 음성 댓글을 찾을 수 없습니다');
      }
    } catch (e) {
      debugPrint('❌ 프로필 위치 업데이트 중 오류 발생: $e');
    }
  }

  /// 커스텀 파형 위젯을 빌드하는 메서드 (실시간 progress 포함)
  Widget _buildWaveformWidgetWithProgress(PhotoDataModel photo) {
    // 오디오가 없는 경우
    if (photo.audioUrl.isEmpty ||
        photo.waveformData == null ||
        photo.waveformData!.isEmpty) {
      return Container(
        height: 32,
        alignment: Alignment.center,
        child: Text(
          '오디오 없음',
          style: TextStyle(color: Colors.white70, fontSize: 10),
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
          onTap: () => _toggleAudio(photo),
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

  /// 사용자 프로필 이미지 위젯 빌드
  Widget _buildUserProfileWidget(PhotoDataModel photo) {
    final userId = photo.userID;

    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final isLoading = _profileLoadingStates[userId] ?? false;

        // 캐시된 프로필 이미지 URL 사용
        final profileImageUrl = _userProfileImages[userId] ?? '';

        // 반응형 크기 계산
        final screenWidth = MediaQuery.of(context).size.width;
        final profileSize = screenWidth * 0.085; // 화면 너비의 8.5%

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
                      child: CircularProgressIndicator(
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
                                  (context, url) => Container(
                                    color: Colors.grey[700],
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: profileSize * 0.4,
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    color: Colors.grey[700],
                                    child: Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: profileSize * 0.4,
                                    ),
                                  ),
                            )
                            : Container(
                              width: profileSize - 4,
                              height: profileSize - 4,
                              color: Colors.grey[700],
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: profileSize * 0.4,
                              ),
                            ),
                  ),
        );
      },
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
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: _allPhotos.length,
        itemBuilder: (context, index) {
          final photoData = _allPhotos[index];
          return _buildPhotoCard(photoData, index);
        },
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
                        final currentUserProfileImage =
                            currentUserId != null
                                ? _userProfileImages[currentUserId]
                                : null;

                        return Container(
                          width: 27,
                          height: 27,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child:
                              currentUserProfileImage != null &&
                                      currentUserProfileImage.isNotEmpty
                                  ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: currentUserProfileImage,
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
