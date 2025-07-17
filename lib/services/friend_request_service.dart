import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_request_model.dart';
import '../models/contact_data_model.dart';
import '../repositories/friend_request_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/contact_repository.dart';

/// 친구 요청 관련 비즈니스 로직을 처리하는 Service
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class FriendRequestService {
  final FriendRequestRepository _friendRequestRepository =
      FriendRequestRepository();
  final AuthRepository _authRepository = AuthRepository();
  final ContactRepository _contactRepository = ContactRepository();

  // ==================== 친구 요청 비즈니스 로직 ====================

  /// 전화번호로 친구 요청 보내기
  Future<FriendRequestResult> sendFriendRequestByPhone({
    required String fromUserId,
    required String fromUserNickname,
    required String phoneNumber,
    String? message,
  }) async {
    try {
      debugPrint('📞 전화번호로 친구 요청: $phoneNumber');

      // 1. 전화번호 정규화
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      if (normalizedPhone.isEmpty) {
        return FriendRequestResult.failure('유효하지 않은 전화번호입니다.');
      }

      // 2. 전화번호로 사용자 검색
      final targetUser = await _authRepository.findUserByPhone(normalizedPhone);
      if (targetUser == null) {
        return FriendRequestResult.failure('해당 전화번호로 가입한 사용자를 찾을 수 없습니다.');
      }

      final targetUserData = targetUser.data() as Map<String, dynamic>;
      final toUserId = targetUser.id;
      final toUserNickname = targetUserData['id'] ?? '';

      // 3. 자기 자신에게 요청 방지
      if (fromUserId == toUserId) {
        return FriendRequestResult.failure('자기 자신에게는 친구 요청을 보낼 수 없습니다.');
      }

      // 4. 친구 요청 생성
      return await _createFriendRequest(
        fromUserId: fromUserId,
        fromUserNickname: fromUserNickname,
        toUserId: toUserId,
        toUserNickname: toUserNickname,
        type: FriendRequestType.phone,
        message: message,
        metadata: {'phoneNumber': normalizedPhone},
      );
    } catch (e) {
      debugPrint('❌ 전화번호 친구 요청 실패: $e');
      return FriendRequestResult.failure('친구 요청 전송 중 오류가 발생했습니다.');
    }
  }

  /// ID(닉네임)로 친구 요청 보내기
  Future<FriendRequestResult> sendFriendRequestByNickname({
    required String fromUserId,
    required String fromUserNickname,
    required String targetNickname,
    String? message,
  }) async {
    try {
      debugPrint('🔍 닉네임으로 친구 요청: $targetNickname');

      // 1. 닉네임 검증
      if (targetNickname.trim().isEmpty) {
        return FriendRequestResult.failure('닉네임을 입력해주세요.');
      }

      // 2. 닉네임으로 사용자 검색 (수정된 로직)
      final userNicknames = await _authRepository.searchUsersByNickname(
        targetNickname,
      );
      if (userNicknames.isEmpty || !userNicknames.contains(targetNickname)) {
        return FriendRequestResult.failure('해당 닉네임의 사용자를 찾을 수 없습니다.');
      }

      // 3. 정확한 닉네임 매치를 위해 Firestore에서 직접 조회
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('id', isEqualTo: targetNickname)
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        return FriendRequestResult.failure('해당 닉네임의 사용자를 찾을 수 없습니다.');
      }

      final targetUser = querySnapshot.docs.first;
      final targetUserData = targetUser.data();
      final toUserId = targetUser.id;

      // 3. 자기 자신에게 요청 방지
      if (fromUserId == toUserId) {
        return FriendRequestResult.failure('자기 자신에게는 친구 요청을 보낼 수 없습니다.');
      }

      // 4. 친구 요청 생성
      return await _createFriendRequest(
        fromUserId: fromUserId,
        fromUserNickname: fromUserNickname,
        toUserId: toUserId,
        toUserNickname: targetNickname,
        type: FriendRequestType.search,
        message: message,
      );
    } catch (e) {
      debugPrint('❌ 닉네임 친구 요청 실패: $e');
      return FriendRequestResult.failure('친구 요청 전송 중 오류가 발생했습니다.');
    }
  }

  /// 추천을 통한 친구 요청 보내기
  Future<FriendRequestResult> sendFriendRequestFromSuggestion({
    required String fromUserId,
    required String fromUserNickname,
    required FriendSuggestionModel suggestion,
    String? message,
  }) async {
    try {
      debugPrint('💡 추천을 통한 친구 요청: ${suggestion.nickname}');

      return await _createFriendRequest(
        fromUserId: fromUserId,
        fromUserNickname: fromUserNickname,
        toUserId: suggestion.userId,
        toUserNickname: suggestion.nickname,
        type: FriendRequestType.suggestion,
        message: message,
        metadata: {
          'suggestion': suggestion.toJson(),
          'suggestionReasons': suggestion.reasons,
          'suggestionScore': suggestion.score,
        },
      );
    } catch (e) {
      debugPrint('❌ 추천 친구 요청 실패: $e');
      return FriendRequestResult.failure('친구 요청 전송 중 오류가 발생했습니다.');
    }
  }

  /// 친구 요청 응답 (수락/거절)
  Future<FriendRequestResult> respondToFriendRequest({
    required String requestId,
    required FriendRequestStatus status,
    required String respondingUserId,
  }) async {
    try {
      debugPrint('📝 친구 요청 응답: $requestId → $status');

      // 1. 비즈니스 규칙 검증
      if (status != FriendRequestStatus.accepted &&
          status != FriendRequestStatus.rejected) {
        return FriendRequestResult.failure('잘못된 응답 상태입니다.');
      }

      // 2. Repository를 통해 응답 처리
      final success = await _friendRequestRepository.respondToFriendRequest(
        requestId: requestId,
        status: status,
        respondingUserId: respondingUserId,
      );

      if (success) {
        // 3. 수락인 경우 추가 비즈니스 로직
        if (status == FriendRequestStatus.accepted) {
          // 친구 추천 목록에서 해당 사용자 제거
          await _removeFriendFromSuggestions(respondingUserId, requestId);
        }

        final statusText = status == FriendRequestStatus.accepted ? '수락' : '거절';
        debugPrint('✅ 친구 요청 $statusText 완료');

        return FriendRequestResult.success();
      } else {
        return FriendRequestResult.failure('친구 요청 응답 처리에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('❌ 친구 요청 응답 실패: $e');
      return FriendRequestResult.failure(e.toString());
    }
  }

  /// 친구 요청 취소
  Future<FriendRequestResult> cancelFriendRequest({
    required String requestId,
    required String cancellingUserId,
  }) async {
    try {
      final success = await _friendRequestRepository.cancelFriendRequest(
        requestId: requestId,
        cancellingUserId: cancellingUserId,
      );

      if (success) {
        return FriendRequestResult.success();
      } else {
        return FriendRequestResult.failure('친구 요청 취소에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('❌ 친구 요청 취소 실패: $e');
      return FriendRequestResult.failure(e.toString());
    }
  }

  // ==================== 친구 추천 비즈니스 로직 ====================

  /// 연락처 기반 친구 추천 생성
  Future<List<FriendSuggestionModel>> generateFriendSuggestions(
    String userId, {
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint('🔮 친구 추천 생성 시작: $userId');

      // 1. 캐시된 추천 확인 (force refresh가 아닌 경우)
      if (!forceRefresh) {
        final cachedSuggestions = await _friendRequestRepository
            .getFriendSuggestions(userId);
        if (cachedSuggestions.isNotEmpty) {
          debugPrint('💾 캐시된 친구 추천 반환: ${cachedSuggestions.length}개');
          return cachedSuggestions;
        }
      }

      // 2. 사용자의 연락처 목록 조회
      final contacts = await _contactRepository.getContactsFromFirestore();

      // 3. 이미 친구인 사용자들 조회
      final friends = await _friendRequestRepository.getFriends(userId);
      final friendUserIds = friends.map((f) => f.userId).toSet();

      // 4. 보낸/받은 친구 요청 조회
      final sentRequests = await _friendRequestRepository.getSentRequests(
        userId,
      );
      final receivedRequests = await _friendRequestRepository
          .getReceivedRequests(userId);
      final requestedUserIds = {
        ...sentRequests.map((r) => r.toUserId),
        ...receivedRequests.map((r) => r.fromUserId),
      };

      // 5. 연락처 기반 사용자 검색 및 추천 점수 계산
      final suggestions = <FriendSuggestionModel>[];

      for (final contact in contacts) {
        if (contact.phoneNumber.isEmpty) continue;

        try {
          // 연락처의 전화번호로 사용자 검색
          final userDoc = await _authRepository.findUserByPhone(
            contact.phoneNumber,
          );
          if (userDoc == null) continue;

          final userData = userDoc.data() as Map<String, dynamic>;
          final targetUserId = userDoc.id;
          final targetNickname = userData['id'] ?? '';

          // 제외 조건 확인
          if (targetUserId == userId || // 자기 자신
              friendUserIds.contains(targetUserId) || // 이미 친구
              requestedUserIds.contains(targetUserId)) {
            // 이미 요청 보냄/받음
            continue;
          }

          // 간단한 추천 이유 생성
          final reasons = ['연락처에 저장된 친구'];
          if (contact.displayName.isNotEmpty) {
            reasons.add('연락처 이름: ${contact.displayName}');
          }

          final suggestion = FriendSuggestionModel(
            userId: targetUserId,
            nickname: targetNickname,
            profileImageUrl: userData['profile_image'],
            phoneNumber: contact.phoneNumber,
            score: 1.0, // 모든 추천에 동일한 점수
            reasons: reasons,
            metadata: {
              'contactName': contact.displayName,
              'foundVia': 'contacts',
            },
          );

          suggestions.add(suggestion);
        } catch (e) {
          debugPrint('⚠️ 연락처 처리 중 오류: ${contact.phoneNumber} - $e');
          continue;
        }
      }

      // 6. 가나다순으로 정렬 후 상위 20개만 선택
      suggestions.sort((a, b) => a.nickname.compareTo(b.nickname));
      final topSuggestions = suggestions.take(20).toList();

      // 7. 캐시에 저장
      await _friendRequestRepository.saveFriendSuggestions(
        userId: userId,
        suggestions: topSuggestions,
        contactSyncEnabled: true,
      );

      debugPrint('✅ 친구 추천 생성 완료: ${topSuggestions.length}개 (가나다순 정렬)');
      return topSuggestions;
    } catch (e) {
      debugPrint('❌ 친구 추천 생성 실패: $e');
      return [];
    }
  }

  /// 친구 추천 새로고침
  Future<List<FriendSuggestionModel>> refreshFriendSuggestions(
    String userId,
  ) async {
    return await generateFriendSuggestions(userId, forceRefresh: true);
  }

  /// 특정 사용자를 추천에서 제거
  Future<bool> removeSuggestion(String userId, String targetUserId) async {
    try {
      final suggestions = await _friendRequestRepository.getFriendSuggestions(
        userId,
      );
      final updatedSuggestions =
          suggestions.where((s) => s.userId != targetUserId).toList();

      return await _friendRequestRepository.saveFriendSuggestions(
        userId: userId,
        suggestions: updatedSuggestions,
        contactSyncEnabled: true,
      );
    } catch (e) {
      debugPrint('❌ 추천 제거 실패: $e');
      return false;
    }
  }

  // ==================== 친구 관계 관리 ====================

  /// 친구 목록 조회 (비즈니스 로직 적용)
  Future<List<FriendModel>> getFriends(String userId) async {
    try {
      final friends = await _friendRequestRepository.getFriends(userId);

      // 비즈니스 로직: 최근 상호작용 순으로 정렬
      friends.sort((a, b) {
        final aTime = a.lastInteraction ?? a.becameFriendsAt;
        final bTime = b.lastInteraction ?? b.becameFriendsAt;
        return bTime.compareTo(aTime);
      });

      return friends;
    } catch (e) {
      debugPrint('❌ 친구 목록 조회 실패: $e');
      return [];
    }
  }

  /// 친구 관계 상태 확인
  Future<FriendshipStatus> getFriendshipStatus(
    String currentUserId,
    String targetUserId,
  ) async {
    return await _friendRequestRepository.getFriendshipStatus(
      currentUserId,
      targetUserId,
    );
  }

  /// 친구 삭제
  Future<bool> removeFriend(String userId, String friendUserId) async {
    try {
      // 비즈니스 로직: 추가 확인 로직이 필요한 경우 여기에 구현
      return await _friendRequestRepository.removeFriend(userId, friendUserId);
    } catch (e) {
      debugPrint('❌ 친구 삭제 실패: $e');
      return false;
    }
  }

  // ==================== 조회 메서드 ====================

  /// 받은 친구 요청 목록 조회
  Future<List<FriendRequestModel>> getReceivedRequests(String userId) async {
    return await _friendRequestRepository.getReceivedRequests(userId);
  }

  /// 보낸 친구 요청 목록 조회
  Future<List<FriendRequestModel>> getSentRequests(String userId) async {
    return await _friendRequestRepository.getSentRequests(userId);
  }

  /// 친구 추천 목록 조회
  Future<List<FriendSuggestionModel>> getFriendSuggestions(
    String userId,
  ) async {
    return await _friendRequestRepository.getFriendSuggestions(userId);
  }

  // ==================== 스트림 메서드 ====================

  /// 받은 친구 요청 실시간 스트림
  Stream<List<FriendRequestModel>> getReceivedRequestsStream(String userId) {
    return _friendRequestRepository.getReceivedRequestsStream(userId);
  }

  /// 보낸 친구 요청 실시간 스트림
  Stream<List<FriendRequestModel>> getSentRequestsStream(String userId) {
    return _friendRequestRepository.getSentRequestsStream(userId);
  }

  /// 친구 목록 실시간 스트림
  Stream<List<FriendModel>> getFriendsStream(String userId) {
    return _friendRequestRepository.getFriendsStream(userId);
  }

  // ==================== 내부 헬퍼 메서드 ====================

  /// 친구 요청 생성 (공통 로직)
  Future<FriendRequestResult> _createFriendRequest({
    required String fromUserId,
    required String fromUserNickname,
    required String toUserId,
    required String toUserNickname,
    required FriendRequestType type,
    String? message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 비즈니스 규칙 검증
      final validationResult = _validateFriendRequest(
        fromUserId,
        toUserId,
        fromUserNickname,
        toUserNickname,
      );

      if (!validationResult.isSuccess) {
        return validationResult;
      }

      // 친구 요청 모델 생성
      final request = FriendRequestModel(
        id: '', // Repository에서 생성
        fromUserId: fromUserId,
        fromUserNickname: fromUserNickname,
        toUserId: toUserId,
        toUserNickname: toUserNickname,
        status: FriendRequestStatus.pending,
        type: type,
        createdAt: DateTime.now(),
        message: message,
        metadata: metadata,
      );

      // Repository를 통해 생성
      final requestId = await _friendRequestRepository.createFriendRequest(
        request,
      );

      if (requestId != null) {
        final createdRequest = request.copyWith(id: requestId);
        return FriendRequestResult.success(createdRequest);
      } else {
        return FriendRequestResult.failure('친구 요청 생성에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('❌ 친구 요청 생성 실패: $e');
      return FriendRequestResult.failure(e.toString());
    }
  }

  /// 친구 요청 검증
  FriendRequestResult _validateFriendRequest(
    String fromUserId,
    String toUserId,
    String fromUserNickname,
    String toUserNickname,
  ) {
    // 1. 기본 검증
    if (fromUserId.isEmpty || toUserId.isEmpty) {
      return FriendRequestResult.failure('사용자 정보가 올바르지 않습니다.');
    }

    if (fromUserNickname.isEmpty || toUserNickname.isEmpty) {
      return FriendRequestResult.failure('사용자 닉네임이 올바르지 않습니다.');
    }

    // 2. 자기 자신 확인
    if (fromUserId == toUserId) {
      return FriendRequestResult.failure('자기 자신에게는 친구 요청을 보낼 수 없습니다.');
    }

    return FriendRequestResult.success();
  }

  /// 전화번호 정규화
  String _normalizePhoneNumber(String phone) {
    // 특수문자 제거 후 숫자만 남기기
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // 최소 길이 검증
    if (cleaned.length < 8) return '';

    // 한국 번호 형식 정규화 (0으로 시작하면 제거)
    if (cleaned.startsWith('0')) {
      return cleaned.substring(1);
    }

    return cleaned;
  }

  /// 친구 추천에서 특정 사용자 제거 (친구 요청 수락 시)
  Future<void> _removeFriendFromSuggestions(
    String userId,
    String requestId,
  ) async {
    try {
      // 요청 정보 조회
      final request = await _friendRequestRepository.getFriendRequest(
        requestId,
      );
      if (request == null) return;

      // 양방향 추천에서 제거
      await removeSuggestion(request.fromUserId, request.toUserId);
      await removeSuggestion(request.toUserId, request.fromUserId);
    } catch (e) {
      debugPrint('⚠️ 추천에서 친구 제거 실패: $e');
    }
  }

  /// 만료된 요청 정리 (관리자용)
  Future<int> cleanupExpiredRequests() async {
    return await _friendRequestRepository.cleanupExpiredRequests();
  }
}
