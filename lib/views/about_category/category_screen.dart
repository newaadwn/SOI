import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/auth_controller.dart';
import 'category_screen_photo.dart';

class CategoryScreen extends StatefulWidget {
  final String categoryId;
  const CategoryScreen({super.key, required this.categoryId});

  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    final authController = Provider.of<AuthController>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<String?>(
          future: categoryController.getCategoryName(widget.categoryId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text('Loading...');
            } else if (snapshot.hasError) {
              return Text('Error');
            } else if (!snapshot.hasData || snapshot.data == null) {
              return Text('No Category Name');
            } else {
              //return Text(snapshot.data!);
              return Text("닉네임 검색하기");
            }
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '사용자 닉네임 검색하기',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    authController.searchNickName(_searchController.text);
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: Consumer<AuthController>(
              builder: (context, authController, child) {
                return ListView.builder(
                  itemCount: authController.searchResults.length,
                  itemBuilder: (context, index) {
                    final nickName = authController.searchResults[index];
                    return ListTile(
                      title: Text(nickName),
                      trailing: IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          _addUserToCategory(context, nickName);
                          _addUidToCategory(context, authController.getUserId!);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CategoryScreenPhoto(
                                    categoryId: widget.categoryId,
                                  ),
                            ),
                          );
                        },
                      ),
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

  Future<void> _addUserToCategory(BuildContext context, String nickName) async {
    try {
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      await categoryController.addUserToCategory(widget.categoryId, nickName);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사용자가 카테고리에 추가되었습니다.')));
    } catch (e) {
      debugPrint('Error adding user to category: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사용자 추가 중 오류가 발생했습니다.')));
    }
  }

  Future<void> _addUidToCategory(BuildContext context, String uid) async {
    try {
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      await categoryController.addUidToCategory(widget.categoryId, uid);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사용자가 카테고리에 추가되었습니다.')));
    } catch (e) {
      debugPrint('Error adding user to category: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('사용자 추가 중 오류가 발생했습니다.')));
    }
  }
}
