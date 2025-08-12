import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../models/category_data_model.dart';
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
    VoidCallback? onEditName,
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
          onEditName: onEditName,
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
  final VoidCallback? onEditName;

  const _ArchivePopupMenuDialog({
    required this.category,
    required this.buttonPosition,
    this.onEditName,
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
              width: 151.w,
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
                  PopupMenuDivider(height: 1.h, color: Color(0xff5a5a5a)),

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
                  PopupMenuDivider(height: 1.h, color: Color(0xff5a5a5a)),

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
        width: 120.w,
        height: 40.h,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            // 아이콘
            Image.asset(icon, width: 15.w, height: 15.h),
            SizedBox(width: 12.w),
            // 텍스트
            Text(
              menuText,
              style: TextStyle(
                color: textColor,
                fontSize: 13.sp,
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
    // 부모 context 참조 저장 (팝업이 닫히기 전에)
    final parentContext = Navigator.of(context, rootNavigator: true).context;

    // 팝업 먼저 닫기
    Navigator.of(context).pop();

    // 안전한 부모 context로 액션 처리
    switch (action) {
      case 'edit_name':
        onEditName!();

        break;
      case 'pin':
      case 'unpin':
        ArchiveCategoryActions.handleTogglePinCategory(parentContext, category);
        break;
      case 'leave':
        ArchiveCategoryDialogs.showLeaveCategoryDialog(
          parentContext,
          category,
          onConfirm: () {
            ArchiveCategoryActions.leaveCategoryConfirmed(
              parentContext,
              category,
            );
          },
        );
        break;
    }
  }
}
