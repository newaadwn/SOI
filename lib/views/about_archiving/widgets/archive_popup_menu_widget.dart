import 'package:flutter/material.dart';
import '../../../models/category_data_model.dart';
import 'archive_category_actions.dart';
import 'archive_category_dialogs.dart';

/// 🎯 아카이브 팝업 메뉴 위젯
/// 카테고리 카드의 더보기 메뉴를 담당합니다.
class ArchivePopupMenuWidget {
  /// 🎯 아카이브 팝업 메뉴 표시
  static void showArchivePopupMenu(
    BuildContext context,
    CategoryDataModel category, {
    Offset? buttonPosition,
  }) {
    // 버튼 위치 계산
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    Offset position = Offset.zero;

    if (renderBox != null) {
      position = renderBox.localToGlobal(Offset.zero);
    } else if (buttonPosition != null) {
      position = buttonPosition;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return _ArchivePopupMenuDialog(
          category: category,
          buttonPosition: position,
        );
      },
    );
  }
}

/// 📱 아카이브 팝업 메뉴 다이얼로그
/// 간단한 Container와 Card를 사용한 커스텀 팝업 메뉴
class _ArchivePopupMenuDialog extends StatelessWidget {
  final CategoryDataModel category;
  final Offset buttonPosition;

  const _ArchivePopupMenuDialog({
    required this.category,
    required this.buttonPosition,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 팝업 메뉴 크기
    const menuWidth = 151.0;
    const menuHeight = 104.0;

    // 팝업 위치 계산 (버튼 왼쪽 위에 표시)
    double left = buttonPosition.dx - menuWidth;
    double top = buttonPosition.dy - menuHeight;

    // 화면 경계 체크 및 조정
    if (left < 20) {
      left = buttonPosition.dx + 20; // 버튼 오른쪽에 표시
    }
    if (left + menuWidth > screenSize.width - 20) {
      left = screenSize.width - menuWidth - 20;
    }
    if (top < 50) {
      top = buttonPosition.dy + 20; // 버튼 아래쪽에 표시
    }

    return Stack(
      children: [
        // 투명한 배경 터치 시 닫기
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.transparent,
          ),
        ),
        // 팝업 메뉴 카드
        Positioned(
          left: left,
          top: top,
          child: Material(
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              width: 151,
              decoration: BoxDecoration(
                color: const Color(0xFF323232), // 피그마 배경색
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름 수정 버튼
                  _buildMenuButton(
                    context: context,
                    icon: 'assets/category_edit.png',
                    menuText: '이름 수정',
                    textColor: Colors.white,
                    onTap: () => _handleMenuAction(context, 'edit_name'),
                  ),
                  const PopupMenuDivider(height: 1, color: Color(0xff5a5a5a)),

                  // 고정/고정 해제 버튼
                  _buildMenuButton(
                    context: context,
                    icon: 'assets/pin.png',
                    menuText: category.isPinned ? '고정 해제' : '고정',
                    textColor: Colors.white,
                    onTap:
                        () => _handleMenuAction(
                          context,
                          category.isPinned ? 'unpin' : 'pin',
                        ),
                  ),
                  const PopupMenuDivider(height: 1, color: Color(0xff5a5a5a)),

                  // 나가기 버튼
                  _buildMenuButton(
                    context: context,
                    icon: 'assets/category_delete.png',
                    menuText: '나가기',
                    textColor: Colors.red,
                    onTap: () => _handleMenuAction(context, 'leave'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 🔧 메뉴 버튼 생성
  Widget _buildMenuButton({
    required BuildContext context,
    required String icon,
    required String menuText,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        width: 120, // 메뉴 너비
        height: 40, // 메뉴 높이
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            // 아이콘
            Image.asset(icon, width: 15.0, height: 15.0),
            const SizedBox(width: 12.0),
            // 텍스트
            Text(
              menuText,
              style: TextStyle(
                color: textColor,
                fontSize: 13.0,
                fontWeight: FontWeight.w400,
                fontFamily: 'Pretendard Variable',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚡ 메뉴 액션 처리
  void _handleMenuAction(BuildContext context, String action) {
    // 팝업 먼저 닫기
    Navigator.of(context).pop();

    // 액션 처리
    switch (action) {
      case 'edit_name':
        ArchiveCategoryDialogs.showEditNameDialog(
          context,
          category,
          onConfirm: (newName) {
            ArchiveCategoryActions.updateCategoryName(
              context,
              category,
              newName,
            );
          },
        );
        break;
      case 'pin':
      case 'unpin':
        ArchiveCategoryActions.handleTogglePinCategory(context, category);
        break;
      case 'leave':
        ArchiveCategoryDialogs.showLeaveCategoryDialog(
          context,
          category,
          onConfirm: () {
            ArchiveCategoryActions.leaveCategoryConfirmed(context, category);
          },
        );
        break;
    }
  }
}
