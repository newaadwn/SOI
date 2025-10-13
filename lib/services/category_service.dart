import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:soi/services/auth_service.dart';
import '../repositories/category_repository.dart';
import '../repositories/category_invite_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';
import '../models/category_data_model.dart';
import '../models/category_invite_model.dart';
import '../models/auth_result.dart';
import 'notification_service.dart';
import 'photo_service.dart';
import 'friend_service.dart';

/// 비즈니스 로직을 처리하는 Service
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class CategoryService {
  // Singleton pattern
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final CategoryRepository _repository = CategoryRepository();

  // Lazy initialization으로 순환 의존성 방지
  NotificationService? _notificationService;
  NotificationService get notificationService {
    _notificationService ??= NotificationService();
    return _notificationService!;
  }

  PhotoService? _photoService;
  PhotoService get photoService {
    _photoService ??= PhotoService();
    return _photoService!;
  }

  UserSearchRepository? _userSearchRepository;
  UserSearchRepository get userSearchRepository {
    _userSearchRepository ??= UserSearchRepository();
    return _userSearchRepository!;
  }

  // FriendService 의존성 추가
  FriendService? _friendService;
  FriendService get friendService {
    _friendService ??= FriendService(
      friendRepository: FriendRepository(),
      userSearchRepository: UserSearchRepository(),
    );
    return _friendService!;
  }

  CategoryInviteRepository? _categoryInviteRepository;
  CategoryInviteRepository get categoryInviteRepository {
    _categoryInviteRepository ??= CategoryInviteRepository();
    return _categoryInviteRepository!;
  }

  AuthService? _authService;
  AuthService get authService {
    _authService ??= AuthService();
    return _authService!;
  }

  // ==================== 비즈니스 로직 ====================

  /// 카테고리 이름 검증
  String? _validateCategoryName(String name) {
    if (name.trim().isEmpty) {
      return '카테고리 이름을 입력해주세요.';
    }

    if (name.trim().length > 20) {
      return '카테고리 이름은 20글자 이하여야 합니다.';
    }
    return null;
  }

  /// 카테고리 이름 정규화
  String _normalizeCategoryName(String name) {
    return name.trim();
  }

  // ==================== 카테고리 관리 ====================

  /// 사용자의 카테고리 목록을 스트림으로 가져오기
  Stream<List<CategoryDataModel>> getUserCategoriesStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    // 차단된 사용자가 있는 카테고리를 필터링한 스트림 반환
    return _repository.getUserCategoriesStream(userId).asyncMap((
      categories,
    ) async {
      return await _filterCategoriesWithBlockedUsers(categories);
    });
  }

  /// 단일 카테고리 실시간 스트림
  Stream<CategoryDataModel?> getCategoryStream(String categoryId) {
    if (categoryId.isEmpty) {
      return Stream.value(null);
    }
    return _repository.getCategoryStream(categoryId);
  }

  /// 사용자의 카테고리 목록을 한 번만 가져오기 (차단된 사용자 필터링 포함)
  Future<List<CategoryDataModel>> getUserCategories(String userId) async {
    if (userId.isEmpty) {
      // // debugPrint('CategoryService: userId가 비어있습니다.');
      return [];
    }

    try {
      final categories = await _repository.getUserCategories(userId);

      // 차단된 사용자가 있는 카테고리 필터링
      return await _filterCategoriesWithBlockedUsers(categories);
    } catch (e) {
      // // debugPrint('카테고리 목록 조회 오류: $e');
      return [];
    }
  }

  /// 카테고리 생성
  Future<AuthResult> createCategory({
    required String name,
    required List<String> mates,
  }) async {
    try {
      debugPrint('🎯 카테고리 생성 시도: $name, 멤버: ${mates.length}명');

      // 1. 카테고리 이름 검증
      final validationError = _validateCategoryName(name);
      if (validationError != null) {
        return AuthResult.failure(validationError);
      }

      // 2. 메이트 검증
      if (mates.isEmpty) {
        return AuthResult.failure('최소 1명의 멤버가 필요합니다.');
      }

      // 3. 현재 사용자 확인 (카테고리 생성자)
      final currentUserId = authService.currentUser?.uid;
      if (currentUserId == null || currentUserId.isEmpty) {
        return AuthResult.failure('로그인이 필요합니다.');
      }

      // 4. 생성자는 mates에 포함되어야 함
      if (!mates.contains(currentUserId)) {
        return AuthResult.failure('카테고리 생성자가 멤버에 포함되어야 합니다.');
      }

      // 5. 카테고리 이름 정규화
      final normalizedName = _normalizeCategoryName(name);

      // 6. 친구 관계 확인: 생성자와 모든 다른 멤버가 친구인지 확인
      final otherMates = mates.where((m) => m != currentUserId).toList();
      debugPrint(
        '🔍 친구 관계 확인 시작: 생성자($currentUserId)와 멤버 ${otherMates.length}명',
      );

      final nonFriendMates = <String>[];

      for (final mateId in otherMates) {
        debugPrint('  확인 중: $currentUserId ←→ $mateId');
        final isFriend = await friendService.areUsersMutualFriends(
          currentUserId,
          mateId,
        );
        debugPrint('  결과: ${isFriend ? "✅ 친구" : "❌ 친구 아님"}');
        if (!isFriend) {
          nonFriendMates.add(mateId);
        }
      }

      // 7. 친구가 아닌 멤버가 있으면 생성 불가
      if (nonFriendMates.isNotEmpty) {
        debugPrint('❌ 카테고리 생성 불가: 친구가 아닌 멤버 ${nonFriendMates.length}명');
        debugPrint('❌ 친구가 아닌 멤버 목록: $nonFriendMates');
        return AuthResult.failure('카테고리는 친구들과만 만들 수 있습니다. 먼저 친구를 추가해주세요.');
      }

      // 8. 모두 친구인 경우 카테고리 생성
      debugPrint('✅ 모든 멤버가 친구 관계 - 카테고리 생성 진행');
      final category = CategoryDataModel(
        id: '', // Repository에서 생성됨
        name: normalizedName,
        mates: mates,
        createdAt: DateTime.now(),
      );

      final categoryId = await _repository.createCategory(category);
      debugPrint('✅ 카테고리 생성 완료: $categoryId');

      // 9. 카테고리 초대 알림 생성
      try {
        await notificationService.createCategoryInviteNotification(
          categoryId: categoryId,
          actorUserId: currentUserId,
          recipientUserIds: otherMates, // 생성자 제외한 멤버들에게만 알림
        );
        debugPrint('🔔 카테고리 초대 알림 생성 완료');
      } catch (e) {
        // 알림 생성 실패는 전체 카테고리 생성을 실패시키지 않음
        debugPrint('⚠️ 알림 생성 실패 (카테고리 생성은 성공): $e');
      }

      return AuthResult.success(categoryId);
    } catch (e) {
      debugPrint('💥 카테고리 생성 실패: $e');
      return AuthResult.failure('카테고리 생성 중 오류가 발생했습니다.');
    }
  }

  /// 사용자별 카테고리 커스텀 이름 업데이트
  Future<AuthResult> updateCustomCategoryName({
    required String categoryId,
    required String userId,
    required String customName,
  }) async {
    try {
      // 1. 카테고리 이름 검증
      final validationError = _validateCategoryName(customName);
      if (validationError != null) {
        return AuthResult.failure(validationError);
      }

      // 2. 카테고리 이름 정규화
      final normalizedName = _normalizeCategoryName(customName);

      // 3. customNames 맵 업데이트
      await _repository.updateCustomName(
        categoryId: categoryId,
        userId: userId,
        customName: normalizedName,
      );

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('커스텀 이름 설정 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 수정
  Future<AuthResult> updateCategory({
    required String categoryId,
    String? name,
    List<String>? mates,
    bool? isPinned,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      // 1. 이름 업데이트
      if (name != null) {
        final validationError = _validateCategoryName(name);
        if (validationError != null) {
          return AuthResult.failure(validationError);
        }
        updateData['name'] = _normalizeCategoryName(name);
      }

      // 2. 멤버 업데이트
      if (mates != null) {
        if (mates.isEmpty) {
          return AuthResult.failure('최소 1명의 멤버가 필요합니다.');
        }
        updateData['mates'] = mates;
      }

      // 3. 고정 상태 업데이트
      if (isPinned != null) {
        updateData['isPinned'] = isPinned;
      }

      if (updateData.isEmpty) {
        return AuthResult.failure('업데이트할 내용이 없습니다.');
      }

      await _repository.updateCategory(categoryId, updateData);
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('카테고리 수정 중 오류가 발생했습니다.');
    }
  }

  /// 사용자별 카테고리 고정 상태 업데이트
  Future<AuthResult> updateUserPinStatus({
    required String categoryId,
    required String userId,
    required bool isPinned,
  }) async {
    try {
      if (categoryId.isEmpty || userId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리 또는 사용자입니다.');
      }

      await _repository.updateUserPinStatus(
        categoryId: categoryId,
        userId: userId,
        isPinned: isPinned,
      );

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('고정 상태 업데이트 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 삭제
  Future<AuthResult> deleteCategory(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      await _repository.deleteCategory(categoryId);
      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('카테고리 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 특정 카테고리 정보 가져오기
  Future<CategoryDataModel?> getCategory(String categoryId) async {
    try {
      if (categoryId.isEmpty) return null;

      return await _repository.getCategory(categoryId);
    } catch (e) {
      return null;
    }
  }

  // ==================== 사진 관리 ====================

  /// 카테고리에 사진 추가
  Future<AuthResult> addPhotoToCategory({
    required String categoryId,
    required File imageFile,
    String? description,
  }) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      // 1. 이미지 업로드
      final imageUrl = await _repository.uploadImage(categoryId, imageFile);

      // 2. 사진 데이터 생성
      final photoData = {
        'url': imageUrl,
        'description': description ?? '',
        'createdAt': DateTime.now(),
      };

      // 3. Firestore에 사진 정보 저장
      final photoId = await _repository.addPhotoToCategory(
        categoryId,
        photoData,
      );

      return AuthResult.success(photoId);
    } catch (e) {
      return AuthResult.failure('사진 추가 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리에서 사진 삭제
  Future<AuthResult> removePhotoFromCategory({
    required String categoryId,
    required String photoId,
    required String imageUrl,
  }) async {
    try {
      if (categoryId.isEmpty || photoId.isEmpty) {
        return AuthResult.failure('유효하지 않은 정보입니다.');
      }

      // 1. Storage에서 이미지 삭제
      await _repository.deleteImage(imageUrl);

      // 2. Firestore에서 사진 정보 삭제
      await _repository.removePhotoFromCategory(categoryId, photoId);

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('사진 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리의 사진들 가져오기 (차단된 사용자 필터링 포함)
  Future<List<Map<String, dynamic>>> getCategoryPhotos(
    String categoryId,
  ) async {
    try {
      if (categoryId.isEmpty) return [];

      // 1. 모든 카테고리 사진 조회
      final allPhotos = await _repository.getCategoryPhotos(categoryId);

      // 2. 내가 차단한 사용자 목록만 조회 (단방향 필터링)
      final blockedByMe = await friendService.getBlockedUsers();

      // 3. 내가 차단한 사용자들의 사진만 필터링
      final filteredPhotos =
          allPhotos.where((photo) {
            final photoUserId = photo['userId'] as String?;
            return photoUserId == null || !blockedByMe.contains(photoUserId);
          }).toList();

      return filteredPhotos;
    } catch (e) {
      debugPrint('getCategoryPhotos 에러: $e');
      return [];
    }
  }

  // ==================== 기존 호환성 메서드 ====================

  // ==================== 표지사진 관리 ====================

  /// 갤러리에서 선택한 이미지로 표지사진 업데이트
  Future<AuthResult> updateCoverPhotoFromGallery({
    required String categoryId,
    required File imageFile,
  }) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      // 이미지 업로드
      final photoUrl = await _repository.uploadCoverImage(
        categoryId,
        imageFile,
      );

      // 카테고리 표지사진 업데이트
      await _repository.updateCategoryPhoto(
        categoryId: categoryId,
        photoUrl: photoUrl,
      );

      // 관련 알림들의 썸네일 업데이트
      try {
        await notificationService.updateCategoryThumbnailInNotifications(
          categoryId: categoryId,
          newThumbnailUrl: photoUrl,
        );
      } catch (e) {
        debugPrint('⚠️ 알림 썸네일 업데이트 실패 (표지사진은 성공적으로 업데이트됨): $e');
        // 표지사진 업데이트는 성공했으므로 계속 진행
      }

      return AuthResult.success(photoUrl);
    } catch (e) {
      return AuthResult.failure('표지사진 업데이트 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 내 사진으로 표지사진 업데이트
  Future<AuthResult> updateCoverPhotoFromCategory({
    required String categoryId,
    required String photoUrl,
  }) async {
    try {
      if (categoryId.isEmpty || photoUrl.isEmpty) {
        return AuthResult.failure('유효하지 않은 정보입니다.');
      }

      await _repository.updateCategoryPhoto(
        categoryId: categoryId,
        photoUrl: photoUrl,
      );

      // 관련 알림들의 썸네일 업데이트
      try {
        await notificationService.updateCategoryThumbnailInNotifications(
          categoryId: categoryId,
          newThumbnailUrl: photoUrl,
        );
      } catch (e) {
        debugPrint('⚠️ 알림 썸네일 업데이트 실패 (표지사진은 성공적으로 업데이트됨): $e');
        // 표지사진 업데이트는 성공했으므로 계속 진행
      }

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('표지사진 업데이트 중 오류가 발생했습니다.');
    }
  }

  /// 표지사진 삭제
  Future<AuthResult> deleteCoverPhoto(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        return AuthResult.failure('유효하지 않은 카테고리입니다.');
      }

      await _repository.deleteCategoryPhoto(categoryId);

      // 관련 알림들의 썸네일을 null로 업데이트 (기본 아이콘 표시)
      try {
        await notificationService.updateCategoryThumbnailInNotifications(
          categoryId: categoryId,
          newThumbnailUrl: '', // 빈 문자열로 설정하여 기본 아이콘 표시
        );
      } catch (e) {
        debugPrint('⚠️ 알림 썸네일 업데이트 실패 (표지사진 삭제는 성공적으로 완료됨): $e');
        // 표지사진 삭제는 성공했으므로 계속 진행
      }

      return AuthResult.success();
    } catch (e) {
      return AuthResult.failure('표지사진 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리 사진 스트림 (차단된 사용자 필터링 포함)
  Stream<List<Map<String, dynamic>>> getCategoryPhotosStream(
    String categoryId,
  ) {
    return _repository.getCategoryPhotosStream(categoryId).asyncMap((
      photos,
    ) async {
      // 내가 차단한 사용자 목록만 조회 (단방향 필터링)
      final blockedByMe = await friendService.getBlockedUsers();

      // 내가 차단한 사용자들의 사진만 필터링
      return photos.where((photo) {
        final photoUserId = photo['userId'] as String?;
        return photoUserId == null || !blockedByMe.contains(photoUserId);
      }).toList();
    });
  }

  // ==================== 유틸리티 ====================

  /// 사용자가 카테고리의 멤버인지 확인
  bool isUserMemberOfCategory(CategoryDataModel category, String userId) {
    return category.mates.contains(userId);
  }

  Future<List<String>> _getPendingMateIds({
    required CategoryDataModel category,
    required String invitedUserId,
    required String inviterUserId,
  }) async {
    if (category.mates.isEmpty) {
      debugPrint('📋 카테고리에 멤버가 없음');
      return [];
    }

    // 초대자와 초대 대상자를 제외한 기존 멤버 목록
    final otherMateIds =
        category.mates
            .where(
              (mateId) => mateId != inviterUserId && mateId != invitedUserId,
            )
            .toSet();

    if (otherMateIds.isEmpty) {
      debugPrint('📋 초대자 외 다른 멤버가 없음');
      return [];
    }

    debugPrint('🔍 기존 멤버와의 친구 관계 확인 중: ${otherMateIds.length}명');

    // 각 멤버와의 친구 관계 확인
    final results = await Future.wait(
      otherMateIds.map((mateId) async {
        final isFriend = await friendService.areUsersMutualFriends(
          invitedUserId,
          mateId,
        );
        debugPrint('  - $mateId: ${isFriend ? "친구" : "친구 아님"}');
        return isFriend ? null : mateId;
      }),
    );

    final nonFriendIds = results.whereType<String>().toList();

    if (nonFriendIds.isNotEmpty) {
      debugPrint('❌ 친구가 아닌 멤버: ${nonFriendIds.length}명');
      return nonFriendIds;
    }

    debugPrint('✅ 모든 멤버와 친구 관계');
    return [];
  }

  Future<String> _createOrUpdateCategoryInvite({
    required CategoryDataModel category,
    required String invitedUserId,
    required String inviterUserId,
    required List<String> blockedMateIds,
  }) async {
    final existingInvite = await categoryInviteRepository
        .getPendingInviteForCategory(
          categoryId: category.id,
          invitedUserId: invitedUserId,
        );

    if (existingInvite != null) {
      final updatedBlockedMates =
          {...existingInvite.blockedMateIds, ...blockedMateIds}.toList();

      await categoryInviteRepository.updateInvite(existingInvite.id, {
        'blockedMateIds': updatedBlockedMates,
        'status': CategoryInviteStatus.pending.name,
      });

      return existingInvite.id;
    }

    final now = DateTime.now();
    final invite = CategoryInviteModel(
      id: '',
      categoryId: category.id,
      invitedUserId: invitedUserId,
      inviterUserId: inviterUserId,
      status: CategoryInviteStatus.pending,
      blockedMateIds: blockedMateIds,
      createdAt: now,
      updatedAt: now,
    );

    return await categoryInviteRepository.createInvite(invite);
  }

  Future<AuthResult> acceptPendingInvite({
    required String inviteId,
    required String userId,
  }) async {
    try {
      debugPrint('🎯 카테고리 초대 수락 시도: $inviteId by $userId');

      if (inviteId.isEmpty || userId.isEmpty) {
        return AuthResult.failure('유효하지 않은 초대입니다.');
      }

      // 1. 초대 정보 조회
      final invite = await categoryInviteRepository.getInvite(inviteId);
      if (invite == null) {
        return AuthResult.failure('초대를 찾을 수 없습니다.');
      }

      // 2. 초대 대상자 확인
      if (invite.invitedUserId != userId) {
        return AuthResult.failure('이 초대를 수락할 수 없습니다.');
      }

      // 3. 초대 상태 확인
      if (invite.status == CategoryInviteStatus.accepted) {
        debugPrint('✅ 이미 수락된 초대');
        return AuthResult.success(invite.categoryId);
      }

      if (invite.status == CategoryInviteStatus.declined || invite.isExpired) {
        return AuthResult.failure('만료되었거나 거절된 초대입니다.');
      }

      // 4. 카테고리 존재 확인
      final category = await _repository.getCategory(invite.categoryId);
      if (category == null) {
        return AuthResult.failure('카테고리를 찾을 수 없습니다.');
      }

      // 5. 이미 멤버인지 확인
      if (category.mates.contains(userId)) {
        debugPrint('✅ 이미 카테고리 멤버임');
        await categoryInviteRepository.deleteInvite(invite.id);
        return AuthResult.success(invite.categoryId);
      }

      // 6. blockedMateIds에 있는 멤버들과 실제로 친구 관계인지 재확인
      if (invite.blockedMateIds.isNotEmpty) {
        debugPrint('🔍 친구가 아닌 멤버 확인 중: ${invite.blockedMateIds.length}명');

        final stillNotFriends = <String>[];
        for (final mateId in invite.blockedMateIds) {
          final isFriend = await friendService.areUsersMutualFriends(
            userId,
            mateId,
          );
          if (!isFriend) {
            stillNotFriends.add(mateId);
          }
        }

        if (stillNotFriends.isNotEmpty) {
          debugPrint('❌ 여전히 친구가 아닌 멤버: ${stillNotFriends.length}명');
          return AuthResult.failure('카테고리에 친구가 아닌 멤버가 있습니다. 먼저 친구 추가가 필요합니다.');
        }
      }

      // 7. 모든 검증 통과 - 카테고리에 추가
      debugPrint('✅ 모든 검증 통과 - 카테고리에 추가');
      await _repository.addUidToCategory(
        categoryId: invite.categoryId,
        uid: userId,
      );

      // 8. 초대 상태 업데이트 및 삭제
      await categoryInviteRepository.updateInviteStatus(
        invite.id,
        CategoryInviteStatus.accepted,
        respondedAt: DateTime.now(),
      );

      await categoryInviteRepository.deleteInvite(invite.id);

      debugPrint('✅ 카테고리 초대 수락 완료');
      return AuthResult.success(invite.categoryId);
    } catch (e) {
      debugPrint('💥 카테고리 초대 수락 실패: $e');
      return AuthResult.failure('초대 수락 중 오류가 발생했습니다.');
    }
  }

  Future<AuthResult> declinePendingInvite({
    required String inviteId,
    required String userId,
  }) async {
    try {
      if (inviteId.isEmpty || userId.isEmpty) {
        return AuthResult.failure('유효하지 않은 초대입니다.');
      }

      final invite = await categoryInviteRepository.getInvite(inviteId);
      if (invite == null) {
        return AuthResult.failure('초대를 찾을 수 없습니다.');
      }

      if (invite.invitedUserId != userId) {
        return AuthResult.failure('이 초대를 거절할 수 없습니다.');
      }

      await categoryInviteRepository.updateInviteStatus(
        invite.id,
        CategoryInviteStatus.declined,
        respondedAt: DateTime.now(),
      );

      await categoryInviteRepository.deleteInvite(invite.id);

      return AuthResult.success();
    } catch (e) {
      debugPrint('카테고리 초대 거절 실패: $e');
      return AuthResult.failure('초대 거절 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리에 사용자 추가 (닉네임으로) - 기존 방식 유지하되 검증 추가
  Future<AuthResult> addUserToCategory({
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
      return await addUidToCategory(categoryId: categoryId, uid: recipientUid);
    } catch (e) {
      return AuthResult.failure('카테고리에 사용자 추가 실패: $e');
    }
  }

  /// 카테고리에 사용자 추가 (UID로)
  Future<AuthResult> addUidToCategory({
    required String categoryId,
    required String uid,
  }) async {
    try {
      debugPrint('🎯 카테고리 사용자 추가 시도: $categoryId <- $uid');

      // 1. 현재 사용자 확인
      final currentUserId = authService.currentUser?.uid;
      if (currentUserId == null || currentUserId.isEmpty) {
        return AuthResult.failure('로그인이 필요합니다.');
      }

      // 2. 자기 자신 추가 시도 확인
      if (currentUserId == uid) {
        return AuthResult.failure('자기 자신은 이미 카테고리 멤버입니다.');
      }

      // 3. 카테고리 존재 확인
      final category = await _repository.getCategory(categoryId);
      if (category == null) {
        return AuthResult.failure('카테고리를 찾을 수 없습니다.');
      }

      // 4. 이미 멤버인지 확인
      if (category.mates.contains(uid)) {
        return AuthResult.failure('이미 카테고리 멤버입니다.');
      }

      // 5. 초대 대상자와 초대자의 친구 관계 확인
      final isInviterMutualFriend = await friendService.areUsersMutualFriends(
        currentUserId,
        uid,
      );

      // 6. 기존 멤버들과 초대 대상자의 친구 관계 확인
      final pendingMateIds = await _getPendingMateIds(
        category: category,
        invitedUserId: uid,
        inviterUserId: currentUserId,
      );

      // 7. 초대 대상자와 친구가 아닌 멤버 목록
      final unknownMemberIds = <String>{
        ...pendingMateIds,
        if (!isInviterMutualFriend) currentUserId,
      };

      // 8. 친구가 아닌 멤버가 있으면 초대 프로세스 진행
      if (unknownMemberIds.isNotEmpty) {
        debugPrint('⏳ 친구가 아닌 멤버 발견: ${unknownMemberIds.length}명 - 초대 수락 필요');
        debugPrint('⏳ 친구가 아닌 멤버 목록: $unknownMemberIds');

        final inviteId = await _createOrUpdateCategoryInvite(
          category: category,
          invitedUserId: uid,
          inviterUserId: currentUserId,
          blockedMateIds: unknownMemberIds.toList(),
        );

        try {
          await notificationService.createCategoryInviteNotification(
            categoryId: categoryId,
            actorUserId: currentUserId,
            recipientUserIds: [uid],
            requiresAcceptance: true,
            categoryInviteId: inviteId,
            pendingMemberIds: unknownMemberIds.toList(),
          );
          debugPrint('🔔 카테고리 초대 알림 전송 (수락 대기) 완료');
        } catch (e) {
          debugPrint('⚠️ 카테고리 초대 알림 전송 실패 (수락 대기): $e');
        }

        debugPrint('⏳ mates에 추가하지 않고 초대만 전송함');
        return AuthResult.success('초대를 보냈습니다. 상대방의 수락을 기다리고 있습니다.');
      }

      // 9. 모든 멤버와 친구 관계일 경우 바로 추가
      debugPrint('✅ 모든 멤버와 친구 관계 확인됨 - 즉시 추가');
      await _repository.addUidToCategory(categoryId: categoryId, uid: uid);
      debugPrint('✅ 카테고리 사용자 추가 성공');

      try {
        await notificationService.createCategoryInviteNotification(
          categoryId: categoryId,
          actorUserId: currentUserId,
          recipientUserIds: [uid],
        );
        debugPrint('🔔 카테고리 초대 알림 전송 완료');
      } catch (e) {
        debugPrint('⚠️ 카테고리 초대 알림 전송 실패: $e');
      }

      return AuthResult.success('카테고리에 추가되었습니다.');
    } catch (e) {
      debugPrint('💥 addUidToCategory 에러: $e');
      return AuthResult.failure('카테고리에 사용자 추가 실패: $e');
    }
  }

  /// 카테고리에서 사용자 제거 (UID로)
  Future<AuthResult> removeUidFromCategory({
    required String categoryId,
    required String uid,
  }) async {
    try {
      // 현재 카테고리 정보 가져오기
      final category = await _repository.getCategory(categoryId);
      if (category == null) {
        return AuthResult.failure('카테고리를 찾을 수 없습니다.');
      }

      // mates 리스트에서 해당 UID 제거
      final updatedMates = List<String>.from(category.mates);
      if (!updatedMates.contains(uid)) {
        return AuthResult.failure('해당 사용자는 이 카테고리의 멤버가 아닙니다.');
      }

      updatedMates.remove(uid);

      // 멤버가 모두 없어지면 카테고리 삭제
      if (updatedMates.isEmpty) {
        await _repository.deleteCategory(categoryId);
        return AuthResult.success('카테고리에서 나갔습니다. 마지막 멤버였으므로 카테고리가 삭제되었습니다.');
      }

      // mates 업데이트
      await _repository.updateCategory(categoryId, {'mates': updatedMates});
      return AuthResult.success('카테고리에서 나갔습니다.');
    } catch (e) {
      return AuthResult.failure('카테고리 나가기 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리에 새 사진 업로드 정보 업데이트
  Future<void> updateLastPhotoInfo({
    required String categoryId,
    required String uploadedBy,
  }) async {
    try {
      final now = Timestamp.now();

      await _repository.updateCategory(categoryId, {
        'lastPhotoUploadedBy': uploadedBy,
        'lastPhotoUploadedAt': now,
      });
    } catch (e) {
      debugPrint('카테고리 최신 사진 정보 업데이트 실패: $e');
    }
  }

  /// 사용자가 카테고리를 확인했음을 기록
  Future<void> updateUserViewTime({
    required String categoryId,
    required String userId,
  }) async {
    try {
      final now = Timestamp.now();

      await _repository.updateCategory(categoryId, {
        'userLastViewedAt.$userId': now,
      });
    } catch (e) {
      debugPrint('사용자 확인 시간 업데이트 실패: $e');
    }
  }

  /// 카테고리 대표사진 삭제 후 최신 사진으로 자동 업데이트
  Future<void> updateCoverPhotoToLatestAfterDeletion(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        throw ArgumentError('카테고리 ID가 필요합니다.');
      }

      // 카테고리의 최신 사진 조회
      final photos = await photoService.getPhotosByCategory(categoryId);

      if (photos.isNotEmpty) {
        // 최신 사진으로 대표사진 업데이트 (자동 설정)
        await _repository.updateCategoryPhoto(
          categoryId: categoryId,
          photoUrl: photos.first.imageUrl, // 이미 최신순으로 정렬되어 있음
        );

        // 관련 알림들의 썸네일 업데이트
        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: photos.first.imageUrl,
          );
        } catch (e) {
          debugPrint('⚠️ 알림 썸네일 업데이트 실패: $e');
        }
      } else {
        // 사진이 없으면 대표사진 제거
        await _repository.deleteCategoryPhoto(categoryId);

        // 관련 알림들의 썸네일을 null로 업데이트
        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: '',
          );
        } catch (e) {
          debugPrint('⚠️ 알림 썸네일 업데이트 실패: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ 삭제 후 대표사진 자동 업데이트 실패: $e');
    }
  }

  /// 차단된 사용자가 있는 카테고리를 필터링하는 메서드
  Future<List<CategoryDataModel>> _filterCategoriesWithBlockedUsers(
    List<CategoryDataModel> categories,
  ) async {
    try {
      // 1. 내가 차단한 사용자만 조회 (차단당한 사용자는 차단 사실을 알면 안됨)
      final blockedByMe = await friendService.getBlockedUsers(); // 내가 차단한 사용자

      if (blockedByMe.isEmpty) {
        return categories; // 내가 차단한 사용자가 없으면 필터링 불필요
      }

      // 2. 각 카테고리를 검사하여 필터링
      final filteredCategories = <CategoryDataModel>[];
      final currentUserId = authService.currentUser?.uid;

      for (final category in categories) {
        // 카테고리가 나와 내가 차단한 사용자 두 명만 있는지 확인
        if (category.mates.length == 2) {
          final otherUser = category.mates.firstWhere(
            (uid) => uid != currentUserId,
            orElse: () => '',
          );

          // 나와 내가 차단한 사용자 두 명만 있는 카테고리는 완전히 숨김
          if (otherUser.isNotEmpty && blockedByMe.contains(otherUser)) {
            continue; // 이 카테고리는 건너뛰기 (숨김)
          }
        }

        // 그 외 모든 카테고리는 포함 (사진 필터링은 getCategoryPhotos에서 처리)
        filteredCategories.add(category);
      }

      return filteredCategories;
    } catch (e) {
      debugPrint('카테고리 필터링 중 오류 발생: $e');
      return categories; // 오류 발생 시 원본 반환
    }
  }
}
