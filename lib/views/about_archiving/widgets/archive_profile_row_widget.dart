import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
        // 이미지가 없거나 비어있으면 기본 이미지 하나만 표시
        if (profileImages.isEmpty) {
          return SizedBox(
            width: 19.w,
            height: 19.h,
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
          height: 19.h,
          child: Row(
            children:
                displayImages.asMap().entries.map<Widget>((entry) {
                  final imageUrl = entry.value;

                  return Container(
                    width: 19.w,
                    height: 19.h,
                    decoration: BoxDecoration(shape: BoxShape.circle),
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
                              )
                              : Container(
                                color: Colors.grey[400],
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 12.sp,
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
