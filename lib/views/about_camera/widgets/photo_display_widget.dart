import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io'; // File 클래스를 사용하기 위한 import 추가

// 이미지를 표시하는 위젯
// 로컬 이미지 경로나 Firebase Storage URL을 기반으로 이미지를 표시합니다.
class PhotoDisplayWidget extends StatelessWidget {
  // 로컬 이미지 경로를 우선적으로 사용해서 이미지를 띄우고 로컬 이미지 경로가 없을 경우 Firebase Storage URL을 사용합니다.
  final String? imagePath; // 로컬 이미지 경로
  final String? downloadUrl; // Firebase Storage URL
  final bool useLocalImage; // 로컬 이미지 사용 여부
  final bool useDownloadUrl; // 다운로드 URL 사용 여부
  final double width;
  final double height;

  const PhotoDisplayWidget({
    super.key,
    this.imagePath,
    this.downloadUrl,
    required this.useLocalImage,
    required this.useDownloadUrl,
    this.width = 354,
    this.height = 471,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(
          (screenWidth * 0.041).clamp(12.0, 20.0),
        ), // 반응형 반지름
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (screenWidth * 0.041).clamp(12.0, 20.0),
        ), // 반응형 반지름
        child: _buildImageWidget(),
      ),
    );
  }

  /// 이미지 위젯을 결정하는 메소드
  Widget _buildImageWidget() {
    // 로컬 이미지를 우선적으로 사용
    if (useLocalImage && imagePath != null) {
      return Image.file(
        File(imagePath!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.error, color: Colors.white);
        },
      );
    }
    // Firebase 다운로드 URL 사용
    else if (useDownloadUrl && downloadUrl != null) {
      return CachedNetworkImage(
        imageUrl: downloadUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder:
            (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget:
            (context, url, error) =>
                const Icon(Icons.error, color: Colors.white),
      );
    }
    // 둘 다 없는 경우 에러 메시지 표시
    else {
      return const Center(
        child: Text("이미지를 불러올 수 없습니다.", style: TextStyle(color: Colors.white)),
      );
    }
  }
}
