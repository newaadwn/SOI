import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../controllers/auth_controller.dart';

// 프로필 이미지 행 위젯 (Figma 디자인 기준)
class ArchiveProfileRowWidget extends StatelessWidget {
  final List<String> mates;

  const ArchiveProfileRowWidget({super.key, required this.mates});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, child) {
        // mates가 없거나 비어있으면 기본 이미지 하나만 표시
        if (mates.isEmpty) {
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

        // 최대 3개까지만 표시하도록 제한
        final displayMates = mates.take(3).toList();

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
                      child: FutureBuilder<String>(
                        future: authController.getUserProfileImageUrlById(
                          mateUid,
                        ),
                        builder: (context, snapshot) {
                          String? imageUrl;
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            imageUrl = snapshot.data;
                          }

                          return Container(
                            width: 19,
                            height: 19,
                            decoration: BoxDecoration(shape: BoxShape.circle),
                            child:
                                imageUrl != null && imageUrl.isNotEmpty
                                    ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) =>
                                                Shimmer.fromColors(
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
                                                ),
                                        errorWidget:
                                            (context, url, error) =>
                                                Shimmer.fromColors(
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
                                                ),
                                      ),
                                    )
                                    : Shimmer.fromColors(
                                      baseColor: Colors.grey[400]!,
                                      highlightColor: Colors.white,
                                      child: Container(
                                        width: 19,
                                        height: 19,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.grey[400],
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 19,
                                        ),
                                      ),
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
}
