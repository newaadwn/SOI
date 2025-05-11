import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../view_model/auth_view_model.dart';
import '../../view_model/category_view_model.dart';
import 'show_photo.dart';

class AllCategoryScreen extends StatefulWidget {
  const AllCategoryScreen({super.key});

  @override
  State<AllCategoryScreen> createState() => _AllCategoryScreenState();
}

class _AllCategoryScreenState extends State<AllCategoryScreen> {
  String? nickName;
  final Map<String, List<String>> _categoryProfileImages = {};

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    authViewModel.getIdFromFirestore().then((value) {
      setState(() {
        nickName = value;
      });
    });
  }

  Widget _buildProfileRow(List<String> profileImages) {
    // 이미지가 없거나 비어있으면 기본 이미지 하나만 표시
    if (profileImages.isEmpty) {
      return SizedBox(
        width: 20,
        height: 20,
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
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 4),
                child: Image.asset('assets/profile.png'),
              );
            }
            // 값이 있으면 해당 이미지를 원형으로 보여줘요.
            return Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 4),
              child: CircleAvatar(
                backgroundImage: NetworkImage(imageUrl),
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
    if (_categoryProfileImages.containsKey(categoryId)) {
      return;
    }

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final categoryViewModel = Provider.of<CategoryViewModel>(
      context,
      listen: false,
    );

    try {
      final profileImages = await categoryViewModel.getCategoryProfileImages(
        mates,
        authViewModel,
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
    // 화면의 너비와 높이를 가져와요.
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

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
    final categoryViewModel = Provider.of<CategoryViewModel>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // 기존의 streamUserCategoriesWithDetails 대신 streamUserCategories 함수 사용
        stream: categoryViewModel.streamUserCategories(nickName!),
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
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: (17 / 393) * screenWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.8,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
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
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: InkWell(
                          // 탭하면 사진 화면으로 이동해요.
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ShowPhotoScreen(
                                      categoryId: category['id'],
                                      categoryName: category['name'],
                                    ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                // 대표 사진을 보여줘요.
                                category['firstPhotoUrl'] != null
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        category['firstPhotoUrl'],
                                        width: 175,
                                        height: 145,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          debugPrint('카테고리 이미지 로드 오류: $error');
                                          return Container(
                                            width: 175,
                                            height: 145,
                                            color: const Color(0xFF383838),
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.white54,
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                    : SizedBox(
                                      width: 175,
                                      height: 145,
                                      child: const Icon(
                                        Icons.photo,
                                        color: Colors.white54,
                                      ),
                                    ),
                                SizedBox(height: 8 / 852 * screenHeight),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // 카테고리 이름 보여줘요.
                                    Text(
                                      category['name'],
                                      style: TextStyle(
                                        color:
                                            AppTheme
                                                .lightTheme
                                                .colorScheme
                                                .secondary,
                                        fontSize: 16 / 852 * screenHeight,
                                      ),
                                    ),
                                    // 프로필 사진들을 함수로 쉽게 보여줘요.
                                    _buildProfileRow(profileImages),
                                  ],
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
