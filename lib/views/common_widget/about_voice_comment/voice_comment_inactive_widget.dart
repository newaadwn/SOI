import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 음성 녹음이 비활성화된 상태의 댓글 입력 필드 위젯
///
/// 마이크 아이콘과 텍스트 입력 필드를 표시합니다.
class VoiceCommentInactiveWidget extends StatelessWidget {
  final String photoId;
  final Function(String) onToggleVoiceComment;

  const VoiceCommentInactiveWidget({
    super.key,
    required this.photoId,
    required this.onToggleVoiceComment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 353,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xff161616),
        borderRadius: BorderRadius.circular(21.5),
        border: Border.all(
          color: const Color(0x66D9D9D9),
          width: 1,
        ),
      ),
      padding: EdgeInsets.only(left: 11.w),
      child: Row(
        children: [
          SizedBox(
            child: InkWell(
              onTap: () => onToggleVoiceComment(photoId),
              child: Center(
                child: Image.asset(
                  'assets/mic_icon.png',
                  width: 36,
                  height: 36,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              maxLines: null,
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: '댓글 추가 ....',
                hintStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w200,
                  letterSpacing: -1.14,
                ),
              ),
              cursorColor: Colors.white,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w200,
                letterSpacing: -1.14,
              ),
              textAlignVertical: TextAlignVertical.center,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Image.asset(
              'assets/send_icon.png',
              width: 17,
              height: 17,
            ),
          ),
        ],
      ),
    );
  }
}
