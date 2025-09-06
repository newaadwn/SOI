import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../models/emoji_reaction_model.dart';

/// 이모티콘 선택 오버레이 위젯
/// like_icon을 탭했을 때 나타나는 이모티콘 선택 UI
class EmojiPickerOverlay extends StatefulWidget {
  final GlobalKey buttonKey;
  final Function(EmojiReactionModel) onEmojiSelected;
  final VoidCallback onDismiss;
  final bool horizontalExpand; // 옆으로 펼치기 여부

  const EmojiPickerOverlay({
    super.key,
    required this.buttonKey,
    required this.onEmojiSelected,
    required this.onDismiss,
    this.horizontalExpand = true,
  });

  @override
  State<EmojiPickerOverlay> createState() => _EmojiPickerOverlayState();
}

class _EmojiPickerOverlayState extends State<EmojiPickerOverlay>
    with TickerProviderStateMixin {
  late AnimationController _appearController; // 전체 등장 (배경/컨테이너)
  late Animation<double> _bgFade;
  // 각 이모티콘 개별 애니메이션 (stagger)
  final List<Animation<double>> _itemScales = [];
  final List<Animation<double>> _itemOpacities = [];
  final List<Animation<Offset>> _itemOffsets = [];

  int? _hoveredIndex;

  static const _itemSize = 44.0; // 각 이모티콘 영역 (정사각)
  static const _spacing = 6.0; // 이모티콘 사이 간격
  static const _horizontalPadding = 10.0;
  static const _verticalPadding = 8.0;

  @override
  void initState() {
    super.initState();

    final count = EmojiConstants.availableEmojis.length;

    _appearController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _bgFade = CurvedAnimation(
      parent: _appearController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );

    for (int i = 0; i < count; i++) {
      final start = 0.15 + i * 0.08;
      final end = start + 0.35;
      _itemScales.add(
        Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(
            parent: _appearController,
            curve: Interval(
              start,
              end.clamp(0.0, 1.0),
              curve: Curves.easeOutBack,
            ),
          ),
        ),
      );
      _itemOpacities.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _appearController,
            curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
          ),
        ),
      );
      _itemOffsets.add(
        Tween<Offset>(begin: const Offset(0.15, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _appearController,
            curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
          ),
        ),
      );
    }

    _appearController.forward();
  }

  @override
  void dispose() {
    _appearController.dispose();
    super.dispose();
  }

  /// 버튼 위치와 화면 폭을 기준으로 수평 오버레이 위치 계산
  _OverlayPosition _calcHorizontalPosition() {
    final RenderBox? btnBox =
        widget.buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (btnBox == null) return _OverlayPosition.zero();
    final buttonPos = btnBox.localToGlobal(Offset.zero);
    final buttonSize = btnBox.size;
    final screenWidth = MediaQuery.of(context).size.width;

    final count = EmojiConstants.availableEmojis.length;
    final contentWidth =
        _horizontalPadding * 2 + count * _itemSize + (count - 1) * _spacing;
    final height = _verticalPadding * 2 + _itemSize;

    // 기본은 오른쪽으로 펼침
    double left = buttonPos.dx + buttonSize.width + 8;
    bool toRight = true;
    if (left + contentWidth > screenWidth - 4) {
      // 오른쪽 공간 부족 -> 왼쪽으로 펼침
      left = buttonPos.dx - contentWidth - 8;
      toRight = false;
    }
    final top = buttonPos.dy + (buttonSize.height / 2) - height / 2;
    return _OverlayPosition(
      left: left,
      top: top,
      width: contentWidth,
      height: height,
      expandToRight: toRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.horizontalExpand) {
      // fallback: 기존 위쪽 표시 로직 (필요시 확장 가능)
    }
    final pos = _calcHorizontalPosition();

    return Positioned(
      left: pos.left,
      top: pos.top,

      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _appearController,
          builder: (context, child) {
            return Opacity(
              opacity: _bgFade.value,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(32.r),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: _horizontalPadding.w,
                  vertical: _verticalPadding.h,
                ),
                child: Row(
                  children:
                      List.generate(EmojiConstants.availableEmojis.length, (
                        index,
                      ) {
                        final emoji = EmojiConstants.availableEmojis[index];
                        return Transform.translate(
                          offset: _itemOffsets[index].value * 30,
                          child: Opacity(
                            opacity: _itemOpacities[index].value,
                            child: Transform.scale(
                              scale: _itemScales[index].value,
                              child: _EmojiButton(
                                emoji: emoji,
                                isHovered: _hoveredIndex == index,
                                onTap: () {
                                  widget.onEmojiSelected(emoji);
                                  _dismiss();
                                },
                                onHoverStart: () {
                                  setState(() => _hoveredIndex = index);
                                },
                                onHoverEnd: () {
                                  setState(() => _hoveredIndex = null);
                                },
                              ),
                            ),
                          ),
                        );
                      }).expand((w) sync* {
                        yield w;
                        if (w != (EmojiConstants.availableEmojis.length - 1)) {
                          // spacing 위젯
                          yield SizedBox(width: _spacing.w);
                        }
                      }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _dismiss() async {
    await _appearController.reverse();
    widget.onDismiss();
  }
}

class _OverlayPosition {
  final double left;
  final double top;
  final double width;
  final double height;
  final bool expandToRight;
  _OverlayPosition({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.expandToRight,
  });
  factory _OverlayPosition.zero() => _OverlayPosition(
    left: 0,
    top: 0,
    width: 0,
    height: 0,
    expandToRight: true,
  );
}

/// 개별 이모티콘 버튼 위젯
class _EmojiButton extends StatefulWidget {
  final EmojiReactionModel emoji;
  final bool isHovered;
  final VoidCallback onTap;
  final VoidCallback onHoverStart;
  final VoidCallback onHoverEnd;

  const _EmojiButton({
    required this.emoji,
    required this.isHovered,
    required this.onTap,
    required this.onHoverStart,
    required this.onHoverEnd,
  });

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3, // 1.3배 크기로 확대
    ).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_EmojiButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // hover 상태 변화에 따른 애니메이션
    if (widget.isHovered && !oldWidget.isHovered) {
      _hoverController.forward();
    } else if (!widget.isHovered && oldWidget.isHovered) {
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => widget.onHoverStart(),
      onTapUp: (_) => widget.onHoverEnd(),
      onTapCancel: () => widget.onHoverEnd(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 45.w,
              height: 45.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    widget.isHovered
                        ? const Color(0xFF404040)
                        : Colors.transparent,
              ),
              child: Center(
                child: Text(
                  widget.emoji.emoji,
                  style: TextStyle(fontSize: 28.sp),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
