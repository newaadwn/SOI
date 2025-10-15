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
    _pruneStreams(widget.mates);
  }

  @override
  void didUpdateWidget(covariant ArchiveProfileRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.mates, widget.mates)) {
      _ensureStreams(widget.mates);
      _pruneStreams(widget.mates);
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
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        if (widget.mates.isEmpty) {
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

        final displayMates = widget.mates.take(3).toList();
        _ensureStreams(displayMates, controller: authController);
        _pruneStreams(displayMates);

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
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
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
                              placeholder:
                                  (context, url) => _buildShimmerCircle(),
                              errorWidget:
                                  (context, url, error) =>
                                      _buildDefaultCircle(),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _ensureStreams(List<String> mates, {AuthController? controller}) {
    final auth = controller ?? _authController;
    if (auth == null) return;

    for (final mateUid in mates) {
      _profileStreams.putIfAbsent(
        mateUid,
        () => auth.getUserProfileImageUrlStream(mateUid),
      );
    }
  }

  void _pruneStreams(List<String> mates) {
    final auth = _authController;
    if (auth == null) return;

    final removableKeys =
        _profileStreams.keys
            .where((mateUid) => !mates.contains(mateUid))
            .toList();
    for (final key in removableKeys) {
      auth.releaseProfileStream(key);
      _profileStreams.remove(key);
    }
  }

  @override
  bool get wantKeepAlive => true;
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
