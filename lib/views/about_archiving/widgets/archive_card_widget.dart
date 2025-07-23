import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../models/category_data_model.dart';
import '../category_photos_screen.dart';

/// 🎨 아카이브 카드 공통 위젯 (Figma 디자인 기준)
/// 168x229 비율의 카드 UI를 제공합니다.
class ArchiveCardWidget extends StatelessWidget {
  final Map<String, dynamic> category;
  final List<String> profileImages;
  final double imageSize;

  const ArchiveCardWidget({
    super.key,
    required this.category,
    required this.profileImages,
    required this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: const Color(0xFF1C1C1C), // Figma 배경색
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6.61), // Figma 모서리
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CategoryPhotosScreen(
                    category: CategoryDataModel(
                      id: category['id'],
                      name: category['name'],
                      mates: [],
                      createdAt: DateTime.now(),
                      firstPhotoUrl: category['firstPhotoUrl'],
                    ),
                  ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.only(
            top: 10.57, // Figma 패딩
            bottom: 10,
            left: 10.65,
            right: 10.65,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🖼️ 메인 이미지 (Figma: 146.7 x 146.86)
              Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6.61),
                  color: Colors.grey[300],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6.61),
                  child:
                      category['firstPhotoUrl'] != null
                          ? CachedNetworkImage(
                            imageUrl: category['firstPhotoUrl'],
                            fit: BoxFit.cover,
                            placeholder:
                                (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.error,
                                    color: Colors.grey,
                                  ),
                                ),
                          )
                          : const Icon(
                            Icons.image,
                            color: Colors.grey,
                            size: 40,
                          ),
                ),
              ),

              const Spacer(),

              // 📝 카테고리 이름과 더보기 버튼 행
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 카테고리 이름 (Figma: Pretendard 14px)
                  Expanded(
                    child: Text(
                      category['name'],
                      style: const TextStyle(
                        color: Color(0xFFF9F9F9), // Figma 텍스트 색상
                        fontSize: 14, // Figma 폰트 크기
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.4, // Figma letter spacing
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 더보기 버튼 (Figma: 24x24)
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 👥 프로필 이미지들 (Figma: 19x19 each)
              ArchiveProfileRowWidget(profileImages: profileImages),
            ],
          ),
        ),
      ),
    );
  }
}

/// 🧑‍🤝‍🧑 프로필 이미지 행 위젯 (Figma 디자인 기준)
class ArchiveProfileRowWidget extends StatelessWidget {
  final List<String> profileImages;

  const ArchiveProfileRowWidget({super.key, required this.profileImages});

  @override
  Widget build(BuildContext context) {
    // Figma 기준: 19px x 19px 프로필 이미지
    const profileSize = 19.0;

    // 이미지가 없거나 비어있으면 기본 이미지 하나만 표시
    if (profileImages.isEmpty) {
      return SizedBox(
        width: profileSize,
        height: profileSize,
        child: CircleAvatar(
          radius: profileSize / 2,
          backgroundColor: Colors.grey[400],
          child: const Icon(Icons.person, color: Colors.white, size: 12),
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
                  right: index < displayImages.length - 1 ? 4.0 : 0.0,
                ),
                child: Container(
                  width: profileSize,
                  height: profileSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 0.5),
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
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    color: Colors.grey[400],
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                            )
                            : Container(
                              color: Colors.grey[400],
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}
