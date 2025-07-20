import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../models/category_data_model.dart';
import '../../theme/theme.dart';
import 'category_photos_screen.dart';

// 나의 아카이브 화면
// 현재 사용자의 아카이브 목록을 표시
// 아카이브를 클릭하면 아카이브 상세 화면으로 이동
class MyArchivesScreen extends StatefulWidget {
  const MyArchivesScreen({super.key});

  @override
  State<MyArchivesScreen> createState() => _MyArchivesScreenState();
}

class _MyArchivesScreenState extends State<MyArchivesScreen> {
  String? nickName;

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    final authController = Provider.of<AuthController>(context, listen: false);
    authController.getIdFromFirestore().then((value) {
      setState(() {
        nickName = value;
      });
    });
  }

  /// 화면 크기별 반응형 값 계산 헬퍼 메서드들
  double _getResponsiveWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth;
  }

  double _getResponsiveHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return screenHeight;
  }

  /// 프로필 이미지 크기 계산 (화면 크기에 따라 조정)
  double _getProfileImageSize(BuildContext context) {
    final screenWidth = _getResponsiveWidth(context);
    return (screenWidth * 0.055).clamp(16.0, 24.0);
  }

  /// 그리드 아이템의 가로 세로 비율 계산
  double _getGridAspectRatio(BuildContext context) {
    final screenWidth = _getResponsiveWidth(context);
    final screenHeight = _getResponsiveHeight(context);

    final screenRatio = screenHeight / screenWidth;
    if (screenRatio > 2.0) {
      return 0.75;
    } else if (screenRatio > 1.8) {
      return 0.8;
    } else {
      return 0.85;
    }
  }

  /// 그리드 열 개수 계산 (화면 크기에 따라)
  int _getGridCrossAxisCount(BuildContext context) {
    final screenWidth = _getResponsiveWidth(context);

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

  /// 카테고리 이름 폰트 크기 계산
  double _getCategoryNameFontSize(BuildContext context) {
    final screenWidth = _getResponsiveWidth(context);
    return (screenWidth * 0.042).clamp(14.0, 18.0);
  }

  /// 카테고리 이미지 크기 계산
  Size _getCategoryImageSize(BuildContext context) {
    final screenWidth = _getResponsiveWidth(context);
    final crossAxisCount = _getGridCrossAxisCount(context);

    final horizontalPadding = screenWidth * 0.086;
    final gridSpacing = (crossAxisCount - 1) * 8;
    final availableWidth = screenWidth - horizontalPadding - gridSpacing;
    final itemWidth = availableWidth / crossAxisCount;

    final imageWidth = (itemWidth - 16).clamp(120.0, 200.0);
    final imageHeight = (imageWidth * 0.82).clamp(100.0, 160.0);

    return Size(imageWidth, imageHeight);
  }

  Widget _buildProfileRow(Map<String, dynamic> category, BuildContext context) {
    final profileSize = _getProfileImageSize(context);
    final screenWidth = _getResponsiveWidth(context);

    // profileImages 리스트 안의 각 항목을 확인해요.
    final List images = category['profileImages'] as List? ?? [];
    return Row(
      children:
          images.map<Widget>((imageUrl) {
            // 만약 이미지가 빈 문자열이면, 기본 이미지를 보여줘요.
            if (imageUrl.toString().isEmpty) {
              return Container(
                width: profileSize,
                height: profileSize,
                margin: EdgeInsets.only(right: screenWidth * 0.011), // 반응형 마진
                child: Image.asset('assets/profile.png'),
              );
            }
            // 값이 있으면 해당 이미지를 원형으로 보여줘요.
            return Container(
              width: profileSize,
              height: profileSize,
              margin: EdgeInsets.only(right: screenWidth * 0.011), // 반응형 마진
              child: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(imageUrl),
                onBackgroundImageError: (exception, stackTrace) {
                  debugPrint('이미지 로딩 오류: $exception');
                },
                child:
                    imageUrl.isEmpty ? Image.asset('assets/profile.png') : null,
              ),
            );
          }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 값들 계산
    final screenWidth = _getResponsiveWidth(context);
    final screenHeight = _getResponsiveHeight(context);
    final crossAxisCount = _getGridCrossAxisCount(context);
    final aspectRatio = _getGridAspectRatio(context);
    final categoryNameFontSize = _getCategoryNameFontSize(context);
    final imageSize = _getCategoryImageSize(context);

    // 만약 닉네임을 아직 못 가져왔다면 로딩 중이에요.
    if (nickName == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 카테고리 정보를 가져오는 스트림을 구독해요.
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    final authController = Provider.of<AuthController>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: categoryController.streamUserCategoriesWithDetails(
          nickName!,
          authController,
        ),
        builder: (context, snapshot) {
          // 데이터가 불러오는 중일때
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          // 에러가 생겼을 때
          if (snapshot.hasError) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final categories = snapshot.data ?? [];
          // 사용자 카테고리만 필터링합니다.
          final userCategories =
              categories
                  .where(
                    (category) => category['mates'].every(
                      (element) => element == nickName,
                    ),
                  )
                  .toList();

          if (userCategories.isEmpty) {
            return const Center(
              child: Text(
                '등록된 카테고리가 없습니다.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.043),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.01),
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: aspectRatio,
                      mainAxisSpacing: screenWidth * 0.02,
                      crossAxisSpacing: screenWidth * 0.02,
                    ),
                    itemCount: userCategories.length,
                    itemBuilder: (context, index) {
                      final category = userCategories[index];
                      return Container(
                        decoration: ShapeDecoration(
                          color: const Color(0xFF292929),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            debugPrint(
                              "category['profileImages']: ${category['profileImages']}",
                            );
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
                                        firstPhotoUrl:
                                            category['firstPhotoUrl'],
                                      ),
                                    ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(screenWidth * 0.02),
                            child: Column(
                              children: [
                                category['firstPhotoUrl'] != null
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: CachedNetworkImage(
                                        imageUrl: category['firstPhotoUrl'],
                                        width: imageSize.width,
                                        height: imageSize.height,
                                        fit: BoxFit.cover,
                                        placeholder:
                                            (context, url) => Container(
                                              width: imageSize.width,
                                              height: imageSize.height,
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.grey,
                                                    ),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) => Container(
                                              width: imageSize.width,
                                              height: imageSize.height,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.error,
                                                color: Colors.grey,
                                              ),
                                            ),
                                      ),
                                    )
                                    : Container(
                                      width: imageSize.width,
                                      height: imageSize.height,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: Colors.grey[300],
                                      ),
                                      child: const Icon(
                                        Icons.photo,
                                        color: Colors.white54,
                                      ),
                                    ),
                                SizedBox(height: screenHeight * 0.01),

                                // 카테고리 이름과 프로필 영역
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              category['name'],
                                              style: TextStyle(
                                                color:
                                                    AppTheme
                                                        .lightTheme
                                                        .colorScheme
                                                        .secondary,
                                                fontSize: categoryNameFontSize,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          _buildProfileRow(category, context),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
