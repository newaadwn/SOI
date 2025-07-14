import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/photo_data_model.dart';
import '../../models/category_data_model.dart';
import '../../controllers/auth_controller.dart';
import '../widgets/smart_waveform_widget.dart';
import 'photo_detail_screen.dart';

class PhotoGridItem extends StatefulWidget {
  final PhotoDataModel photo;
  final List<PhotoDataModel> allPhotos;
  final int currentIndex;
  final String categoryName;
  final String categoryId;
  final CategoryDataModel? category;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.allPhotos,
    required this.currentIndex,
    required this.categoryName,
    required this.categoryId,
    this.category,
  });

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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (!_hasLoadedOnce) {
      _loadUserProfileImage();
      _hasLoadedOnce = true;
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
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              width: 32,
              height: 32,
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
          ),

          // 음성이 있는 경우 오른쪽 상단에 음성 아이콘 표시
          if (widget.photo.audioUrl.isNotEmpty)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.mic, color: Colors.white, size: 16),
              ),
            ),

          // 음성이 있는 경우 하단에 미니 파형 표시
          if (widget.photo.audioUrl.isNotEmpty)
            Positioned(
              bottom: 40,
              left: 8,
              right: 8,
              child: Container(
                height: 30,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SmartWaveformWidget(
                  audioUrl: widget.photo.audioUrl,
                  width: 159, // 전체 너비에서 패딩 제외
                  height: 22,
                  waveColor: Colors.grey.withOpacity(0.5),
                  progressColor: Colors.white,
                  onTap: () {
                    // 그리드 아이템 탭과 동일한 동작
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
                ),
              ),
            ),
        ],
      ),
    );
  }
}
