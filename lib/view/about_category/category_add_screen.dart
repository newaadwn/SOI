import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../view_model/auth_view_model.dart';
import '../../view_model/category_view_model.dart';

class CategoryAddScreen extends StatefulWidget {
  const CategoryAddScreen({super.key});

  @override
  State<CategoryAddScreen> createState() => _CategoryAddScreenState();
}

class _CategoryAddScreenState extends State<CategoryAddScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 글로벌 navigator key
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final categoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    categoryController.dispose(); // 컨트롤러 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    //double screenHeight = MediaQuery.of(context).size.height;

    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final categoryViewModel = Provider.of<CategoryViewModel>(
      context,
      listen: false,
    );

    //Color selectedColor = Color(0xff454242);

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
                          controller: categoryController,
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
                                          onPressed: () {
                                            authViewModel.searchNickName(
                                              _searchController.text,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Consumer<AuthViewModel>(
                                      builder: (context, authViewModel, child) {
                                        return ListView.builder(
                                          itemCount:
                                              authViewModel
                                                  .searchResults
                                                  .length,
                                          itemBuilder: (context, index) {
                                            final nickName =
                                                authViewModel
                                                    .searchResults[index];
                                            final profileImage =
                                                authViewModel
                                                    .searchProfileImage[index];
                                            // Consumer<CategoryViewModel>를 사용하여 CategoryViewModel의 변경 사항을 구독합니다.
                                            return Consumer<CategoryViewModel>(
                                              builder: (
                                                BuildContext context,
                                                CategoryViewModel
                                                categoryViewModel,
                                                Widget? child,
                                              ) {
                                                // ListTile을 반환합니다.
                                                return ListTile(
                                                  // 선택된 이름인지 확인하여 배경색을 지정합니다.
                                                  tileColor:
                                                      categoryViewModel
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
                                                    categoryViewModel
                                                        .toggleName(nickName);
                                                    setState(() {}); // 상태 업데이트
                                                    print(
                                                      categoryViewModel
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
                            authViewModel.clearSearchResults();
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
                        onPressed: () async {
                          if (categoryController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("카테고리 이름을 먼저 입력하세요.")),
                            );
                            return;
                          }
                          final String categoryName = categoryController.text;
                          // AuthViewModel에서 현재 닉네임과 userId 가져오기
                          final String? userId = authViewModel.getUserId;
                          final String userNickName =
                              await authViewModel.getNickNameFromFirestore();

                          // 현재 CategoryViewModel의 selectedNames는 사용자가 추가한 다른 친구들입니다.
                          List<String> mates = List.from(
                            categoryViewModel.selectedNames,
                          );

                          // 여기에 현재 유저의 닉네임을 추가 (단, 이미 없다면)
                          if (!mates.contains(userNickName)) {
                            mates.add(userNickName);
                          }

                          try {
                            // CategoryViewModel의 createCategory를 호출하면 Firestore에 문서가 생성됩니다.
                            await categoryViewModel.createCategory(
                              categoryName,
                              mates,
                              userId!,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("카테고리가 생성되었습니다.")),
                            );
                            categoryController.clear();
                            categoryViewModel.clearSelectedNames();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "카테고리 생성 중 오류가 발생했습니다. 다시 시도해주세요.",
                                ),
                              ),
                            );
                          }
                        },
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
