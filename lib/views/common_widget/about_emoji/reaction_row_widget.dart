// 리액션 행: 댓글 파형 레이아웃과 동일 구조, 가운데 파형 영역을 이모지 박스로 대체
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../utils/format_utils.dart';

class ReactionRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String emoji;
  const ReactionRow({super.key, required this.data, this.emoji = ''});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        children: [
          // 리액션 내용
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 이미지
              ClipOval(
                child:
                    (data['profileImageUrl'] ?? '').toString().isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: data['profileImageUrl'],
                          width: 38.w,
                          height: 38.w,
                          fit: BoxFit.cover,
                        )
                        : Container(
                          width: 38.w,
                          height: 38.w,
                          color: const Color(0xFF4E4E4E),
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
              ),
              SizedBox(width: 12.w),
              // 아이디와 리액션 이모지를 묶은 Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['id'] ?? '').toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                      ),
                    ),

                    Container(
                      alignment: Alignment.centerRight,
                      child: Text(
                        emoji.isEmpty ? '😊' : emoji,
                        style: TextStyle(fontSize: 32.sp),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
            ],
          ),
          // 시간 표시
          Row(
            children: [
              const Spacer(),
              Text(
                FormatUtils.formatRelativeTime(
                  (data['createdAt'] is Timestamp)
                      ? (data['createdAt'] as Timestamp).toDate()
                      : DateTime.now(),
                ),
                style: TextStyle(
                  color: const Color(0xFFB5B5B5),
                  fontSize: 12.sp,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(width: 12.w),
            ],
          ),
        ],
      ),
    );
  }
}
