import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 🧑‍🤝‍🧑 프로필 이미지 행 위젯 (Figma 디자인 기준)
class ArchiveProfileRowWidget extends StatelessWidget {
  final List<String> profileImages;

  const ArchiveProfileRowWidget({super.key, required this.profileImages});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        // 이미지가 없거나 비어있으면 기본 이미지 하나만 표시
        if (profileImages.isEmpty) {
          return SizedBox(
            width: 19,
            height: 19,
            child: CircleAvatar(
              radius: 19.0 / 2,
              backgroundColor: Colors.grey[400],
              child: Icon(Icons.person, color: Colors.white, size: 12.0),
            ),
          );
        }

        // 최대 3개까지만 표시하도록 제한
        final displayImages = profileImages.take(3).toList();

        return SizedBox(
          height: 19.sp,

          child: Row(
            children:
                displayImages.asMap().entries.map<Widget>((entry) {
                  final imageUrl = entry.value;

                  return imageUrl.isNotEmpty
                      ? SizedBox(
                        width: 19,
                        height: 19,
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  color: Colors.grey[400],
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 12.sp,
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Container(
                                  color: Colors.grey[400],
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 12.sp,
                                  ),
                                ),
                          ),
                        ),
                      )
                      : Container(
                        color: Colors.grey[400],
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 12.sp,
                        ),
                      );
                }).toList(),
          ),
        );
      },
    );
  }
}
