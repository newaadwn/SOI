import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 음성 녹음이 비활성화된 상태의 댓글 입력 필드 위젯
///
/// 마이크 아이콘과 텍스트 입력 필드를 표시합니다.
class VoiceCommentTextWidget extends StatefulWidget {
  final String photoId;
  final Function(String) onToggleVoiceComment;
  final Function(bool)? onFocusChanged; // 포커스 변경 콜백 추가

  const VoiceCommentTextWidget({
    super.key,
    required this.photoId,
    required this.onToggleVoiceComment,
    this.onFocusChanged,
  });

  @override
  State<VoiceCommentTextWidget> createState() => _VoiceCommentTextWidgetState();
}

class _VoiceCommentTextWidgetState extends State<VoiceCommentTextWidget> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 353,
      // 높이 자동 증가 (옵션 B)
      decoration: BoxDecoration(
        color: const Color(0xff161616),
        borderRadius: BorderRadius.circular(21.5),
        border: Border.all(color: const Color(0x66D9D9D9), width: 1),
      ),
      padding: EdgeInsets.only(left: 11.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 5),
            child: InkWell(
              onTap: () => widget.onToggleVoiceComment(widget.photoId),
              child: Image.asset('assets/mic_icon.png', width: 36, height: 36),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 11),
              child: TextField(
                focusNode: _focusNode, // FocusNode 연결
                onTapOutside: (event) {
                  FocusScope.of(context).unfocus();
                },
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.text,
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
          ),
          IconButton(
            onPressed: () {},
            icon: Image.asset('assets/send_icon.png', width: 17, height: 17),
          ),
        ],
      ),
    );
  }
}
