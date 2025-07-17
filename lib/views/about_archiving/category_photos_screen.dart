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

  /// 그리드 열 개수 계산 (화면 크기에 따라)
  int _getGridCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < 360) {
      return 1;
    } else if (screenWidth < 500) {
      return 2;
    } else if (screenWidth < 800) {
      return 3;
    } else {
      return 4;
    }
  }

  /// 그리드 아이템의 가로 세로 비율 계산
  double _getGridAspectRatio(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final screenRatio = screenHeight / screenWidth;
    if (screenRatio > 2.0) {
      return 0.75;
    } else if (screenRatio > 1.8) {
      return 0.8;
    } else {
      return 0.85;
    }
  }

  /// 반응형 간격 계산
  double _getGridSpacing(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth * 0.03; // 화면 너비의 3%
  }

  /// 반응형 패딩 계산
  double _getGridPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth * 0.02; // 화면 너비의 2%
  }

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

          // 반응형 그리드로 사진들을 배치
          final crossAxisCount = _getGridCrossAxisCount(context);
          final aspectRatio = _getGridAspectRatio(context);
          final spacing = _getGridSpacing(context);
          final padding = _getGridPadding(context);

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: aspectRatio,
            ),
            padding: EdgeInsets.all(padding),
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
