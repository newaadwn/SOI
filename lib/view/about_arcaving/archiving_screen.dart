import 'package:flutter/material.dart';
import 'package:iconify_flutter/icons/uil.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import '../../theme/theme.dart';
import 'all_category_screen.dart';
import 'my_record_screen.dart';
import 'share_record_screen.dart';

class ArchivingScreen extends StatefulWidget {
  const ArchivingScreen({super.key});

  @override
  State<ArchivingScreen> createState() => _ArchivingScreenState();
}

class _ArchivingScreenState extends State<ArchivingScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;

    return DefaultTabController(
      initialIndex: 1,
      length: 3,
      child: Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        appBar: AppBar(
          title: Text(
            'SOI',
            style: TextStyle(color: AppTheme.lightTheme.colorScheme.secondary),
          ),
          backgroundColor: AppTheme.lightTheme.colorScheme.surface,
          toolbarHeight: 70,
          actions: [
            IconButton(
              onPressed: () {},
              icon: Iconify(
                Uil.setting,
                color: Colors.white,
                size: 30,
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    labelStyle: TextStyle(
                      color: Color(0xFFD9D9D9),
                      fontSize: 17.9 / 852 * screenHeight,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: <Widget>[
                      Tab(text: '전체'),
                      Tab(text: '나의 기록'),
                      Tab(text: '공유 기록'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.add,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const <Widget>[
            AllCategoryScreen(),
            MyRecordScreen(),
            ShareRecordScreen(),
          ],
        ),
      ),
    );
  }
}
