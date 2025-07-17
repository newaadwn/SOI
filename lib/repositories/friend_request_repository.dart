import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/friend_request_model.dart';

/// 친구 요청 관련 Firebase 데이터 액세스 Repository
/// 실제 데이터 CRUD 작업을 담당
class FriendRequestRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== 컬렉션 참조 ====================

  /// friend_requests 컬렉션 참조
  CollectionReference get _friendRequestsCollection =>
      _firestore.collection('friend_requests');

  /// 특정 사용자의 friends 서브컬렉션 참조
  CollectionReference _userFriendsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('friends');

  // ==================== 친구 요청 CRUD ====================

  /// 친구 요청 생성
  Future<String?> createFriendRequest(FriendRequestModel request) async {
    try {
      debugPrint(
        '📤 친구 요청 생성 시작: ${request.fromUserNickname} → ${request.toUserNickname}',
      );

      // 1. 중복 요청 확인
      final existingRequest = await checkExistingRequest(
        request.fromUserId,
        request.toUserId,
      );

      if (existingRequest != null) {
        throw Exception('이미 친구 요청이 존재합니다.');
      }

      // 2. 이미 친구인지 확인
      final isFriend = await areFriends(request.fromUserId, request.toUserId);
      if (isFriend) {
        throw Exception('이미 친구 관계입니다.');
      }

      // 3. 친구 요청 문서 생성
      final docRef = await _friendRequestsCollection.add(request.toFirestore());

      debugPrint('✅ 친구 요청 생성 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ 친구 요청 생성 실패: $e');
      rethrow;
    }
  }

  /// 친구 요청 응답 (수락/거절)
  Future<bool> respondToFriendRequest({
    required String requestId,
    required FriendRequestStatus status,
    required String respondingUserId,
  }) async {
    try {
      debugPrint('📝 친구 요청 응답 시작: $requestId → $status');

      // 1. 요청 문서 조회
      final requestDoc = await _friendRequestsCollection.doc(requestId).get();

      if (!requestDoc.exists) {
        throw Exception('친구 요청을 찾을 수 없습니다.');
      }

      final request = FriendRequestModel.fromFirestore(requestDoc);

      // 2. 응답 권한 확인
      if (request.toUserId != respondingUserId) {
        throw Exception('친구 요청에 응답할 권한이 없습니다.');
      }

      // 3. 요청 상태 확인
      if (!request.canRespond) {
        throw Exception('응답할 수 없는 상태의 요청입니다.');
      }

      // 4. 배치 작업 시작
      final batch = _firestore.batch();

      // 5. 친구 요청 상태 업데이트
      batch.update(_friendRequestsCollection.doc(requestId), {
        'status': status.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // 6. 수락인 경우 양방향 친구 관계 생성
      if (status == FriendRequestStatus.accepted) {
        await _createFriendship(batch, request);
      }

      // 7. 배치 실행
      await batch.commit();

      debugPrint('✅ 친구 요청 응답 완료: $status');
      return true;
    } catch (e) {
      debugPrint('❌ 친구 요청 응답 실패: $e');
      rethrow;
    }
  }

  /// 친구 요청 취소
  Future<bool> cancelFriendRequest({
    required String requestId,
    required String cancellingUserId,
  }) async {
    try {
      debugPrint('🚫 친구 요청 취소 시작: $requestId');

      final requestDoc = await _friendRequestsCollection.doc(requestId).get();

      if (!requestDoc.exists) {
        throw Exception('친구 요청을 찾을 수 없습니다.');
      }

      final request = FriendRequestModel.fromFirestore(requestDoc);

      // 권한 확인 - 요청 보낸 사람만 취소 가능
      if (request.fromUserId != cancellingUserId) {
        throw Exception('친구 요청을 취소할 권한이 없습니다.');
      }

      // 상태 확인 - pending 상태만 취소 가능
      if (request.status != FriendRequestStatus.pending) {
        throw Exception('취소할 수 없는 상태의 요청입니다.');
      }

      // 상태 업데이트
      await _friendRequestsCollection.doc(requestId).update({
        'status': FriendRequestStatus.cancelled.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 친구 요청 취소 완료');
      return true;
    } catch (e) {
      debugPrint('❌ 친구 요청 취소 실패: $e');
      rethrow;
    }
  }

  // ==================== 친구 요청 조회 ====================

  /// 받은 친구 요청 목록 조회
  Future<List<FriendRequestModel>> getReceivedRequests(String userId) async {
    try {
      final querySnapshot =
          await _friendRequestsCollection
              .where('toUserId', isEqualTo: userId)
              .where('status', isEqualTo: FriendRequestStatus.pending.name)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => FriendRequestModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ 받은 친구 요청 조회 실패: $e');
      return [];
    }
  }

  /// 보낸 친구 요청 목록 조회
  Future<List<FriendRequestModel>> getSentRequests(String userId) async {
    try {
      final querySnapshot =
          await _friendRequestsCollection
              .where('fromUserId', isEqualTo: userId)
              .where('status', isEqualTo: FriendRequestStatus.pending.name)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => FriendRequestModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ 보낸 친구 요청 조회 실패: $e');
      return [];
    }
  }

  /// 받은 친구 요청 실시간 스트림
  Stream<List<FriendRequestModel>> getReceivedRequestsStream(String userId) {
    return _friendRequestsCollection
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FriendRequestModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// 보낸 친구 요청 실시간 스트림
  Stream<List<FriendRequestModel>> getSentRequestsStream(String userId) {
    return _friendRequestsCollection
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FriendRequestModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// 특정 친구 요청 조회
  Future<FriendRequestModel?> getFriendRequest(String requestId) async {
    try {
      final doc = await _friendRequestsCollection.doc(requestId).get();

      if (!doc.exists) return null;

      return FriendRequestModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ 친구 요청 조회 실패: $e');
      return null;
    }
  }

  // ==================== 친구 관계 관리 ====================

  /// 친구 목록 조회
  Future<List<FriendModel>> getFriends(String userId) async {
    try {
      final querySnapshot =
          await _userFriendsCollection(userId)
              .where('isActive', isEqualTo: true)
              .orderBy('becameFriendsAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => FriendModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ 친구 목록 조회 실패: $e');
      return [];
    }
  }

  /// 친구 목록 실시간 스트림
  Stream<List<FriendModel>> getFriendsStream(String userId) {
    return _userFriendsCollection(userId)
        .where('isActive', isEqualTo: true)
        .orderBy('becameFriendsAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => FriendModel.fromFirestore(doc))
                  .toList(),
        );
  }

  /// 친구 관계 확인
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final doc = await _userFriendsCollection(userId1).doc(userId2).get();

      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>?;
      return data?['isActive'] == true;
    } catch (e) {
      debugPrint('❌ 친구 관계 확인 실패: $e');
      return false;
    }
  }

  /// 친구 삭제
  Future<bool> removeFriend(String userId, String friendUserId) async {
    try {
      debugPrint('🗑️ 친구 삭제 시작: $userId → $friendUserId');

      final batch = _firestore.batch();

      // 양방향 친구 관계 비활성화
      batch.update(_userFriendsCollection(userId).doc(friendUserId), {
        'isActive': false,
        'lastInteraction': FieldValue.serverTimestamp(),
      });

      batch.update(_userFriendsCollection(friendUserId).doc(userId), {
        'isActive': false,
        'lastInteraction': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      debugPrint('✅ 친구 삭제 완료');
      return true;
    } catch (e) {
      debugPrint('❌ 친구 삭제 실패: $e');
      return false;
    }
  }

  // ==================== 유틸리티 메서드 ====================

  /// 기존 친구 요청 확인 (중복 방지)
  Future<FriendRequestModel?> checkExistingRequest(
    String fromUserId,
    String toUserId,
  ) async {
    try {
      // 두 방향 모두 확인 (A→B 또는 B→A)
      final querySnapshot1 =
          await _friendRequestsCollection
              .where('fromUserId', isEqualTo: fromUserId)
              .where('toUserId', isEqualTo: toUserId)
              .where('status', isEqualTo: FriendRequestStatus.pending.name)
              .limit(1)
              .get();

      if (querySnapshot1.docs.isNotEmpty) {
        return FriendRequestModel.fromFirestore(querySnapshot1.docs.first);
      }

      final querySnapshot2 =
          await _friendRequestsCollection
              .where('fromUserId', isEqualTo: toUserId)
              .where('toUserId', isEqualTo: fromUserId)
              .where('status', isEqualTo: FriendRequestStatus.pending.name)
              .limit(1)
              .get();

      if (querySnapshot2.docs.isNotEmpty) {
        return FriendRequestModel.fromFirestore(querySnapshot2.docs.first);
      }

      return null;
    } catch (e) {
      debugPrint('❌ 기존 요청 확인 실패: $e');
      return null;
    }
  }

  /// 두 사용자 간의 관계 상태 확인
  Future<FriendshipStatus> getFriendshipStatus(
    String currentUserId,
    String targetUserId,
  ) async {
    try {
      // 1. 친구 관계 확인
      if (await areFriends(currentUserId, targetUserId)) {
        return FriendshipStatus.friends;
      }

      // 2. 친구 요청 확인
      final existingRequest = await checkExistingRequest(
        currentUserId,
        targetUserId,
      );

      if (existingRequest != null) {
        if (existingRequest.fromUserId == currentUserId) {
          return FriendshipStatus.requested; // 내가 보낸 요청
        } else {
          return FriendshipStatus.received; // 받은 요청
        }
      }

      return FriendshipStatus.none;
    } catch (e) {
      debugPrint('❌ 관계 상태 확인 실패: $e');
      return FriendshipStatus.none;
    }
  }

  // ==================== 내부 헬퍼 메서드 ====================

  /// 친구 관계 생성 (양방향)
  Future<void> _createFriendship(
    WriteBatch batch,
    FriendRequestModel request,
  ) async {
    try {
      debugPrint(
        '🤝 친구 관계 생성 시작: ${request.fromUserNickname} ↔ ${request.toUserNickname}',
      );

      final now = FieldValue.serverTimestamp();

      // A의 친구 목록에 B 추가
      final friendData1 = FriendModel(
        id: request.toUserId,
        userId: request.toUserId,
        nickname: request.toUserNickname,
        becameFriendsAt: DateTime.now(),
      );

      batch.set(
        _userFriendsCollection(request.fromUserId).doc(request.toUserId),
        friendData1.toFirestore(),
      );

      // B의 친구 목록에 A 추가
      final friendData2 = FriendModel(
        id: request.fromUserId,
        userId: request.fromUserId,
        nickname: request.fromUserNickname,
        becameFriendsAt: DateTime.now(),
      );

      batch.set(
        _userFriendsCollection(request.toUserId).doc(request.fromUserId),
        friendData2.toFirestore(),
      );

      debugPrint('✅ 친구 관계 생성 완료');
    } catch (e) {
      debugPrint('❌ 친구 관계 생성 실패: $e');
      rethrow;
    }
  }

  /// 만료된 친구 요청 정리 (배치 작업용)
  Future<int> cleanupExpiredRequests() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final querySnapshot =
          await _friendRequestsCollection
              .where('status', isEqualTo: FriendRequestStatus.pending.name)
              .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
              .get();

      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'status': FriendRequestStatus.cancelled.name,
          'respondedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      debugPrint('🧹 만료된 친구 요청 정리 완료: ${querySnapshot.docs.length}개');
      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('❌ 만료된 요청 정리 실패: $e');
      return 0;
    }
  }
}
