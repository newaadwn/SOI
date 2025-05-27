/*
 * PersonalArchivesScreen
 * 
 * 이 화면은 사용자의 개인 아카이빙 카테고리를 표시하는 화면입니다.
 * 개인적으로 만든 카테고리(다른 사용자와 공유하지 않은 카테고리)만 표시합니다.
 * 
 * 기능 설명:
 * 1. Firebase에서 사용자의 닉네임을 불러옵니다.
 * 2. 닉네임을 이용하여 이 사용자가 생성한 개인 카테고리 목록을 불러옵니다.
 * 3. 각 카테고리는 그리드 형태로 표시됩니다.
 * 4. 각 카테고리 항목에는 대표 이미지와 카테고리 이름이 표시됩니다.
 * 5. 카테고리를 탭하면 해당 카테고리에 포함된 모든 사진을 볼 수 있는 CategoryPhotosScreen으로 이동합니다.
 * 
 * 데이터 흐름:
 * - AuthController: 사용자의 닉네임을 Firebase에서 가져오는 역할을 합니다.
 * - CategoryController: 사용자의 카테고리 정보를 실시간으로 스트리밍합니다.
 * - 카테고리 필터링: 'mates' 배열에 사용자의 닉네임만 포함된 카테고리를 개인 카테고리로 판단하여 표시합니다.
 * 
 * 주요 컴포넌트:
 * - StreamBuilder: Firebase의 실시간 데이터를 구독하여 UI를 업데이트합니다.
 * - GridView: 카테고리를 2열 그리드 형태로 표시합니다.
 * - _buildProfileRow: 카테고리에 참여한 사용자의 프로필 이미지를 표시합니다(이 화면에서는 자기 자신만 표시됨).
 * 
 * 상태 관리:
 * - nickName: 사용자의 닉네임을 저장하는 상태 변수입니다.
 */

import 'package:flutter/material.dart';
import 'package:flutter_swift_camera/controllers/category_controller.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/theme.dart';
import 'category_photos_screen.dart';

class PersonalArchivesScreen extends StatefulWidget {
  const PersonalArchivesScreen({super.key});

  @override
  State<PersonalArchivesScreen> createState() => _PersonalArchivesScreenState();
}

class _PersonalArchivesScreenState extends State<PersonalArchivesScreen> {
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

  Widget _buildProfileRow(Map<String, dynamic> category) {
    // profileImages 리스트 안의 각 항목을 확인해요.
    final List images = category['profileImages'] as List;
    return Row(
      children:
          images.map<Widget>((imageUrl) {
            // 만약 이미지가 빈 문자열이면, 기본 이미지를 보여줘요.
            if (imageUrl.toString().isEmpty) {
              return SizedBox(
                width: 20,
                height: 20,
                child: Image.asset('assets/profile.png'),
              );
            }
            // 값이 있으면 해당 이미지를 원형으로 보여줘요.
            return SizedBox(
              width: 20,
              height: 20,
              child: CircleAvatar(
                backgroundImage: NetworkImage(imageUrl),
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
    // 화면의 너비와 높이를 가져와요.

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
              padding: EdgeInsets.symmetric(
                horizontal: (17 / 393) * MediaQuery.of(context).size.width,
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
                            print(
                              "category['profileImages']: ${category['profileImages']}",
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CategoryPhotosScreen(
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
                                SizedBox(
                                  height:
                                      8 /
                                      852 *
                                      MediaQuery.of(context).size.height,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
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
                                    _buildProfileRow(category),
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
