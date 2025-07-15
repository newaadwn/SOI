import 'package:flutter/material.dart';
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

  void _initializeWaveformData() {
    // 실제 오디오 URL 확인
    final audioUrl = widget.photo.audioUrl;

    // 오디오 URL 유효성 검사
    if (audioUrl.isEmpty) {
      debugPrint('⚠️ 오디오 URL이 비어있습니다.');
      setState(() {
        _hasAudio = false;
      });
      return;
    }

    // Firestore에서 파형 데이터 가져오기
    final waveformData = widget.photo.waveformData;

    if (waveformData != null && waveformData.isNotEmpty) {
      debugPrint('🎵 Firestore 파형 데이터 사용: ${waveformData.length} samples');
      setState(() {
        _hasAudio = true;
        _waveformData = waveformData;
      });
      debugPrint('✅ 파형 데이터 설정 완료');
    } else {
      debugPrint('⚠️ Firestore에 파형 데이터가 없습니다');
      setState(() {
        _hasAudio = false;
      });
    }
  }

  Future<void> _loadUserProfileImage() async {
    debugPrint('프로필 이미지 로딩 시작 - UserID: ${widget.photo.userID}');

    // 캐시 크기 관리
    if (_profileImageCache.length > _maxCacheSize) {
      _profileImageCache.clear();
      debugPrint('캐시 크기 초과로 초기화');
    }

    // 캐시 확인 (캐시 활성화)
    if (_profileImageCache.containsKey(widget.photo.userID)) {
      debugPrint('캐시에서 프로필 이미지 발견');
      if (mounted) {
        setState(() {
          _userProfileImageUrl = _profileImageCache[widget.photo.userID]!;
          _isLoadingProfile = false;
        });
      }
      return;
    }

    // 네트워크에서 로드 (캐시에 없을 때만)
    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );

      debugPrint('네트워크에서 프로필 이미지 요청 중...');
      final profileImageUrl = await authController.getUserProfileImageUrlById(
        widget.photo.userID,
      );

      debugPrint('프로필 이미지 URL 받음: "$profileImageUrl"');

      // 캐시에 저장
      _profileImageCache[widget.photo.userID] = profileImageUrl;

      if (mounted) {
        setState(() {
          _userProfileImageUrl = profileImageUrl;
          _isLoadingProfile = false;
        });
        debugPrint('프로필 이미지 상태 업데이트 완료');
      } else {
        debugPrint('위젯이 unmounted 상태');
      }
    } catch (e) {
      debugPrint('프로필 이미지 로드 실패: $e');
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
            width: 175,
            height: 232,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: widget.photo.imageUrl,
                fit: BoxFit.cover,
                placeholder:
                    (context, url) => Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
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
                  SizedBox(width: 7 / 393 * MediaQuery.of(context).size.width),
                  Container(
                    width: 32 / 393 * MediaQuery.of(context).size.width,
                    height: 32 / 852 * MediaQuery.of(context).size.height,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child:
                        _isLoadingProfile
                            ? CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.grey,
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                            : _userProfileImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: _userProfileImageUrl,
                              imageBuilder:
                                  (context, imageProvider) => CircleAvatar(
                                    radius: 14,
                                    backgroundImage: imageProvider,
                                  ),
                              placeholder:
                                  (context, url) => CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.grey,
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.grey,
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
                  SizedBox(width: 6 / 393 * MediaQuery.of(context).size.width),
                  Expanded(
                    child: Container(
                      width: 129,
                      height: 21,
                      decoration: BoxDecoration(
                        color: Colors.black,
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
        height: 60,
        alignment: Alignment.center,
        child: Text(
          '오디오 없음',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      );
    }

    // 커스텀 파형 표시
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: CustomWaveformWidget(
        waveformData: _waveformData!,
        color: Colors.white70,
        activeColor: Colors.blueAccent,
      ),
    );
  }
}
