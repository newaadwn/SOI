import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';
import '../../controllers/audio_controller.dart';
import '../../models/category_data_model.dart';
import '../../models/photo_data_model.dart';
import '../../models/auth_model.dart';
import '../../utils/format_utils.dart';
import '../about_archiving/widgets/custom_waveform_widget.dart';

class FeedHomeScreen extends StatefulWidget {
  const FeedHomeScreen({super.key});

  @override
  State<FeedHomeScreen> createState() => _FeedHomeScreenState();
}

class _FeedHomeScreenState extends State<FeedHomeScreen> {
  List<Map<String, dynamic>> _allPhotos = []; // 카테고리 정보와 함께 저장
  bool _isLoading = true;
  String? _error;

  // 프로필 정보 캐싱
  final Map<String, String> _userProfileImages = {};
  final Map<String, String> _userNames = {};
  final Map<String, bool> _profileLoadingStates = {};

  @override
  void initState() {
    super.initState();
    // 빌드가 완료된 후에 데이터 로딩 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserCategoriesAndPhotos();
    });
  }

  /// 사용자가 속한 카테고리들과 해당 사진들을 모두 로드
  Future<void> _loadUserCategoriesAndPhotos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
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

      debugPrint('🔍 현재 사용자 ID: $currentUserId');

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
    } catch (e) {
      debugPrint('❌ 사진 로드 실패: $e');
      setState(() {
        _error = e.toString();
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
    final isLoading = _profileLoadingStates[userId] ?? false;
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
                    color: Colors.white,
                  ),
                ),
              )
              : profileImageUrl.isNotEmpty
              ? CachedNetworkImage(
                imageUrl: profileImageUrl,
                imageBuilder:
                    (context, imageProvider) => CircleAvatar(
                      radius: profileSize / 2 - 2,
                      backgroundImage: imageProvider,
                    ),
                placeholder:
                    (context, url) => CircleAvatar(
                      radius: profileSize / 2 - 2,
                      backgroundColor: Colors.grey[700],
                      child: SizedBox(
                        width: profileSize * 0.4,
                        height: profileSize * 0.4,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => CircleAvatar(
                      radius: profileSize / 2 - 2,
                      backgroundColor: Colors.grey[700],
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: profileSize * 0.5,
                      ),
                    ),
              )
              : CircleAvatar(
                radius: profileSize / 2 - 2,
                backgroundColor: Colors.grey[700],
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: profileSize * 0.5,
                ),
              ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'SOI 피드',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadUserCategoriesAndPhotos,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _buildBody(),
    );
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

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              '오류가 발생했습니다',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUserCategoriesAndPhotos,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('다시 시도'),
            ),
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

    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _allPhotos.length,
      itemBuilder: (context, index) {
        final photoData = _allPhotos[index];
        return _buildPhotoCard(photoData, index);
      },
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            // 배경 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                photo.imageUrl,
                fit: BoxFit.cover,
                width: cardWidth,
                height: cardHeight,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: cardWidth,
                    height: cardHeight,
                    color: Colors.grey[900],
                    child: Center(
                      child: CircularProgressIndicator(
                        value:
                            loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: cardWidth,
                    height: cardHeight,
                    color: Colors.grey[900],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 64,
                          ),
                          SizedBox(height: 8),
                          Text(
                            '이미지를 불러올 수 없습니다',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
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
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: ClipOval(child: _buildUserProfileWidget(photo)),
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
                            displayDuration = audioController.currentPosition;
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
              //_buildUserProfileWidget(photo),
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
      ],
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
