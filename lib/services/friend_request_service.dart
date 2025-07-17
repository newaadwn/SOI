import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/friend_request_model.dart';
import '../repositories/friend_request_repository.dart';
import '../repositories/auth_repository.dart';

/// 친구 요청 관련 비즈니스 로직을 처리하는 Service
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class FriendRequestService {
  final FriendRequestRepository _friendRequestRepository =
      FriendRequestRepository();
  final AuthRepository _authRepository = AuthRepository();

  // 앱 다운로드 링크 (데모용)
  static const String _appDownloadLink = 'https://soi-app-demo.com/download';
  static const String _appName = 'SOI';

  // ==================== 친구 요청 비즈니스 로직 ====================

  /// 전화번호로 친구 요청 보내기 또는 앱 초대하기
  Future<FriendRequestResult> sendFriendRequestByPhone({
    required String fromUserId,
    required String fromUserNickname,
    required String phoneNumber,
    String? message,
  }) async {
    try {
      debugPrint('📞 전화번호로 친구 요청/초대: $phoneNumber');

      // 1. 전화번호 정규화
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      if (normalizedPhone.isEmpty) {
        return FriendRequestResult.failure('유효하지 않은 전화번호입니다.');
      }

      // 2. 전화번호로 사용자 검색
      final targetUser = await _authRepository.findUserByPhone(normalizedPhone);

      if (targetUser == null) {
        // 🎯 사용자가 앱을 설치하지 않았거나 삭제한 경우 -> SMS로 초대 링크 보내기
        debugPrint('📱 앱 미설치 사용자 - SMS 초대 링크 발송: $phoneNumber');
        return await _sendAppInvitationSMS(
          phoneNumber: normalizedPhone,
          inviterName: fromUserNickname,
          message: message,
        );
      }

      final targetUserData = targetUser.data() as Map<String, dynamic>;
      final toUserId = targetUser.id;
      final toUserNickname = targetUserData['id'] ?? '';

      // 3. 사용자가 활성 상태인지 확인 (선택적)
      final isUserActive = await _checkUserActiveStatus(targetUserData);
      if (!isUserActive) {
        // 사용자가 앱을 삭제했거나 비활성 상태인 경우 SMS 보내기
        debugPrint('📱 비활성 사용자 - SMS 초대 링크 발송: $phoneNumber');
        return await _sendAppInvitationSMS(
          phoneNumber: normalizedPhone,
          inviterName: fromUserNickname,
          message: message,
        );
      }

      // 4. 자기 자신에게 요청 방지
      if (fromUserId == toUserId) {
        return FriendRequestResult.failure('자기 자신에게는 친구 요청을 보낼 수 없습니다.');
      }

      // 5. 🎯 활성 사용자인 경우 -> 친구 요청 생성
      debugPrint('✅ 활성 사용자 - 친구 요청 발송: $toUserNickname');
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
      debugPrint('❌ 전화번호 친구 요청/초대 실패: $e');
      return FriendRequestResult.failure('요청 처리 중 오류가 발생했습니다.');
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
          // 친구 목록 업데이트 등의 작업이 여기에 추가될 수 있음
          debugPrint('친구 요청 수락 - 추가 비즈니스 로직 실행');
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

  /// 만료된 요청 정리 (관리자용)
  Future<int> cleanupExpiredRequests() async {
    return await _friendRequestRepository.cleanupExpiredRequests();
  }

  /// 앱 초대 링크를 SMS로 보내기
  Future<FriendRequestResult> _sendAppInvitationSMS({
    required String phoneNumber,
    required String inviterName,
    String? message,
  }) async {
    try {
      // SMS 초대 메시지 구성
      final inviteMessage =
          '$inviterName님이 $_appName 앱에 초대했습니다! 다운로드: $_appDownloadLink';

      // SMS URI 생성 (URL 인코딩)
      final encodedMessage = Uri.encodeComponent(inviteMessage);
      final smsUri = Uri.parse('sms:$phoneNumber?body=$encodedMessage');

      debugPrint('📱 SMS 초대 링크 발송 시도: $phoneNumber');
      debugPrint('💬 메시지: $inviteMessage');

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        debugPrint('✅ SMS 초대 링크 발송 성공');
        return FriendRequestResult.smsInvitationSuccess(phoneNumber);
      } else {
        debugPrint('❌ SMS 앱을 열 수 없습니다');
        return FriendRequestResult.smsInvitationFailure(
          '문자 메시지를 보낼 수 없습니다. SMS 앱을 확인해주세요.',
        );
      }
    } catch (e) {
      debugPrint('❌ SMS 초대 발송 중 오류: $e');
      return FriendRequestResult.smsInvitationFailure(
        '초대 메시지 발송 중 오류가 발생했습니다.',
      );
    }
  }

  /// 사용자 활성 상태 확인 (간단 버전)
  Future<bool> _checkUserActiveStatus(Map<String, dynamic> userData) async {
    try {
      // 기본적으로 Firestore에서 조회되면 활성 상태로 간주
      // 추후 더 정교한 로직으로 개선 가능 (예: 최근 로그인 시간 확인)

      final lastLogin = userData['lastLogin'];
      if (lastLogin == null) {
        // 로그인 기록이 없으면 비활성으로 간주
        debugPrint('🕒 마지막 로그인 기록이 없음 - 비활성 처리');
        return false;
      }

      // 30일 이내 로그인한 사용자만 활성으로 간주
      final lastLoginDate = (lastLogin as Timestamp).toDate();
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final isActive = lastLoginDate.isAfter(thirtyDaysAgo);
      debugPrint('🕒 마지막 로그인: $lastLoginDate, 활성 상태: $isActive');

      return isActive;
    } catch (e) {
      debugPrint('❌ 사용자 활성 상태 확인 실패: $e');
      // 오류 시 안전을 위해 활성 상태로 간주 (친구 요청 보내기)
      return true;
    }
  }
}
