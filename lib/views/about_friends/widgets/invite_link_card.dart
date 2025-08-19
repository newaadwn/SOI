import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InviteLinkCard extends StatelessWidget {
  final double scale;

  const InviteLinkCard({super.key, required this.scale});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 354,
      height: 96,
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: const Color(0xff1c1c1c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 18.w),
              _buildLinkCardContent(context, scale, '링크 복사', 'assets/link.png'),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(context, scale, '공유', 'assets/share.png'),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(context, scale, '카카오톡', 'assets/kakao.png'),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                '인스타그램',
                'assets/insta.png',
              ),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                '메세지',
                'assets/message.png',
              ),
              SizedBox(width: (18).w),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkCardContent(
    BuildContext context,
    double scale,
    String title,
    String imagePath,
  ) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공유 기능을 구현해주세요'),
            backgroundColor: Color(0xff404040),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Image.asset(imagePath, width: (51.76).w, height: (51.76).w),
          ),
          SizedBox(height: (7.24).h),
          Text(
            title,
            style: TextStyle(
              color: const Color(0xfff9f9f9),
              fontSize: (12).sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
