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
    CategoryDataModel category,
  ) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(const Offset(0, 0), ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF323232), // 피그마 배경색
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      elevation: 8.0,
      items: [
        _buildPopupMenuItem(
          value: 'edit_name',
          icon: Image.asset(
            'assets/category_edit.png',
            width: 10.0,
            height: 10.0,
          ),
          text: '이름 수정',
          textColor: Colors.white,
          iconColor: const Color(0xFFF9F9F9),
        ),
        const PopupMenuDivider(height: 0, color: Color(0xff5a5a5a)),
        _buildPopupMenuItem(
          value: category.isPinned ? 'unpin' : 'pin',
          icon: Image.asset('assets/pin.png', width: 10.0, height: 10.0),
          text: category.isPinned ? '고정 해제' : '고정',
          textColor: Colors.white,
          iconColor: const Color(0xFFF9F9F9),
        ),
        const PopupMenuDivider(height: 0, color: Color(0xff5a5a5a)),
        _buildPopupMenuItem(
          value: 'leave',
          icon: Image.asset(
            'assets/category_delete.png',
            width: 10.0,
            height: 10.0,
          ),
          text: '나가기',
          textColor: Colors.red,
          iconColor: Colors.red,
        ),
      ],
    ).then((String? result) {
      if (result != null) {
        _handlePopupMenuAction(context, result, category);
      }
    });
  }

  /// 🏗️ 커스텀 팝업 메뉴 아이템 생성
  static PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required Image icon,
    required String text,
    required Color textColor,
    required Color iconColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 48.0,
      child: Row(
        children: [
          icon,
          const SizedBox(width: 12.0),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 13.0,
              fontWeight: FontWeight.w400,
              fontFamily: 'Pretendard Variable',
            ),
          ),
        ],
      ),
    );
  }

  /// ⚡ 팝업 메뉴 액션 처리
  static void _handlePopupMenuAction(
    BuildContext context,
    String action,
    CategoryDataModel category,
  ) {
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
