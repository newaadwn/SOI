/*
 * ShowPhotoScreen
 * 
 * 이 파일은 특정 카테고리에 속한 사진들을 그리드 형태로 보여주는 화면을 구현합니다.
 * 
 * 기능:
 * 1. 선택된 카테고리의 모든 사진을 그리드 레이아웃으로 표시합니다.
 * 2. 사진은 다양한 높이를 가진 타일 형태로 표시됩니다(메이슨리 그리드).
 * 3. 각 사진 아래에는 촬영 날짜가 표시됩니다.
 * 4. 사진을 탭하면 해당 사진의 상세 보기 화면(ShowDetailedPhoto)으로 이동합니다.
 * 5. 앱바에 카테고리 이름과 캘린더 아이콘을 표시합니다.
 * 
 * 데이터 흐름:
 * - 외부에서 categoryId와 categoryName을 위젯 생성자로 전달받습니다.
 * - CategoryViewModel을 통해 해당 카테고리의 사진 목록을 실시간 스트림으로 가져옵니다.
 * - StreamBuilder를 사용해 데이터가 변경될 때마다 UI가 자동으로 업데이트됩니다.
 * - 사진을 탭하면 전체 사진 목록과 탭한 사진의 인덱스를 ShowDetailedPhoto 위젯에 전달합니다.
 * 
 * 주요 위젯:
 * - StreamBuilder: Firebase에서 실시간으로 사진 데이터를 가져옵니다.
 * - MasonryGridView: 사진들을 다양한 높이의 타일로 표시하는 그리드 레이아웃을 제공합니다.
 * - Stack: 사진 위에 날짜를 오버레이 형태로 표시합니다.
 * - GestureDetector: 사진 탭 동작을 감지하여 상세 화면으로 이동합니다.
 * - ClipRRect: 이미지에 둥근 모서리를 적용합니다.
 * 
 * 사용된 외부 패키지:
 * - flutter_staggered_grid_view: 다양한 높이의 그리드 레이아웃을 구현하기 위해 사용합니다.
 * - intl: 날짜 형식을 지정하기 위해 사용합니다.
 * 
 * 참고사항:
 * - 랜덤 높이를 생성하여 시각적으로 더 다양한 그리드 레이아웃을 만듭니다.
 * - 캘린더 버튼 기능은 아직 구현되지 않았습니다.
 */

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/theme.dart';
import '../../view_model/category_view_model.dart';
import '../../model/photo_model.dart';
import 'show_detailed_photo.dart'; // 상세 화면 임포트

class ShowPhotoScreen extends StatelessWidget {
  final String categoryId; // 카테고리 ID를 외부에서 전달
  final String categoryName; // 카테고리 이름을 외부에서 전달

  const ShowPhotoScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final categoryViewModel = Provider.of<CategoryViewModel>(
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
            Text(categoryName, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      ),
      body: StreamBuilder<List<PhotoModel>>(
        stream: categoryViewModel.getPhotosStream(categoryId),
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
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.7,
            ),
            padding: const EdgeInsets.all(8.0),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              // 랜덤 높이: 200 ~ 350 사이 (예시)

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ShowDetailedPhoto(
                            photos: photos,
                            initialIndex: index,
                            categoryName: categoryName,
                            categoryId: categoryId,
                          ),
                    ),
                  );
                },
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    SizedBox(
                      width: 175,
                      height: 232,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(photo.imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                    Text(
                      DateFormat('yyyy.MM.dd').format(photo.createdAt.toDate()),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
