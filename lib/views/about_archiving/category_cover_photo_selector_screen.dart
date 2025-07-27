import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/photo_controller.dart';
import '../../models/category_data_model.dart';

/// 카테고리 표지사진 선택 화면
class CategoryCoverPhotoSelectorScreen extends StatefulWidget {
  final CategoryDataModel category;

  const CategoryCoverPhotoSelectorScreen({super.key, required this.category});

  @override
  State<CategoryCoverPhotoSelectorScreen> createState() =>
      _CategoryCoverPhotoSelectorScreenState();
}

class _CategoryCoverPhotoSelectorScreenState
    extends State<CategoryCoverPhotoSelectorScreen> {
  String? selectedPhotoUrl;

  @override
  void initState() {
    super.initState();
    // 카테고리 사진들 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoController>().loadPhotosByCategory(widget.category.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          '표지사진 선택',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard Variable',
          ),
        ),
        actions: [
          if (selectedPhotoUrl != null)
            TextButton(
              onPressed: _updateCoverPhoto,
              child: Text(
                '완료',
                style: TextStyle(
                  color: const Color(0xFF007AFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Pretendard Variable',
                ),
              ),
            ),
        ],
      ),
      body: Consumer<PhotoController>(
        builder: (context, photoController, child) {
          if (photoController.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF007AFF)),
            );
          }

          if (photoController.photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  SizedBox(height: 16),
                  Text(
                    '아직 사진이 없습니다',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                      fontFamily: 'Pretendard Variable',
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: photoController.photos.length,
              itemBuilder: (context, index) {
                final photo = photoController.photos[index];
                final isSelected = selectedPhotoUrl == photo.imageUrl;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedPhotoUrl = isSelected ? null : photo.imageUrl;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border:
                          isSelected
                              ? Border.all(
                                color: const Color(0xFF007AFF),
                                width: 3,
                              )
                              : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          // 사진
                          CachedNetworkImage(
                            imageUrl: photo.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
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
                          ),

                          // 선택 표시
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF007AFF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// 표지사진 업데이트
  void _updateCoverPhoto() async {
    if (selectedPhotoUrl == null) return;

    final categoryController = context.read<CategoryController>();

    final success = await categoryController.updateCoverPhotoFromCategory(
      categoryId: widget.category.id,
      photoUrl: selectedPhotoUrl!,
    );

    if (success) {
      Navigator.pop(context, selectedPhotoUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('표지사진이 변경되었습니다.'),
          backgroundColor: Color(0xFF007AFF),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(categoryController.error ?? '표지사진 변경에 실패했습니다.'),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    }
  }
}
