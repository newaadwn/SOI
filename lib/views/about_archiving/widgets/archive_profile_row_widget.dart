import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 🧑‍🤝‍🧑 프로필 이미지 행 위젯 (Figma 디자인 기준)
class ArchiveProfileRowWidget extends StatelessWidget {
  final List<String> mates; // UID 리스트

  const ArchiveProfileRowWidget({super.key, required this.mates});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        // mates가 없거나 비어있으면 기본 이미지 하나만 표시
        if (mates.isEmpty) {
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
        final displayMates = mates.take(3).toList();

        return SizedBox(
          height: 19.sp,
          child: Row(
            children:
                displayMates.map<Widget>((mateUid) {
                  return FutureBuilder<String>(
                    future: authController.getUserProfileImageUrlById(mateUid),
                    builder: (context, snapshot) {
                      String? imageUrl;
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        imageUrl = snapshot.data;
                      }

                      return SizedBox(
                        width: 19,
                        height: 19,
                        child:
                            imageUrl != null && imageUrl.isNotEmpty
                                ? ClipOval(
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
                                )
                                : Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 12.sp,
                                  ),
                                ),
                      );
                    },
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}
