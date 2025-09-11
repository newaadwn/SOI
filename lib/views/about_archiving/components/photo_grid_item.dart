import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/audio_controller.dart';
import '../../../models/photo_data_model.dart';
import '../screens/archive_detail/photo_detail_screen.dart';
import '../widgets/wave_form_widget/custom_waveform_widget.dart';

class PhotoGridItem extends StatefulWidget {
  final PhotoDataModel photo;
  final List<PhotoDataModel> allPhotos;
  final int currentIndex;
  final String categoryName;
  final String categoryId;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.allPhotos,
    required this.currentIndex,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  _PhotoGridItemState createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<PhotoGridItem> {
  // 🔥 메모리 폭탄 해체: AutomaticKeepAliveClientMixin 완전 제거
  // ❌ with AutomaticKeepAliveClientMixin 제거
  // ❌ wantKeepAlive => true 제거
  // ➡️ 이제 화면에서 벗어난 사진들이 메모리에서 해제됨!
  String _userProfileImageUrl = '';
  bool _isLoadingProfile = true;
  bool _hasLoadedOnce = false; // 한 번 로드했는지 추적

  // AuthController 참조 저장용
  AuthController? _authController;

  // 🔥 메모리 최적화: static 캐시 크기 대폭 축소
  static final Map<String, String> _profileImageCache = {};
  static const int _maxCacheSize = 20; // ❌ 100 -> ✅ 20으로 대폭 축소

  // 오디오 관련 상태
  bool _hasAudio = false;
  List<double>? _waveformData;

  // 🔥 메모리 최적화된 프로필 이미지 캐시 관리
  static String? _getCachedProfileImage(String userId) {
    return _profileImageCache[userId];
  }

  static void _setCachedProfileImage(String userId, String imageUrl) {
    // LRU 방식: 캐시가 가득 차면 가장 오래된 항목 제거
    if (_profileImageCache.length >= _maxCacheSize) {
      String oldestKey = _profileImageCache.keys.first;
      _profileImageCache.remove(oldestKey);
      debugPrint('🧹 Profile cache cleaned - removed: $oldestKey');
    }
    _profileImageCache[userId] = imageUrl;
  }

  // 🔥 앱 메모리 정리 시 캐시도 함께 정리
  /*static void clearProfileCache() {
    _profileImageCache.clear();
    debugPrint('🧹 Profile image cache cleared');
  }*/

  @override
  void initState() {
    super.initState();
    if (!_hasLoadedOnce) {
      _loadUserProfileImage();
      _hasLoadedOnce = true;
    }

    // 파형 데이터 초기화
    _initializeWaveformData();
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
    // AuthController 리스너 제거 (저장된 참조 사용)
    _authController?.removeListener(_onAuthControllerChanged);
    super.dispose();
  }

  /// AuthController 변경 감지 시 프로필 이미지 캐시 무효화
  void _onAuthControllerChanged() async {
    // 🔥 개선된 캐시에서 해당 사용자 제거
    _profileImageCache.remove(widget.photo.userID);

    // 프로필 이미지 다시 로드
    await _loadUserProfileImage();
  }

  void _initializeWaveformData() {
    // 실제 오디오 URL 확인
    final audioUrl = widget.photo.audioUrl;

    // 오디오 URL 유효성 검사
    if (audioUrl.isEmpty) {
      setState(() {
        _hasAudio = false;
      });
      return;
    }

    // Firestore에서 파형 데이터 가져오기
    final waveformData = widget.photo.waveformData;

    if (waveformData != null && waveformData.isNotEmpty) {
      setState(() {
        _hasAudio = true;
        _waveformData = waveformData;
      });
    } else {
      setState(() {
        _hasAudio = false;
      });
    }
  }

  Future<void> _loadUserProfileImage() async {
    // 🔥 먼저 캐시 확인
    String? cachedUrl = _getCachedProfileImage(widget.photo.userID);
    if (cachedUrl != null) {
      setState(() {
        _userProfileImageUrl = cachedUrl;
        _isLoadingProfile = false;
      });
      return;
    }

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );

      // AuthController의 캐싱 메서드 사용 (feed_home과 동일)
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(widget.photo.userID);

      // 🔥 개선된 캐시에 저장
      _setCachedProfileImage(widget.photo.userID, profileImageUrl);

      if (mounted) {
        setState(() {
          _userProfileImageUrl = profileImageUrl;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => PhotoDetailScreen(
                  photos: widget.allPhotos,
                  initialIndex: widget.currentIndex,
                  categoryName: widget.categoryName,
                  categoryId: widget.categoryId,
                ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SizedBox(
            width: 175, // 반응형 너비
            height: 232, // 반응형 높이
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: widget.photo.imageUrl,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey.shade800,
                      highlightColor: Colors.grey.shade700,
                      period: const Duration(milliseconds: 1500),
                      child: Container(color: Colors.grey.shade800),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: Colors.grey.shade800,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image,
                        color: Colors.grey.shade600,
                        size: 32.sp,
                      ),
                    ),
              ),
            ),
          ),

          // 하단 왼쪽에 프로필 이미지 표시
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  SizedBox(width: 8.w), // 반응형 간격
                  Container(
                    width: 28.w,
                    height: 28.h,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child:
                        _isLoadingProfile
                            ? Shimmer.fromColors(
                              baseColor: Colors.grey.shade800,
                              highlightColor: Colors.grey.shade700,
                              period: const Duration(milliseconds: 1500),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade800,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      width: 1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            )
                            : _userProfileImageUrl.isNotEmpty
                            ? Consumer<AuthController>(
                              builder: (context, authController, child) {
                                return CachedNetworkImage(
                                  key: ValueKey(
                                    'profile_${widget.photo.userID}_${_userProfileImageUrl.hashCode}',
                                  ),
                                  imageUrl: _userProfileImageUrl,
                                  imageBuilder:
                                      (context, imageProvider) => CircleAvatar(
                                        radius: 16,
                                        backgroundImage: imageProvider,
                                      ),
                                  placeholder:
                                      (context, url) => Shimmer.fromColors(
                                        baseColor: Colors.grey.shade800,
                                        highlightColor: Colors.grey.shade700,
                                        period: const Duration(
                                          milliseconds: 1500,
                                        ),
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.grey.shade800,
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) => CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.grey.shade700,
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 18.sp,
                                        ),
                                      ),
                                );
                              },
                            )
                            : CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey.shade700,
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 18.sp,
                              ),
                            ),
                  ),
                  SizedBox(width: 7.w), // 반응형 간격
                  Expanded(
                    child:
                        (!_hasAudio ||
                                _waveformData == null ||
                                _waveformData!.isEmpty)
                            ? Container()
                            : GestureDetector(
                              onTap: () => _toggleAudioPlayback(),
                              child: Container(
                                width: 140.w,
                                height: 21.h,
                                decoration: BoxDecoration(
                                  color: Color(
                                    0xff171717,
                                  ).withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: _buildWaveformWidget(),
                              ),
                            ),
                  ),
                  SizedBox(width: 5.w),
                ],
              ),
              SizedBox(height: 5.h),
            ],
          ),
        ],
      ),
    );
  }

  /// 오디오 재생/일시정지 토글 메서드
  void _toggleAudioPlayback() async {
    if (!_hasAudio || widget.photo.audioUrl.isEmpty) return;

    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );

    audioController.toggleAudio(widget.photo.audioUrl);
  }

  /// 커스텀 파형 위젯을 빌드하는 메서드
  Widget _buildWaveformWidget() {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isCurrentAudio =
            audioController.isPlaying &&
            audioController.currentPlayingAudioUrl == widget.photo.audioUrl;

        double progress = 0.0;
        if (isCurrentAudio &&
            audioController.currentDuration.inMilliseconds > 0) {
          progress = (audioController.currentPosition.inMilliseconds /
                  audioController.currentDuration.inMilliseconds)
              .clamp(0.0, 1.0);
        }

        return Container(
          height: 21,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: CustomWaveformWidget(
            waveformData: _waveformData!,
            color: (isCurrentAudio) ? Color(0xff5a5a5a) : Color(0xffffffff),
            activeColor: Colors.white,
            progress: progress,
          ),
        );
      },
    );
  }
}
