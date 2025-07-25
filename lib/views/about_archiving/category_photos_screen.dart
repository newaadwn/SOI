import 'package:flutter/material.dart';
import '../../controllers/photo_controller.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../models/photo_data_model.dart';
import '../../models/category_data_model.dart';
import 'photo_grid_item.dart';

class CategoryPhotosScreen extends StatelessWidget {
  final CategoryDataModel category;

  const CategoryPhotosScreen({super.key, required this.category});

  /// 화면 크기 구분 메서드들
  bool _isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 375;
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 414;
  }

  /// AppBar 높이 계산 (화면 크기별)
  double _getAppBarHeight(BuildContext context) {
    if (_isSmallScreen(context)) {
      return 50.0; // 작은 화면: 작은 AppBar
    } else if (_isLargeScreen(context)) {
      return 60.0; // 큰 화면: 큰 AppBar
    } else {
      return 56.0; // 일반 화면: 기본 AppBar
    }
  }

  /// 타이틀 폰트 크기 계산 (화면 크기별)
  double _getTitleFontSize(BuildContext context) {
    if (_isSmallScreen(context)) {
      return 18.0; // 작은 화면: 작은 폰트
    } else if (_isLargeScreen(context)) {
      return 22.0; // 큰 화면: 큰 폰트
    } else {
      return 20.0; // 일반 화면: 일반 폰트
    }
  }

  /// 아이콘 크기 계산 (화면 크기별)
  double _getIconSize(BuildContext context) {
    if (_isSmallScreen(context)) {
      return 20.0; // 작은 화면: 작은 아이콘
    } else if (_isLargeScreen(context)) {
      return 28.0; // 큰 화면: 큰 아이콘
    } else {
      return 24.0; // 일반 화면: 일반 아이콘
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoController = Provider.of<PhotoController>(
      context,
      listen: false,
    );

    // 반응형 값들 계산
    final titleFontSize = _getTitleFontSize(context);
    final iconSize = _getIconSize(context);
    final appBarHeight = _getAppBarHeight(context);
    final isSmallScreen = _isSmallScreen(context);

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: appBarHeight,
        iconTheme: IconThemeData(color: Colors.white, size: iconSize),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                category.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      ),
      body: StreamBuilder<List<PhotoDataModel>>(
        stream: photoController.getPhotosByCategoryStream(category.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: isSmallScreen ? 2.0 : 3.0,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20.0 : 40.0,
                ),
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14.0 : 16.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final photos = snapshot.data ?? [];

          if (photos.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20.0 : 40.0,
                ),
                child: Text(
                  '사진이 없습니다.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 14.0 : 16.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12, // 피그마 디자인에 맞춤: 수평 간격
              childAspectRatio: 175 / 233, // 피그마 디자인 비율: 175x233
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 15.0, // 피그마 디자인에 맞춤: 좌우 15px
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];

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
