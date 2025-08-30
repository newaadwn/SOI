import 'package:flutter/material.dart';
import '../../../models/emoji_reaction_model.dart';
import '../emoji_picker_overlay.dart';

/// 이모티콘 오버레이를 표시하는 유틸리티 클래스
class EmojiOverlayManager {
  static OverlayEntry? _currentOverlay;

  /// 이모티콘 오버레이 표시
  static void showEmojiPicker({
    required BuildContext context,
    required GlobalKey buttonKey,
    required Function(EmojiReactionModel) onEmojiSelected,
  }) {
    // 기존 오버레이가 있다면 제거
    dismissEmojiPicker();

    final overlay = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              // 배경 터치 시 닫기
              Positioned.fill(
                child: GestureDetector(
                  onTap: dismissEmojiPicker,
                  child: Container(color: Colors.transparent),
                ),
              ),
              // 이모티콘 오버레이
              EmojiPickerOverlay(
                buttonKey: buttonKey,
                onEmojiSelected: (emoji) {
                  onEmojiSelected(emoji);
                  dismissEmojiPicker();
                },
                onDismiss: dismissEmojiPicker,
              ),
            ],
          ),
    );

    overlay.insert(_currentOverlay!);
  }

  /// 이모티콘 오버레이 제거
  static void dismissEmojiPicker() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}
