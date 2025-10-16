import 'package:flutter/material.dart';
import 'package:soi/services/auth_service.dart';
import '../repositories/category_repository.dart';
import '../repositories/user_search_repository.dart';
import '../models/category_data_model.dart';
import '../models/auth_result.dart';
import 'notification_service.dart';
import 'category_invite_service.dart';

/// 카테고리 멤버 관리 Service
class CategoryMemberService {
  // Singleton pattern
  static final CategoryMemberService _instance =
      CategoryMemberService._internal();
  factory CategoryMemberService() => _instance;
  CategoryMemberService._internal();

  final CategoryRepository _repository = CategoryRepository();

  // Lazy initialization
  UserSearchRepository? _userSearchRepository;
  UserSearchRepository get userSearchRepository {
    _userSearchRepository ??= UserSearchRepository();
    return _userSearchRepository!;
  }

  NotificationService? _notificationService;
  NotificationService get notificationService {
    _notificationService ??= NotificationService();
    return _notificationService!;
  }

  CategoryInviteService? _inviteService;
  CategoryInviteService get inviteService {
    _inviteService ??= CategoryInviteService();
    return _inviteService!;
  }

  AuthService? _authService;
  AuthService get authService {
    _authService ??= AuthService();
    return _authService!;
  }

  /// 닉네임으로 사용자 추가
  Future<AuthResult> addUserByNickname({
    required String categoryId,
    required String nickName,
  }) async {
    try {
      final users = await userSearchRepository.searchUsersById(
        nickName,
        limit: 1,
      );
      if (users.isEmpty) {
        return AuthResult.failure('사용자를 찾을 수 없습니다.');
      }
      final recipientUid = users.first.uid;
      return await addUserByUid(categoryId: categoryId, uid: recipientUid);
    } catch (e) {
      return AuthResult.failure('카테고리에 사용자 추가 실패: $e');
    }
  }

  /// UID로 사용자 추가
  Future<AuthResult> addUserByUid({
    required String categoryId,
    required String uid,
  }) async {
    try {
      final currentUserId = authService.currentUser?.uid;
      if (currentUserId == null || currentUserId.isEmpty) {
        return AuthResult.failure('로그인이 필요합니다.');
      }

      if (currentUserId == uid) {
        return AuthResult.failure('자기 자신은 이미 카테고리 멤버입니다.');
      }

      final category = await _repository.getCategory(categoryId);
      if (category == null) {
        return AuthResult.failure('카테고리를 찾을 수 없습니다.');
      }

      if (category.mates.contains(uid)) {
        return AuthResult.failure('이미 카테고리 멤버입니다.');
      }

      final nonFriendMateIds = await inviteService.getPendingMateIds(
        category: category,
        invitedUserId: uid,
      );

      if (nonFriendMateIds.isNotEmpty) {
        final inviteId = await inviteService.createOrUpdateInvite(
          category: category,
          invitedUserId: uid,
          inviterUserId: currentUserId,
          blockedMateIds: nonFriendMateIds,
        );

        try {
          await notificationService.createCategoryInviteNotification(
            categoryId: categoryId,
            actorUserId: currentUserId,
            recipientUserIds: [uid],
            requiresAcceptance: true,
            categoryInviteId: inviteId,
            pendingMemberIds: nonFriendMateIds,
          );
        } catch (e) {
          debugPrint('⚠️ 카테고리 초대 알림 전송 실패: $e');
        }

        return AuthResult.success('초대를 보냈습니다. 상대방의 수락을 기다리고 있습니다.');
      }

      await _repository.addUidToCategory(categoryId: categoryId, uid: uid);

      try {
        await notificationService.createCategoryInviteNotification(
          categoryId: categoryId,
          actorUserId: currentUserId,
          recipientUserIds: [uid],
        );
      } catch (e) {
        debugPrint('카테고리 초대 알림 전송 실패: $e');
      }

      return AuthResult.success('카테고리에 추가되었습니다.');
    } catch (e) {
      debugPrint('addUserByUid 에러: $e');
      return AuthResult.failure('카테고리에 사용자 추가 실패: $e');
    }
  }

  /// 사용자 제거
  Future<AuthResult> removeUser({
    required String categoryId,
    required String uid,
  }) async {
    try {
      final category = await _repository.getCategory(categoryId);
      if (category == null) {
        return AuthResult.failure('카테고리를 찾을 수 없습니다.');
      }

      final updatedMates = List<String>.from(category.mates);
      if (!updatedMates.contains(uid)) {
        return AuthResult.failure('해당 사용자는 이 카테고리의 멤버가 아닙니다.');
      }

      updatedMates.remove(uid);

      if (updatedMates.isEmpty) {
        await _repository.deleteCategory(categoryId);
        return AuthResult.success('카테고리에서 나갔습니다. 마지막 멤버였으므로 카테고리가 삭제되었습니다.');
      }

      await _repository.updateCategory(categoryId, {'mates': updatedMates});
      return AuthResult.success('카테고리에서 나갔습니다.');
    } catch (e) {
      return AuthResult.failure('카테고리 나가기 중 오류가 발생했습니다.');
    }
  }

  /// 사용자가 카테고리 멤버인지 확인
  bool isUserMember(CategoryDataModel category, String userId) {
    return category.mates.contains(userId);
  }
}
