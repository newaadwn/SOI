import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:soi/controllers/auth_controller.dart';
import '../../../../models/category_data_model.dart';
import '../../components/archive_category_actions.dart';
import '../../components/archive_category_dialogs.dart';

/// 아카이브 팝업 메뉴 위젯
/// 카테고리 카드의 더보기 메뉴를 담당합니다.
class ArchivePopupMenuWidget extends StatefulWidget {
  final CategoryDataModel category;
  final VoidCallback? onEditName;
  final Widget child;

  const ArchivePopupMenuWidget({
    super.key,
    required this.category,
    required this.child,
    this.onEditName,
  });

  @override
  State<ArchivePopupMenuWidget> createState() => _ArchivePopupMenuWidgetState();
}

class _ArchivePopupMenuWidgetState extends State<ArchivePopupMenuWidget> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFF323232)),
        shadowColor: WidgetStateProperty.all(
          Colors.black.withValues(alpha: 0.3),
        ),
        elevation: WidgetStateProperty.all(8.0),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        maximumSize: WidgetStateProperty.all(Size(151.w, 115.h)),
        minimumSize: WidgetStateProperty.all(Size(151.w, 115.h)),
      ),
      menuChildren: _buildMenuItems(),
      child: GestureDetector(
        onTap: () {
          if (_menuController.isOpen) {
            _menuController.close();
          } else {
            _menuController.open();
          }
        },
        child: widget.child,
      ),
    );
  }

  /// 🔧 메뉴 아이템들 생성
  List<Widget> _buildMenuItems() {
    final authController = AuthController();
    final userId = authController.getUserId;
    final isPinnedForCurrentUser =
        userId != null ? widget.category.isPinnedForUser(userId) : false;

    return [
      // 이름 수정 메뉴
      _buildCustomMenuItem(
        icon: 'assets/category_edit.png',
        text: '이름 수정',
        textColor: Colors.white,
        onPressed: () => _handleMenuAction('edit_name'),
      ),

      // 구분선
      Divider(color: const Color(0xff5a5a5a), height: 1.h),

      // 고정/고정 해제 메뉴
      _buildCustomMenuItem(
        icon: 'assets/pin.png',
        text: isPinnedForCurrentUser ? '고정 해제' : '고정',
        textColor: Colors.white,
        onPressed:
            () => _handleMenuAction(isPinnedForCurrentUser ? 'unpin' : 'pin'),
      ),

      // 구분선
      Divider(color: const Color(0xff5a5a5a), height: 1.h),

      // 나가기 메뉴
      _buildCustomMenuItem(
        icon: 'assets/category_delete.png',
        text: '나가기',
        textColor: Color(0xFFFF0000),
        onPressed: () => _handleMenuAction('leave'),
      ),
    ];
  }

  /// 커스텀 메뉴 아이템 생성
  Widget _buildCustomMenuItem({
    required String icon,
    required String text,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 151.w,
        height: (36.1).h,
        padding: EdgeInsets.only(left: 10.w),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(0),
        ),
        child: Row(
          children: [
            // 아이콘
            Image.asset(icon, width: 10.w, height: 10.h),
            SizedBox(width: 10.w),
            // 텍스트
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: (13.4).sp,
                fontWeight: FontWeight.w400,
                fontFamily: 'Pretendard Variable',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 메뉴 액션 처리
  void _handleMenuAction(String action) {
    // 메뉴 먼저 닫기
    _menuController.close();

    // 액션 처리
    switch (action) {
      case 'edit_name':
        if (widget.onEditName != null) {
          widget.onEditName!();
        }
        break;
      case 'pin':
      case 'unpin':
        ArchiveCategoryActions.handleTogglePinCategory(
          context,
          widget.category,
        );
        break;
      case 'leave':
        ArchiveCategoryDialogs.showLeaveCategoryDialog(
          context,
          widget.category,
          onConfirm: () {
            ArchiveCategoryActions.leaveCategoryConfirmed(
              context,
              widget.category,
            );
          },
        );
        break;
    }
  }
}
