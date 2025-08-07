import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/photo_data_model.dart';
import '../../controllers/auth_controller.dart';
import 'widgets/custom_waveform_widget.dart';
import 'photo_detail_screen.dart';

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

class _PhotoGridItemState extends State<PhotoGridItem>
    with AutomaticKeepAliveClientMixin {
  String _userProfileImageUrl = '';
  bool _isLoadingProfile = true;
  bool _hasLoadedOnce = false; // 한 번 로드했는지 추적

  // AuthController 참조 저장용
  AuthController? _authController;

  // 메모리 캐시 추가 (최대 100개 유저로 제한)
  static final Map<String, String> _profileImageCache = {};
  static const int _maxCacheSize = 100;

  // 오디오 관련 상태
  bool _hasAudio = false;
  List<double>? _waveformData;

  @override
  bool get wantKeepAlive => true;

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
    // 정적 캐시에서 해당 사용자 제거
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
    // 캐시 크기 관리
    if (_profileImageCache.length > _maxCacheSize) {
      _profileImageCache.clear();
    }

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );

      // AuthController의 캐싱 메서드 사용 (feed_home과 동일)
      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(widget.photo.userID);

      // 로컬 캐시에도 저장
      _profileImageCache[widget.photo.userID] = profileImageUrl;

      if (mounted) {
        setState(() {
          _userProfileImageUrl = profileImageUrl;
          _isLoadingProfile = false;
        });
      } else {}
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
    super.build(context);

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
                    (context, url) => Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.error, color: Colors.grey),
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
                            ? CircleAvatar(
                              radius: 16, // 반응형 반지름
                              backgroundColor: Colors.grey,
                              child: SizedBox(
                                width: 18.sp, // 반응형 너비
                                height: 18.sp, // 반응형 높이
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5, // 반응형 선 두께
                                  color: Colors.white,
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
                                        radius: 16, // 반응형 반지름
                                        backgroundImage: imageProvider,
                                      ),
                                  placeholder:
                                      (context, url) => CircleAvatar(
                                        radius: 161, // 반응형 반지름
                                        backgroundColor: Colors.grey,
                                        child: SizedBox(
                                          width: 18.sp, // 반응형 너비
                                          height: 18.sp, // 반응형 높이
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5, // 반응형 선 두께
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) => CircleAvatar(
                                        radius: 16, // 반응형 반지름
                                        backgroundColor: Colors.grey,
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 18.sp, // 반응형 아이콘 크기
                                        ),
                                      ),
                                );
                              },
                            )
                            : CircleAvatar(
                              radius: 16, // 반응형 반지름
                              backgroundColor: Colors.grey,
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 18.sp, // 반응형 아이콘 크기
                              ),
                            ),
                  ),
                  SizedBox(width: 7.w), // 반응형 간격
                  Expanded(
                    child: Container(
                      width: 140.w, // 반응형 너비
                      height: 21.h,
                      decoration: BoxDecoration(
                        color: Color(0xff171717).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: _buildWaveformWidget(),
                    ),
                  ),
                  SizedBox(width: 5 / 393 * MediaQuery.of(context).size.width),
                ],
              ),
              SizedBox(height: 5 / 852 * MediaQuery.of(context).size.height),
            ],
          ),
        ],
      ),
    );
  }

  /// 커스텀 파형 위젯을 빌드하는 메서드
  Widget _buildWaveformWidget() {
    // 오디오가 없는 경우
    if (!_hasAudio || _waveformData == null || _waveformData!.isEmpty) {
      return Container(
        height: 60.h,
        alignment: Alignment.center,
        child: Text(
          '오디오 없음',
          style: TextStyle(color: Colors.white70, fontSize: 10.sp),
        ),
      );
    }

    // 커스텀 파형 표시
    return Container(
      height: 21,
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: CustomWaveformWidget(
        waveformData: _waveformData!,
        color: Colors.white,
        activeColor: Colors.blueAccent,
      ),
    );
  }
}
