import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/category_controller.dart';
import '../../theme/theme.dart';
import '../../controllers/auth_controller.dart';

class CategorySelectScreen extends StatefulWidget {
  const CategorySelectScreen({super.key});

  @override
  State<CategorySelectScreen> createState() => _CategorySelectScreenState();
}

class _CategorySelectScreenState extends State<CategorySelectScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final categoryController = Provider.of<CategoryController>(context);
    final authController = Provider.of<AuthController>(context);
    TextEditingController categoryNameController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: Text('카테고리 선택')),
      body: Column(
        children: [
          TextField(
            controller: categoryNameController,
            decoration: InputDecoration(
              hintText: '카테고리 추가하기',
              suffixIcon: IconButton(
                icon: Icon(Icons.add),
                onPressed: () async {
                  debugPrint("userId: ${authController.getUserId}");
                  /* 카테고리 생성 로직은 나중에 구현 */
                },
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: authController.getIdFromFirestore(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('오류 발생: ${snapshot.error}'));
                }
                final nickName = snapshot.data!;
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: categoryController.streamUserCategoriesAsMap(
                    nickName,
                  ),
                  builder: (context, catSnapshot) {
                    if (catSnapshot.connectionState ==
                        ConnectionState.waiting) {
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
                    return ListView.builder(
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return ListTile(
                          title: Text(
                            category['name'],
                            style: TextStyle(
                              color: AppTheme.lightTheme.colorScheme.secondary,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CategorySelectScreen(),
                              ),
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
      ),
    );
  }
}
