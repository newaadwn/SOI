import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/theme.dart';
import '../view_model/auth_view_model.dart';
import '../view_model/category_view_model.dart';
import 'widgets/custom_drawer.dart'; // 커스텀 Drawer 임포트 추가

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
    final categoryViewModel = Provider.of<CategoryViewModel>(
      context,
      listen: false,
    );

    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,

      appBar: AppBar(
        title: Text(
          'SOI',
          style: TextStyle(color: AppTheme.lightTheme.colorScheme.secondary),
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        toolbarHeight: 70 / 852 * screenHeight,

        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/category_add_screen');
            },
            icon: Icon(
              Icons.add,
              size: 35,
              color: AppTheme.lightTheme.colorScheme.secondary,
            ),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: authViewModel.getIdFromFirestore(),
        builder: (context, nickSnapshot) {
          if (nickSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!nickSnapshot.hasData) {
            return Center(child: Text('로그인 정보가 없습니다.'));
          }
          final nickName = nickSnapshot.data!;
          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: categoryViewModel.streamUserCategories(nickName),
            builder: (context, catSnapshot) {
              if (catSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (catSnapshot.hasError) {
                return Center(child: Text('카테고리를 불러오는데 오류가 발생했습니다.'));
              }
              final categories = catSnapshot.data ?? [];
              if (categories.isEmpty) {
                return Center(
                  child: Text(
                    '등록된 카테고리가 없습니다.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              // 전체 페이지를 SingleChildScrollView로 감싸서 스크롤 가능하게 함.
              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: (17 / 393) * screenWidth,
                    right: (17 / 393) * screenWidth,
                  ),
                  child: Column(
                    children: [
                      // 필요한 다른 위젯도 여기에 추가할 수 있음.
                      // 아래 GridView는 shrinkWrap과 NeverScrollableScrollPhysics를 적용하여
                      // 내부 스크롤이 생기지 않고 부모 SingleChildScrollView에 의해 스크롤 되도록 설정됨.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '최근 카테고리',
                            style: TextStyle(
                              color: Color(0xFFC4C4C4),
                              fontSize: 20 / 393 * screenWidth,
                              fontFamily: 'Pretendard Variable',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 2.9,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                ),
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              return Container(
                                decoration: ShapeDecoration(
                                  color: Color(0xFF292929),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {},
                                  child: Row(
                                    children: [
                                      StreamBuilder<String?>(
                                        stream: categoryViewModel
                                            .getFirstPhotoUrlStream(
                                              category['id'],
                                            ),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return SizedBox(
                                              width: 56 / 393 * screenWidth,
                                              height: 56 / 852 * screenHeight,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            );
                                          }
                                          if (snapshot.hasError ||
                                              !snapshot.hasData ||
                                              snapshot.data == null) {
                                            return Icon(
                                              Icons.photo,
                                              size: 56 / 393 * screenWidth,
                                            );
                                          }
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: Image.network(
                                              snapshot.data!,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                            ),
                                          );
                                        },
                                      ),
                                      SizedBox(width: 14 / 393 * screenWidth),
                                      Flexible(
                                        child: Text(
                                          category['name'],
                                          style: TextStyle(
                                            color:
                                                AppTheme
                                                    .lightTheme
                                                    .colorScheme
                                                    .secondary,
                                            fontSize: 16 / 393 * screenWidth,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
