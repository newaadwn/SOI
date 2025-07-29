import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/category_controller.dart';
import '../../../models/category_data_model.dart';
import '../../../services/auth_service.dart';

/// ⚡ 아카이브 카테고리 액션 처리 클래스
/// 카테고리 관련 비즈니스 로직을 담당합니다.
class ArchiveCategoryActions {
  /// 📌 카테고리 고정/해제 토글
  static Future<void> handleTogglePinCategory(
    BuildContext context,
    CategoryDataModel category,
  ) async {
    try {
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      await categoryController.togglePinCategory(
        category.id,
        category.isPinned,
      );

      if (context.mounted) {
        final message =
            category.isPinned ? '카테고리 고정이 해제되었습니다.' : '카테고리가 상단에 고정되었습니다.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF323232),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('카테고리 고정 변경 실패: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카테고리 고정 변경에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 🔄 카테고리 이름 업데이트
  static Future<void> updateCategoryName(
    BuildContext context,
    CategoryDataModel category,
    String newName,
  ) async {
    try {
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      // 카테고리 이름 업데이트
      await categoryController.updateCategory(
        categoryId: category.id,
        name: newName,
      );

      // 성공 피드백
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카테고리 이름이 "$newName"으로 변경되었습니다.'),
            backgroundColor: const Color(0xFF323232),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('카테고리 이름 변경 실패: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카테고리 이름 변경에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 🚪 카테고리 나가기 실행
  static Future<void> leaveCategoryConfirmed(
    BuildContext context,
    CategoryDataModel category,
  ) async {
    try {
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      // AuthService에서 현재 사용자 UID 가져오기
      final authService = AuthService();
      final currentUserId = authService.getUserId;

      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사용자 정보를 찾을 수 없습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      await categoryController.leaveCategoryByUid(category.id, currentUserId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${category.name}" 카테고리에서 나갔습니다.'),
            backgroundColor: const Color(0xFF323232),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('카테고리 나가기 실패: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카테고리 나가기에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
