import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FriendAddScreen extends StatefulWidget {
  const FriendAddScreen({super.key});

  @override
  State<FriendAddScreen> createState() => _State();
}

class _State extends State<FriendAddScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '친구목록',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: Color(0xfff9f9f9),
            fontFamily: 'Pretendard',
          ),
        ),
      ),
      body: Center(child: Text('친구 추가 화면', style: TextStyle(fontSize: 24.sp))),
    );
  }
}
