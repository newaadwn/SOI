import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/category_controller.dart';
import '../../models/category_data_model.dart';
import '../../theme/theme.dart';
import 'category_photos_screen.dart';

// 전체 아카이브 화면
// 모든 사용자의 아카이브 목록을 표시
// 아카이브를 클릭하면 아카이브 상세 화면으로 이동
class AllArchivesScreen extends StatefulWidget {
  const AllArchivesScreen({super.key});

  @override
  State<AllArchivesScreen> createState() => _AllArchivesScreenState();
}

class _AllArchivesScreenState extends State<AllArchivesScreen> {
  String? nickName;
  final Map<String, List<String>> _categoryProfileImages = {};

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
    // 화면 크기에 따라 프로필 이미지 크기 조정 (최소 16, 최대 24)
    return (screenWidth * 0.055).clamp(16.0, 24.0);
  }

  /// 그리드 아이템의 가로 세로 비율 계산
  double _getGridAspectRatio(BuildContext context) {
    final screenWidth = _getResponsiveWidth(context);
    final screenHeight = _getResponsiveHeight(context);

    // 화면 비율에 따라 조정 (세로가 긴 화면에서는 카드를 더 길게)
    final screenRatio = screenHeight / screenWidth;
    if (screenRatio > 2.0) {
      return 0.75; // 매우 긴 화면
    } else if (screenRatio > 1.8) {
      return 0.8; // 일반적인 긴 화면
    } else {
      return 0.85; // 상대적으로 짧은 화면
    }
  }

  /// 그리드 열 개수 계산 (화면 크기에 따라)
  int _getGridCrossAxisCount(BuildContext context) {
    final screenWidth = _getResponsiveWidth(context);

    if (screenWidth < 360) {
      return 1; // 매우 작은 화면
    } else if (screenWidth < 500) {
      return 2; // 일반적인 폰 크기
    } else if (screenWidth < 800) {
      return 3; // 큰 폰이나 작은 태블릿
    } else {
      return 4; // 태블릿
    }
  }

  /// 카테고리 이름 폰트 크기 계산
  double _getCategoryNameFontSize(BuildContext context) {
    final screenWidth = _getResponsiveWidth(context);
    // 화면 크기에 비례하여 폰트 크기 조정 (최소 14, 최대 14)
    return (screenWidth * 0.042).clamp(14.0, 14.0);
  }

  /// 카테고리 이미지 크기 계산
  Size _getCategoryImageSize(BuildContext context) {
    final screenWidth = _getResponsiveWidth(context);
    final crossAxisCount = _getGridCrossAxisCount(context);

    // 그리드 아이템 크기에서 패딩을 뺀 값
    final horizontalPadding = screenWidth * 0.086; // 전체 패딩
    final gridSpacing = (crossAxisCount - 1) * 8; // 그리드 간격
    final availableWidth = screenWidth - horizontalPadding - gridSpacing;
    final itemWidth = availableWidth / crossAxisCount;

    // 이미지는 아이템 크기에서 패딩을 뺀 값
    final imageWidth = (itemWidth - 16).clamp(120.0, 200.0);
    final imageHeight = (imageWidth * 0.82).clamp(100.0, 160.0);

    return Size(imageWidth, imageHeight);
  }

  Widget _buildProfileRow(List<String> profileImages, BuildContext context) {
    final profileSize = _getProfileImageSize(context);

    // 이미지가 없거나 비어있으면 기본 이미지 하나만 표시
    if (profileImages.isEmpty) {
      return SizedBox(
        width: profileSize,
        height: profileSize,
        child: Image.asset('assets/profile.png'),
      );
    }

    // 최대 3개까지만 표시하도록 제한
    final displayImages = profileImages.take(3).toList();

    return Row(
      children:
          displayImages.map<Widget>((imageUrl) {
            // 만약 이미지가 빈 문자열이면, 기본 이미지를 보여줘요.
            if (imageUrl.toString().isEmpty) {
              return Container(
                width: profileSize,
                height: profileSize,
                margin: const EdgeInsets.only(right: 4),
                child: Image.asset('assets/profile.png'),
              );
            }
            // 값이 있으면 해당 이미지를 원형으로 보여줘요.
            return Container(
              width: profileSize,
              height: profileSize,
              margin: const EdgeInsets.only(right: 4),
              child: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(imageUrl),
                onBackgroundImageError: (exception, stackTrace) {
                  debugPrint('이미지 로딩 오류: $exception');
                  // 에러 발생 시 별도 처리가 필요하면 여기에 추가
                },
                // 이미지 로드 실패 시 기본 이미지 표시
                child:
                    imageUrl.isEmpty ? Image.asset('assets/profile.png') : null,
              ),
            );
          }).toList(),
    );
  }

  // 카테고리에 대한 프로필 이미지를 가져오는 함수
  Future<void> _loadProfileImages(String categoryId, List<String> mates) async {
    // Skip if already loaded
    if (_categoryProfileImages.containsKey(categoryId)) {
      return;
    }

    final authController = Provider.of<AuthController>(context, listen: false);
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    try {
      final profileImages = await categoryController.getCategoryProfileImages(
        mates,
        authController,
      );
      setState(() {
        _categoryProfileImages[categoryId] = profileImages;
      });
    } catch (e) {
      debugPrint('프로필 이미지 로딩 오류: $e');
      setState(() {
        _categoryProfileImages[categoryId] = [];
      });
    }
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

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // 기존의 streamUserCategoriesWithDetails 대신 streamUserCategories 함수 사용
        stream: categoryController.streamUserCategoriesAsMap(nickName!),
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
              child: Text(
                '카테고리 로딩 중 오류가 발생했습니다.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          // 데이터 없으면
          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return const Center(
              child: Text(
                '등록된 카테고리가 없습니다.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          // 모든 카테고리에 대해 프로필 이미지 로드 요청
          for (var category in categories) {
            final categoryId = category['id'] as String;
            final mates = (category['mates'] as List).cast<String>();
            _loadProfileImages(categoryId, mates);
          }

          // 데이터가 있으면 화면을 스크롤할 수 있도록 만듭니다.
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  screenWidth *
                  0.051, // 20/393 비율을 유지하되 반응형으로 (20 ÷ 393 ≈ 0.05089)
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.01), // 반응형 간격
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: aspectRatio,
                      mainAxisSpacing: screenWidth * 0.04, // 반응형 간격
                      crossAxisSpacing: screenWidth * 0.04, // 반응형 간격
                    ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final categoryId = category['id'] as String;
                      final profileImages =
                          _categoryProfileImages[categoryId] ?? [];

                      return Container(
                        decoration: ShapeDecoration(
                          color: const Color(0xFF292929),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.61),
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
                                        firstPhotoUrl:
                                            category['firstPhotoUrl'],
                                      ),
                                    ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsets.all(
                              screenWidth * 0.02,
                            ), // 반응형 패딩
                            child: Column(
                              children: [
                                // 대표 사진을 보여줘요.
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
                                      child: Icon(Icons.image),
                                    ),

                                SizedBox(height: screenHeight * 0.01), // 반응형 간격
                                // 카테고리 이름과 프로필 영역
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 카테고리 이름
                                      SizedBox(
                                        width: double.infinity,
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

                                      // 프로필 이미지들
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildProfileRow(
                                          profileImages,
                                          context,
                                        ),
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
