import 'package:flutter/material.dart';
import '../../controllers/category_controller.dart';
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
    final categoryController = Provider.of<CategoryController>(
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
            // 임시 파형 데이터 추가 버튼
            IconButton(
              icon: Icon(Icons.graphic_eq, color: Colors.white),
              onPressed: () async {
                debugPrint('🔧 파형 데이터 추가 버튼 클릭');
                final photoService = PhotoService();
                final success = await photoService
                    .addWaveformDataToExistingPhotos(category.id);

                if (success) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('파형 데이터가 추가되었습니다!')));
                } else {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('파형 데이터 추가에 실패했습니다.')));
                }
              },
            ),
          ],
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: categoryController.getPhotosStream(category.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Convert Map data to PhotoModel objects using helper method
          final photos =
              (snapshot.data ?? [])
                  .map((photoMap) => PhotoDataModel.fromMapData(photoMap))
                  .toList();

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
                category: category,
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
