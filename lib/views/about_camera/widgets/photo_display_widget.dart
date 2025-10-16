import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

// 이미지를 표시하는 위젯
// 로컬 이미지 경로나 Firebase Storage URL을 기반으로 이미지를 표시합니다.
class PhotoDisplayWidget extends StatefulWidget {
  final String? imagePath;
  final String? downloadUrl;
  final bool useLocalImage;
  final bool useDownloadUrl;
  final double width;
  final double height;
  final Future<void> Function()? onCancel;

  const PhotoDisplayWidget({
    super.key,
    this.imagePath,
    this.downloadUrl,
    required this.useLocalImage,
    required this.useDownloadUrl,
    this.width = 354,
    this.height = 471,
    this.onCancel,
  });

  @override
  State<PhotoDisplayWidget> createState() => _PhotoDisplayWidgetState();
}

class _PhotoDisplayWidgetState extends State<PhotoDisplayWidget> {
  @override
  void dispose() {
    // 이미지 캐시에서 해당 이미지 제거
    try {
      if (widget.imagePath != null) {
        PaintingBinding.instance.imageCache.evict(
          FileImage(File(widget.imagePath!)),
        );
      }
      if (widget.downloadUrl != null) {
        PaintingBinding.instance.imageCache.evict(
          NetworkImage(widget.downloadUrl!),
        );
      }
    } catch (e) {
      // 캐시 제거 실패해도 계속 진행
      debugPrint('Error evicting image from cache: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: _buildImageWidget(context),
      ),
    );
  }

  /// 이미지 위젯을 결정하는 메소드
  Widget _buildImageWidget(BuildContext context) {
    // 로컬 이미지를 우선적으로 사용
    if (widget.useLocalImage && widget.imagePath != null) {
      return Stack(
        alignment: Alignment.topLeft,
        children: [
          Image.file(
            File(widget.imagePath!),
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            // 메모리 최적화: 이미지 캐시 크기 제한
            cacheWidth: (widget.width * 2).round(),
            cacheHeight: (widget.height * 2).round(),

            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error, color: Colors.white);
            },
          ),
          IconButton(
            onPressed: () async {
              await _handleCancel(doublePop: true);
            },
            icon: Icon(Icons.cancel, color: Color(0xff1c1b1f), size: 35.sp),
          ),
        ],
      );
    }
    // Firebase 다운로드 URL 사용
    else if (widget.useDownloadUrl && widget.downloadUrl != null) {
      return Stack(
        alignment: Alignment.topLeft,
        children: [
          CachedNetworkImage(
            imageUrl: widget.downloadUrl!,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            // 메모리 최적화 설정 추가
            memCacheWidth: (widget.width * 2).round(),
            memCacheHeight: (widget.height * 2).round(),
            maxWidthDiskCache: 400,
            maxHeightDiskCache: 400,
            filterQuality: FilterQuality.medium,
            placeholder:
                (context, url) =>
                    const Center(child: CircularProgressIndicator()),
            errorWidget:
                (context, url, error) =>
                    const Icon(Icons.error, color: Colors.white),
          ),
          IconButton(
            onPressed: () async {
              await _handleCancel(doublePop: false);
            },
            icon: Icon(
              Icons.cancel,
              color: Color.fromARGB(255, 17, 15, 22).withValues(alpha: 0.8),
              size: 30.sp,
            ),
          ),
        ],
      );
    }
    // 둘 다 없는 경우 에러 메시지 표시
    else {
      return const Center(
        child: Text("이미지를 불러올 수 없습니다.", style: TextStyle(color: Colors.white)),
      );
    }
  }

  Future<void> _handleCancel({required bool doublePop}) async {
    if (widget.onCancel != null) {
      await widget.onCancel!();
    }

    if (!mounted) return;

    final navigator = Navigator.of(context);
    navigator.pop();

    if (doublePop && navigator.canPop()) {
      navigator.pop();
    }
  }
}
