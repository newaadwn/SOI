import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../controllers/photo_controller.dart';
import '../../controllers/auth_controller.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../models/photo_data_model.dart';
import '../../models/category_data_model.dart';
import '../../services/category_service.dart';
import 'category_edit/category_editor_screen.dart';
import 'photo_grid_item.dart';

// 카테고리 사진 화면
class CategoryPhotosScreen extends StatefulWidget {
  final CategoryDataModel category;

  const CategoryPhotosScreen({super.key, required this.category});

  @override
  State<CategoryPhotosScreen> createState() => _CategoryPhotosScreenState();
}

class _CategoryPhotosScreenState extends State<CategoryPhotosScreen> {
  final CategoryService _categoryService = CategoryService();

  @override
  void initState() {
    super.initState();
    _updateUserViewTime();
  }

  void _updateUserViewTime() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    final userId = authController.getUserId;

    if (userId != null) {
      await _categoryService.updateUserViewTime(
        categoryId: widget.category.id,
        userId: userId,
      );
    }
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
        toolbarHeight: 90.h,
        iconTheme: IconThemeData(color: Colors.white),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.category.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 25.sp, color: Colors.white),
                SizedBox(width: 2.w),
                // 카테고리에 있는 사용자의 숫자를 표시
                Text(
                  '${widget.category.mates.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            CategoryEditorScreen(category: widget.category),
                  ),
                );
              },
              icon: Icon(Icons.menu),
            ),
          ],
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      ),
      body: StreamBuilder<List<PhotoDataModel>>(
        stream: photoController.getPhotosByCategoryStream(widget.category.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3.0,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final photos = snapshot.data ?? [];

          if (photos.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: Text(
                  '사진이 없습니다.',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.w, // 피그마 디자인에 맞춤: 수평 간격
              mainAxisSpacing: 15.h, // 피그마 디자인에 맞춤: 수직 간격
              childAspectRatio: 175 / 233, // 피그마 디자인 비율: 175x233
            ),
            padding: EdgeInsets.only(left: 15.w, right: 15.w, top: 20.h),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];

              return PhotoGridItem(
                photo: photo,
                allPhotos: photos,
                currentIndex: index,
                categoryName: widget.category.name,
                categoryId: widget.category.id,
              );
            },
          );
        },
      ),
    );
  }
}
