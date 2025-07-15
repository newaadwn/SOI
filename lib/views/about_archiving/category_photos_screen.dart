import 'package:flutter/material.dart';
import '../../controllers/photo_controller.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../models/photo_data_model.dart';
import '../../models/category_data_model.dart';
import '../../services/photo_service.dart';
import 'photo_grid_item.dart';

class CategoryPhotosScreen extends StatelessWidget {
  final CategoryDataModel category;

  const CategoryPhotosScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final photoController = Provider.of<PhotoController>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white, //색변경
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category.name,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      ),
      body: StreamBuilder<List<PhotoDataModel>>(
        stream: photoController.getPhotosByCategoryStream(category.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final photos = snapshot.data ?? [];

          if (photos.isEmpty) {
            return const Center(
              child: Text('사진이 없습니다.', style: TextStyle(color: Colors.white)),
            );
          }

          // MasonryGridView를 사용하여 사진들을 다양한 높이로 배치
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 13,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            padding: const EdgeInsets.all(8.0),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              // 랜덤 높이: 200 ~ 350 사이 (예시)

              return PhotoGridItem(
                photo: photo,
                allPhotos: photos,
                currentIndex: index,
                categoryName: category.name,
                categoryId: category.id,
              );
            },
          );
        },
      ),
    );
  }
}
