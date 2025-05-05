import 'package:flutter/material.dart';
import 'package:flutter_swift_camera/view/widgets/custom_drawer.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import 'all_category_screen.dart';
import 'my_record_screen.dart';
import 'share_record_screen.dart';
import '../../../view_model/auth_view_model.dart';

class ArchivingScreen extends StatefulWidget {
  const ArchivingScreen({super.key});

  @override
  State<ArchivingScreen> createState() => _ArchivingScreenState();
}

class _ArchivingScreenState extends State<ArchivingScreen> {
  int _selectedIndex = 0;

  // 탭 화면 목록
  final List<Widget> _screens = const [
    AllCategoryScreen(),
    MyRecordScreen(),
    ShareRecordScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      drawer: CustomDrawer(),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'SOI',
          style: TextStyle(color: AppTheme.lightTheme.colorScheme.secondary),
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        toolbarHeight: 70 / 852 * screenHeight,
        leading: Consumer<AuthViewModel>(
          builder: (context, authViewModel, _) {
            return FutureBuilder<String>(
              future: authViewModel.getIdFromFirestore(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  );
                }

                return StreamBuilder<List>(
                  stream: authViewModel.getprofileImages([snapshot.data ?? '']),
                  builder: (context, imageSnapshot) {
                    String profileImageUrl = '';
                    if (imageSnapshot.hasData &&
                        imageSnapshot.data!.isNotEmpty) {
                      profileImageUrl = imageSnapshot.data!.first as String;
                    }

                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Builder(
                          builder:
                              (context) =>
                                  profileImageUrl.isNotEmpty
                                      ? InkWell(
                                        onTap: () {
                                          Scaffold.of(context).openDrawer();
                                        },
                                        child: SizedBox(
                                          width: 34,
                                          height: 34,
                                          child: CircleAvatar(
                                            backgroundImage: NetworkImage(
                                              profileImageUrl,
                                            ),
                                          ),
                                        ),
                                      )
                                      : InkWell(
                                        onTap: () {
                                          Scaffold.of(context).openDrawer();
                                        },
                                        child: const CircleAvatar(
                                          backgroundColor: Colors.grey,
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 34,
                                          ),
                                        ),
                                      ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Image.asset('assets/person_add.png', width: 19, height: 19),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.add, color: Colors.white),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildChip('전체', 0),
                const SizedBox(width: 8),
                _buildChip('나의 기록', 1),
                const SizedBox(width: 8),
                _buildChip('공유 기록', 2),
              ],
            ),
          ),
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }

  // 선택 가능한 Chip 위젯 생성
  Widget _buildChip(String label, int index) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xff292929) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
