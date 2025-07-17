import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/photo_data_model.dart';
import '../../models/auth_model.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/audio_controller.dart';
import '../../utils/format_utils.dart';
import 'widgets/custom_waveform_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserProfileImage();
  }

  @override
  void dispose() {
    // Controller는 Provider에서 관리하므로 별도 dispose 불필요
    super.dispose();
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

      // ✅ Controller의 캐싱 메서드 사용 (비즈니스 로직은 Controller에서 처리)
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(currentPhoto.userID);

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

  // 페이지가 변경될 때마다 호출되어 현재 사진을 업데이트합니다.
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _stopAudio(); // 기존 오디오 정지
    _loadUserProfileImage(); // 새 사용자 프로필 로드
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
        onPageChanged: _onPageChanged, // 페이지 변경 감지
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return Column(
            children: [
              // 사진 이미지 + 오디오 오버레이
              Expanded(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 사진 이미지
                        SizedBox(
                          width: 343,
                          height: double.infinity,
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

                        // 오디오 컨트롤 오버레이 (하단에 배치)
                        if (photo.audioUrl.isNotEmpty)
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xff000000).withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Row(
                                children: [
                                  // 왼쪽 프로필 이미지
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child:
                                        _isLoadingProfile
                                            ? CircleAvatar(
                                              radius: 14,
                                              backgroundColor: Colors.grey,
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            )
                                            : _userProfileImageUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                              imageUrl: _userProfileImageUrl,
                                              imageBuilder:
                                                  (context, imageProvider) =>
                                                      CircleAvatar(
                                                        radius: 14,
                                                        backgroundImage:
                                                            imageProvider,
                                                      ),
                                              placeholder:
                                                  (
                                                    context,
                                                    url,
                                                  ) => CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor:
                                                        Colors.grey,
                                                    child: SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      CircleAvatar(
                                                        radius: 14,
                                                        backgroundColor:
                                                            Colors.grey,
                                                        child: Icon(
                                                          Icons.person,
                                                          color: Colors.white,
                                                          size: 16,
                                                        ),
                                                      ),
                                            )
                                            : CircleAvatar(
                                              radius: 14,
                                              backgroundColor: Colors.grey,
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                  ),
                                  const SizedBox(width: 12),

                                  // 가운데 파형 (progress 포함)
                                  Expanded(
                                    child: SizedBox(
                                      height: 32,
                                      child: _buildWaveformWidgetWithProgress(
                                        photo,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // 오른쪽 재생 시간 (실시간 업데이트)
                                  Consumer<AudioController>(
                                    builder: (context, audioController, child) {
                                      // 현재 사진의 오디오가 재생 중인지 확인
                                      final isCurrentAudio =
                                          audioController.isPlaying &&
                                          audioController
                                                  .currentPlayingAudioUrl ==
                                              photo.audioUrl;

                                      // 실시간 재생 시간 사용
                                      Duration displayDuration = Duration.zero;
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
                                          fontSize: 12,
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
                  ),
                ),
              ),

              // 사진 아래 정보 섹션 (닉네임과 날짜만)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사용자 닉네임
                    Text(
                      '@${_userName.isNotEmpty ? _userName : photo.userID}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // 날짜
                    Text(
                      FormatUtils.formatDate(photo.createdAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
