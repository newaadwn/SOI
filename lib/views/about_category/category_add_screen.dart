import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/category_controller.dart';
import '../../theme/theme.dart';
import '../../controllers/auth_controller.dart';

class CategoryAddScreen extends StatefulWidget {
  const CategoryAddScreen({super.key});

  @override
  State<CategoryAddScreen> createState() => _CategoryAddScreenState();
}

class _CategoryAddScreenState extends State<CategoryAddScreen> {
  final TextEditingController _categoryNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // 글로벌 navigator key
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _categoryNameController.dispose(); // 컨트롤러 해제
    _searchController.dispose(); // 컨트롤러 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    //double screenHeight = MediaQuery.of(context).size.height;

    final authController = Provider.of<AuthController>(context, listen: false);
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    //Color selectedColor = Color(0xff454242);

    // 검색 버튼 클릭 시 사용자 검색 실행
    void _searchUser() {
      if (_searchController.text.isNotEmpty) {
        authController.searchNickName(_searchController.text.trim());
      }
    }

    Future<void> _createCategory() async {
      // 카테고리 이름 검증
      if (_categoryNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('카테고리 이름을 입력해주세요.')));
        return;
      }

      final String categoryName = _categoryNameController.text;
      // AuthController에서 현재 닉네임과 userId 가져오기
      final String? userId = authController.getUserId;
      final String userNickName = await authController.getIdFromFirestore();

      // 현재 CategoryController의 selectedNames는 사용자가 추가한 다른 친구들입니다.
      List<String> mates = List.from(categoryController.selectedNames);

      // 여기에 현재 유저의 닉네임을 추가 (단, 이미 없다면)
      if (!mates.contains(userNickName)) {
        mates.add(userNickName);
      }

      try {
        // CategoryController의 createCategory를 호출하면 Firestore에 문서가 생성됩니다.
        await categoryController.createCategory(categoryName, mates, userId!);
        _categoryNameController.clear();
        categoryController.clearSelectedNames();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("카테고리 생성 중 오류가 발생했습니다. 다시 시도해주세요.")),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white, //색변경
        ),
        title: Text(
          'SOI',
          style: TextStyle(color: AppTheme.lightTheme.colorScheme.secondary),
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        toolbarHeight: 70,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                '카테고리 생성',
                style: AppTheme.lightTheme.textTheme.displayMedium!.copyWith(
                  fontSize: (20 / 393) * screenWidth,
                  color: AppTheme.lightTheme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 32),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 359,
                    height: 359,
                    decoration: ShapeDecoration(
                      color: Color(0xFF535252),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: 1,
                          strokeAlign: BorderSide.strokeAlignOutside,
                          color: Color(0xFF535252),
                        ),
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '새 Task 추가',
                        textAlign: TextAlign.center,
                        style: AppTheme.lightTheme.textTheme.labelMedium!
                            .copyWith(
                              fontSize: (30 / 393) * screenWidth,
                              color: Color(0xffd9d9d9),
                            ),
                      ),
                      SizedBox(height: 18),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFD9D9D9),
                          shape: CircleBorder(),
                          fixedSize: Size(56, 56),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () {},
                        child: Icon(Icons.add, size: 40, color: Colors.black),
                      ),
                      SizedBox(height: 24),
                      SizedBox(
                        width: 191,
                        height: 44,
                        child: TextField(
                          controller: _categoryNameController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF232121),
                            hintText: '카테고리 이름 입력',
                            hintStyle: AppTheme
                                .lightTheme
                                .textTheme
                                .labelMedium!
                                .copyWith(
                                  color: Color.fromRGBO(234, 216, 202, 0.5),
                                  fontSize: (16 / 393) * screenWidth,
                                ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: AppTheme.lightTheme.textTheme.labelMedium!
                              .copyWith(color: Color(0xFFEAD8CA)),
                        ),
                      ),
                      SizedBox(height: 21),
                      ElevatedButton(
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: Color(0xff454242),
                            builder: (BuildContext context) {
                              return Column(
                                children: [
                                  SizedBox(height: 10),
                                  SizedBox(
                                    width: 350,
                                    child: TextField(
                                      controller: _searchController,
                                      style: TextStyle(
                                        color:
                                            AppTheme
                                                .lightTheme
                                                .colorScheme
                                                .secondary,
                                      ),
                                      cursorColor:
                                          AppTheme
                                              .lightTheme
                                              .colorScheme
                                              .secondary,
                                      decoration: InputDecoration(
                                        hintText: '닉네임 검색하기',
                                        hintStyle: AppTheme
                                            .lightTheme
                                            .textTheme
                                            .displayMedium!
                                            .copyWith(
                                              fontSize:
                                                  (16 / 393) * screenWidth,
                                              color:
                                                  AppTheme
                                                      .lightTheme
                                                      .colorScheme
                                                      .secondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                AppTheme
                                                    .lightTheme
                                                    .colorScheme
                                                    .secondary,
                                          ), // 비포커스 상태의 라인 색
                                        ),
                                        focusedBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color:
                                                AppTheme
                                                    .lightTheme
                                                    .colorScheme
                                                    .secondary,
                                          ), // 포커스 상태의 라인 색
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(Icons.search),
                                          color:
                                              AppTheme
                                                  .lightTheme
                                                  .colorScheme
                                                  .secondary,
                                          onPressed: _searchUser,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Consumer<AuthController>(
                                      builder: (
                                        context,
                                        authController,
                                        child,
                                      ) {
                                        return ListView.builder(
                                          itemCount:
                                              authController
                                                  .searchResults
                                                  .length,
                                          itemBuilder: (context, index) {
                                            final nickName =
                                                authController
                                                    .searchResults[index];
                                            final profileImage =
                                                authController
                                                    .searchProfileImage[index];
                                            // Consumer<CategoryController>를 사용하여 CategoryController의 변경 사항을 구독합니다.
                                            return Consumer<CategoryController>(
                                              builder: (
                                                BuildContext context,
                                                CategoryController
                                                categoryController,
                                                Widget? child,
                                              ) {
                                                // ListTile을 반환합니다.
                                                return ListTile(
                                                  // 선택된 이름인지 확인하여 배경색을 지정합니다.
                                                  tileColor:
                                                      categoryController
                                                              .selectedNames
                                                              .contains(
                                                                nickName,
                                                              )
                                                          ? Color.fromRGBO(
                                                            0,
                                                            0,
                                                            0,
                                                            0.5,
                                                          )
                                                          : Color(0xff454242),
                                                  // 프로필 이미지를 표시합니다. 이미지 URL이 없으면 기본 이미지 사용.
                                                  leading:
                                                      profileImage.isEmpty
                                                          ? Image.asset(
                                                            'assets/profile.png',
                                                            width: 40,
                                                            height: 40,
                                                          )
                                                          : ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  100,
                                                                ),
                                                            child: Image.network(
                                                              profileImage,
                                                              width: 40,
                                                              height: 40,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                  // 닉네임을 타이틀로 출력.
                                                  title: Text(
                                                    nickName,
                                                    style: TextStyle(
                                                      color:
                                                          AppTheme
                                                              .lightTheme
                                                              .colorScheme
                                                              .secondary,
                                                    ),
                                                  ),
                                                  // 탭 시, 선택 상태를 토글하고 UI를 갱신합니다.
                                                  onTap: () {
                                                    categoryController
                                                        .toggleName(nickName);
                                                    setState(() {}); // 상태 업데이트
                                                    print(
                                                      categoryController
                                                          .selectedNames,
                                                    );
                                                  },
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ).then((value) {
                            // BottomSheet가 닫힌 후 텍스트 필드와 검색 리스트를 초기화
                            _searchController.clear();
                            authController.clearSearchResults();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF232121),
                          fixedSize: const Size(191, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        child: Text(
                          'Add mate',
                          style: AppTheme.lightTheme.textTheme.labelMedium!
                              .copyWith(
                                color: Color(0xffead8ca),
                                fontSize: 16 / 393 * screenWidth,
                              ),
                        ),
                      ),
                      SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _createCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppTheme.lightTheme.colorScheme.secondary,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Container(
                          width: (99 / 393) * MediaQuery.of(context).size.width,
                          height:
                              (31 / 852) * MediaQuery.of(context).size.height,
                          alignment: Alignment.center,
                          child: Text(
                            '확인',
                            style: AppTheme.lightTheme.textTheme.labelMedium!
                                .copyWith(
                                  fontSize:
                                      (14 / 393) *
                                      MediaQuery.of(context).size.width,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
