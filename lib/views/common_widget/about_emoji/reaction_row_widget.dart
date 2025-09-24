// 리액션 행: 댓글 파형 레이아웃과 동일 구조, 가운데 파형 영역을 이모지 박스로 대체
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:soi/models/comment_record_model.dart';
import '../../../utils/format_utils.dart';

class ReactionRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String emoji;
  final CommentRecordModel comment;

  const ReactionRow({
    super.key,
    required this.data,
    this.emoji = '',
    required this.comment,
  });

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
                    (comment.profileImageUrl).isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: comment.profileImageUrl,
                          width: 44.w,
                          height: 44.w,
                          memCacheHeight:
                              (44 * 2).toInt(), // 실제 크기의 2배로 고해상도 지원
                          memCacheWidth: (44 * 2).toInt(), // 실제 크기의 2배로 고해상도 지원
                          fit: BoxFit.cover,
                        )
                        : Container(
                          width: 44.w,
                          height: 44.w,
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
                        fontSize: 13,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.40,
                      ),
                    ),

                    Container(
                      alignment: Alignment.centerRight,
                      child: Text(
                        emoji.isEmpty ? '😊' : emoji,
                        style: TextStyle(fontSize: 25.sp),
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
                  color: const Color(0xFFC5C5C5),
                  fontSize: 10,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.40,
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
