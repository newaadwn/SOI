import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../controllers/auth_controller.dart';

// 프로필 이미지 행 위젯 (Figma 디자인 기준)
class ArchiveProfileRowWidget extends StatefulWidget {
  final List<String> mates;

  const ArchiveProfileRowWidget({super.key, required this.mates});

  @override
  State<ArchiveProfileRowWidget> createState() =>
      _ArchiveProfileRowWidgetState();
}

class _ArchiveProfileRowWidgetState extends State<ArchiveProfileRowWidget>
    with AutomaticKeepAliveClientMixin {
  final Map<String, Stream<String>> _profileStreams = {};
  AuthController? _authController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authController ??= Provider.of<AuthController>(context, listen: false);
    _ensureStreams(widget.mates);
  }

  @override
  void didUpdateWidget(covariant ArchiveProfileRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.mates, widget.mates)) {
      _releaseUnusedStreams(oldWidget.mates, widget.mates);
      _ensureStreams(widget.mates);
    }
  }

  @override
  void dispose() {
    // 모든 Stream 참조 해제
    final auth = _authController;
    if (auth != null) {
      for (final mateUid in _profileStreams.keys) {
        auth.releaseProfileStream(mateUid);
      }
    }
    _profileStreams.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.mates.isEmpty) {
      return _buildEmptyShimmer();
    }

    final displayMates = widget.mates.take(3).toList();
    _ensureStreams(displayMates);

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 19,
        width: (displayMates.length - 1) * 12.0 + 19.0,
        child: Stack(
          children:
              displayMates.asMap().entries.map<Widget>((entry) {
                final index = entry.key;
                final mateUid = entry.value;

                return Positioned(
                  left: index * 12.0,
                  child: StreamBuilder<String>(
                    stream: _profileStreams[mateUid],
                    builder: (context, snapshot) {
                      // 연결 대기 중이고 데이터가 없을 때만 로딩 표시
                      if (!snapshot.hasData &&
                          snapshot.connectionState == ConnectionState.waiting) {
                        return _buildShimmerCircle();
                      }

                      final imageUrl = snapshot.data ?? '';

                      if (imageUrl.isEmpty) {
                        return _buildDefaultCircle();
                      }

                      return ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: 19,
                          height: 19,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          useOldImageOnUrlChange: true,
                          memCacheHeight: (19 * 3).toInt(),
                          memCacheWidth: (19 * 3).toInt(),
                          maxHeightDiskCache: 150,
                          maxWidthDiskCache: 150,
                          placeholder: (context, url) => _buildShimmerCircle(),
                          errorWidget:
                              (context, url, error) => _buildDefaultCircle(),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  /// Stream 확보 (필요한 것만 생성)
  void _ensureStreams(List<String> mates) {
    final auth = _authController;
    if (auth == null) return;

    for (final mateUid in mates) {
      if (!_profileStreams.containsKey(mateUid)) {
        _profileStreams[mateUid] = auth.getUserProfileImageUrlStream(mateUid);
      }
    }
  }

  /// 사용하지 않는 Stream 해제 (메모리 최적화)
  void _releaseUnusedStreams(List<String> oldMates, List<String> newMates) {
    final auth = _authController;
    if (auth == null) return;

    // 더 이상 사용하지 않는 mate들의 Stream 해제
    for (final oldMate in oldMates) {
      if (!newMates.contains(oldMate) && _profileStreams.containsKey(oldMate)) {
        auth.releaseProfileStream(oldMate);
        _profileStreams.remove(oldMate);
      }
    }
  }

  Widget _buildEmptyShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[400]!,
      highlightColor: Colors.white,
      child: Container(
        width: 19,
        height: 19,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildShimmerCircle() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade600,
      highlightColor: Colors.grey.shade400,
      child: Container(
        width: 19,
        height: 19,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDefaultCircle() {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade500,
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 14),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
