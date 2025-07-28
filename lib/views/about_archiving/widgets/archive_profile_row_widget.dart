import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';

/// 🧑‍🤝‍🧑 프로필 이미지 행 위젯 (Figma 디자인 기준)
class ArchiveProfileRowWidget extends StatelessWidget {
  final List<String> profileImages;
  final bool isSmallScreen;
  final bool isLargeScreen;

  const ArchiveProfileRowWidget({
    super.key,
    required this.profileImages,
    required this.isSmallScreen,
    required this.isLargeScreen,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        // 반응형 프로필 이미지 크기
        final profileSize =
            isSmallScreen
                ? 16.0
                : isLargeScreen
                ? 22.0
                : 19.0;
        final iconSize =
            isSmallScreen
                ? 10.0
                : isLargeScreen
                ? 14.0
                : 12.0;
        final borderWidth = isSmallScreen ? 0.3 : 0.5;
        final margin = isSmallScreen ? 3.0 : 4.0;

        // 이미지가 없거나 비어있으면 기본 이미지 하나만 표시
        if (profileImages.isEmpty) {
          return SizedBox(
            width: profileSize,
            height: profileSize,
            child: CircleAvatar(
              radius: profileSize / 2,
              backgroundColor: Colors.grey[400],
              child: Icon(Icons.person, color: Colors.white, size: iconSize),
            ),
          );
        }

        // 최대 3개까지만 표시하도록 제한
        final displayImages = profileImages.take(3).toList();

        return SizedBox(
          height: profileSize,
          child: Row(
            children:
                displayImages.asMap().entries.map<Widget>((entry) {
                  final index = entry.key;
                  final imageUrl = entry.value;

                  return Container(
                    margin: EdgeInsets.only(
                      right: index < displayImages.length - 1 ? margin : 0.0,
                    ),
                    child: Container(
                      width: profileSize,
                      height: profileSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: borderWidth,
                        ),
                      ),
                      child: ClipOval(
                        child:
                            imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) => Container(
                                        color: Colors.grey[400],
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: iconSize,
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Container(
                                        color: Colors.grey[400],
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: iconSize,
                                        ),
                                      ),
                                )
                                : Container(
                                  color: Colors.grey[400],
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: iconSize,
                                  ),
                                ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}
