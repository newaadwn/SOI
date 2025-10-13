import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/friend_model.dart';

/// 친구 목록 Repository 클래스
/// Firestore의 users/{userId}/friends 서브컬렉션과 상호작용
class FriendRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// users 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// 현재 사용자 UID 가져오기
  String? get _currentUserUid => _auth.currentUser?.uid;

  /// 현재 사용자의 친구 컬렉션 참조
  CollectionReference<Map<String, dynamic>>? get _currentUserFriendsCollection {
    final currentUid = _currentUserUid;
    if (currentUid == null) return null;
    return _usersCollection.doc(currentUid).collection('friends');
  }

  /// 친구 목록 조회 (실시간)
  Stream<List<FriendModel>> getFriendsList() {
    final friendsCollection = _currentUserFriendsCollection;
    if (friendsCollection == null) {
      return Stream.value([]);
    }

    return friendsCollection
        .where('status', isEqualTo: 'active')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return FriendModel.fromFirestore(doc);
          }).toList();
        });
  }

  /// 즐겨찾기 친구 목록 조회 (실시간)
  Stream<List<FriendModel>> getFavoriteFriendsList() {
    final friendsCollection = _currentUserFriendsCollection;
    if (friendsCollection == null) {
      return Stream.value([]);
    }

    return friendsCollection
        .where('status', isEqualTo: 'active')
        .where('isFavorite', isEqualTo: true)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return FriendModel.fromFirestore(doc);
          }).toList();
        });
  }

  /// 양방향 친구 관계 생성
  ///
  /// [friendUid] 친구로 추가할 사용자 UID
  /// [friendid] 친구의 닉네임
  /// [friendName] 친구의 실명
  /// [currentUserid] 현재 사용자의 닉네임
  /// [currentUserName] 현재 사용자의 실명
  /// [friendProfileImageUrl] 친구의 프로필 이미지 URL
  /// [currentUserProfileImageUrl] 현재 사용자의 프로필 이미지 URL
  Future<void> addFriend({
    required String friendUid,
    required String friendid,
    required String friendName,
    required String currentUserid,
    required String currentUserName,
    String? friendProfileImageUrl,
    String? currentUserProfileImageUrl,
  }) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    if (currentUid == friendUid) {
      throw Exception('자기 자신을 친구로 추가할 수 없습니다');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final now = DateTime.now();

        // 1. 현재 사용자의 친구 목록에 추가
        final currentUserFriendDoc = _usersCollection
            .doc(currentUid)
            .collection('friends')
            .doc(friendUid);

        final currentUserFriend = FriendModel(
          userId: friendUid,
          id: friendid,
          name: friendName,
          profileImageUrl: friendProfileImageUrl,
          status: FriendStatus.active,
          isFavorite: false,
          addedAt: now,
        );

        transaction.set(currentUserFriendDoc, currentUserFriend.toJson());

        // 2. 친구의 친구 목록에 현재 사용자 추가
        final friendUserFriendDoc = _usersCollection
            .doc(friendUid)
            .collection('friends')
            .doc(currentUid);

        final friendUserFriend = FriendModel(
          userId: currentUid,
          id: currentUserid,
          name: currentUserName,
          profileImageUrl: currentUserProfileImageUrl,
          status: FriendStatus.active,
          isFavorite: false,
          addedAt: now,
        );

        transaction.set(friendUserFriendDoc, friendUserFriend.toJson());
      });
    } catch (e) {
      throw Exception('친구 추가 실패: $e');
    }
  }

  /// 친구 삭제
  /// [friendUid] 삭제할 친구의 UID
  Future<void> removeFriend(String friendUid) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    // 양방향 삭제는 하지 않고, 내 목록에서만 삭제
    try {
      await _usersCollection
          .doc(currentUid)
          .collection('friends')
          .doc(friendUid)
          .delete();
      debugPrint("일방향 친구 삭제 완료: $friendUid");
    } catch (e) {
      throw Exception('친구 삭제 실패: $e');
    }
  }

  /// 친구 차단
  ///
  /// [friendUid] 차단할 친구의 UID
  Future<void> blockFriend(String friendUid) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    try {
      await _usersCollection
          .doc(currentUid)
          .collection('friends')
          .doc(friendUid)
          .update({
            'status': FriendStatus.blocked.value,
            'lastInteraction': Timestamp.now(),
          });
    } catch (e) {
      throw Exception('친구 차단 실패: $e');
    }
  }

  /// 친구 차단 해제
  ///
  /// [friendUid] 차단 해제할 친구의 UID
  Future<void> unblockFriend(String friendUid) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    try {
      await _usersCollection
          .doc(currentUid)
          .collection('friends')
          .doc(friendUid)
          .update({
            'status': FriendStatus.active.value,
            'lastInteraction': Timestamp.now(),
          });
    } catch (e) {
      throw Exception('친구 차단 해제 실패: $e');
    }
  }

  /// 친구 즐겨찾기 설정/해제
  ///
  /// [friendUid] 즐겨찾기 설정할 친구의 UID
  /// [isFavorite] 즐겨찾기 여부
  Future<void> setFriendFavorite(String friendUid, bool isFavorite) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    try {
      await _usersCollection
          .doc(currentUid)
          .collection('friends')
          .doc(friendUid)
          .update({
            'isFavorite': isFavorite,
            'lastInteraction': Timestamp.now(),
          });
    } catch (e) {
      throw Exception('친구 즐겨찾기 설정 실패: $e');
    }
  }

  /// 친구 정보 업데이트
  ///
  /// [friendUid] 업데이트할 친구의 UID
  /// [updates] 업데이트할 필드들
  Future<void> updateFriend(
    String friendUid,
    Map<String, dynamic> updates,
  ) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다');
    }

    try {
      final updateData = Map<String, dynamic>.from(updates);
      updateData['lastInteraction'] = Timestamp.now();

      await _usersCollection
          .doc(currentUid)
          .collection('friends')
          .doc(friendUid)
          .update(updateData);
    } catch (e) {
      throw Exception('친구 정보 업데이트 실패: $e');
    }
  }

  /// 특정 친구 정보 조회
  ///
  /// [friendUid] 조회할 친구의 UID
  Future<FriendModel?> getFriend(String friendUid) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      return null;
    }

    try {
      final doc =
          await _usersCollection
              .doc(currentUid)
              .collection('friends')
              .doc(friendUid)
              .get();

      if (!doc.exists) {
        return null;
      }

      return FriendModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('친구 정보 조회 실패: $e');
    }
  }

  /// 두 사용자가 친구인지 확인
  ///
  /// [friendUid] 확인할 사용자의 UID
  Future<bool> isFriend(String friendUid) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      return false;
    }

    try {
      final doc =
          await _usersCollection
              .doc(currentUid)
              .collection('friends')
              .doc(friendUid)
              .get();

      if (!doc.exists) {
        return false;
      }

      final friend = FriendModel.fromFirestore(doc);
      return friend.status == FriendStatus.active;
    } catch (e) {
      return false;
    }
  }

  /// 두 사용자 ID가 서로를 친구로 가지고 있는지 확인
  Future<bool> areUsersMutualFriends(String userA, String userB) async {
    try {
      debugPrint('    🔍 친구 관계 확인: $userA ←→ $userB');

      final userAFriendDoc =
          await _usersCollection
              .doc(userA)
              .collection('friends')
              .doc(userB)
              .get();
      if (!userAFriendDoc.exists) {
        debugPrint('    ❌ $userA의 친구 목록에 $userB 없음');
        return false;
      }
      final userAFriend = FriendModel.fromFirestore(userAFriendDoc);
      if (userAFriend.status != FriendStatus.active) {
        debugPrint('    ❌ $userA → $userB 상태: ${userAFriend.status}');
        return false;
      }

      final userBFriendDoc =
          await _usersCollection
              .doc(userB)
              .collection('friends')
              .doc(userA)
              .get();
      if (!userBFriendDoc.exists) {
        debugPrint('    ❌ $userB의 친구 목록에 $userA 없음');
        return false;
      }
      final userBFriend = FriendModel.fromFirestore(userBFriendDoc);
      final result = userBFriend.status == FriendStatus.active;
      if (!result) {
        debugPrint('    ❌ $userB → $userA 상태: ${userBFriend.status}');
      } else {
        debugPrint('    ✅ 상호 친구 관계 확인됨');
      }
      return result;
    } catch (e) {
      debugPrint('    💥 areUsersMutualFriends 에러: $e');
      return false;
    }
  }

  /// 친구 목록에서 검색
  ///
  /// [query] 검색 쿼리 (닉네임 또는 이름)
  Future<List<FriendModel>> searchFriends(String query) async {
    final friendsCollection = _currentUserFriendsCollection;
    if (friendsCollection == null) {
      return [];
    }

    try {
      // Firestore에서는 부분 검색이 제한적이므로 클라이언트에서 필터링
      final snapshot =
          await friendsCollection.where('status', isEqualTo: 'active').get();

      final friends =
          snapshot.docs.map((doc) {
            return FriendModel.fromFirestore(doc);
          }).toList();

      // 클라이언트 측 검색 필터링
      final queryLower = query.toLowerCase();
      return friends.where((friend) {
        return friend.id.toLowerCase().contains(queryLower) ||
            friend.name.toLowerCase().contains(queryLower);
      }).toList();
    } catch (e) {
      throw Exception('친구 검색 실패: $e');
    }
  }

  /// 친구 수 조회
  Future<int> getFriendsCount() async {
    final friendsCollection = _currentUserFriendsCollection;
    if (friendsCollection == null) {
      return 0;
    }

    try {
      final snapshot =
          await friendsCollection.where('status', isEqualTo: 'active').get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// 마지막 상호작용 시간 업데이트
  ///
  /// [friendUid] 상호작용한 친구의 UID
  Future<void> updateLastInteraction(String friendUid) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      return;
    }

    try {
      await _usersCollection
          .doc(currentUid)
          .collection('friends')
          .doc(friendUid)
          .update({'lastInteraction': Timestamp.now()});
    } catch (e) {
      // 상호작용 시간 업데이트 실패는 중요하지 않으므로 로그만 출력
      // print('친구 상호작용 시간 업데이트 실패: $e');
    }
  }

  /// 현재 사용자의 새 프로필 이미지 URL을 모든 친구들의 friends 서브컬렉션 문서에 반영
  ///
  /// Firestore batch(최대 500)에 맞추어 청크로 나누어 업데이트
  Future<void> propagateCurrentUserProfileImage(
    String newProfileImageUrl,
  ) async {
    final currentUid = _currentUserUid;
    if (currentUid == null) return;

    try {
      // 내 친구 목록(= 내가 가진 friends 서브컬렉션)에서 친구 UID 들 수집
      final myFriendsSnapshot =
          await _usersCollection.doc(currentUid).collection('friends').get();

      if (myFriendsSnapshot.docs.isEmpty) return;

      final friendUids = myFriendsSnapshot.docs.map((d) => d.id).toList();

      const int batchLimit = 400; // 안전 마진 (500 제한 대비)
      for (var i = 0; i < friendUids.length; i += batchLimit) {
        final slice = friendUids.sublist(
          i,
          i + batchLimit > friendUids.length
              ? friendUids.length
              : i + batchLimit,
        );

        final batch = _firestore.batch();
        for (final friendUid in slice) {
          final friendDocRef = _usersCollection
              .doc(friendUid)
              .collection('friends')
              .doc(currentUid);
          // 존재하지 않을 수도 있으므로 set(merge) 사용
          batch.set(friendDocRef, {
            'profileImageUrl': newProfileImageUrl,
            'lastInteraction': Timestamp.now(), // 변동 트리거 용도
          }, SetOptions(merge: true));
        }
        await batch.commit();
      }
    } catch (e) {
      // 실패는 치명적이지 않으므로 throw 대신 무시 / 필요하면 로그 처리
      // print('프로필 이미지 전파 실패: $e');
    }
  }

  /// 카테고리 추가 가능 여부 확인
  Future<bool> canAddToCategory(String requesterId, String targetId) async {
    try {
      // 1. requester가 target을 삭제했는지 확인
      final requesterFriend = await getFriend(targetId);
      if (requesterFriend == null) {
        debugPrint('❌ requester가 target을 삭제함: $requesterId -> $targetId');
        return false; // 삭제했거나 원래 친구 아님
      }

      // 2. requester가 target을 차단했는지 확인
      if (requesterFriend.status == FriendStatus.blocked) {
        debugPrint('❌ requester가 target을 차단함: $requesterId -> $targetId');
        return false;
      }

      // 3. target이 requester를 차단했는지 확인 (양방향 차단)
      final targetFriend = await getTargetUserFriend(requesterId, targetId);
      if (targetFriend?.status == FriendStatus.blocked) {
        debugPrint('❌ target이 requester를 차단함: $targetId -> $requesterId');
        return false;
      }

      debugPrint('✅ 카테고리 추가 가능: $requesterId -> $targetId');
      return true;
    } catch (e) {
      debugPrint('⚠️ canAddToCategory 에러: $e');
      return false; // 안전하게 false 반환
    }
  }

  /// 카테고리 추가 불가 이유 반환
  Future<String?> getCannotAddReason(
    String requesterId,
    String targetId,
  ) async {
    try {
      final requesterFriend = await getFriend(targetId);

      if (requesterFriend == null) {
        return '삭제된 친구는 카테고리에 추가할 수 없습니다.';
      }

      if (requesterFriend.status == FriendStatus.blocked) {
        return '차단된 친구는 카테고리에 추가할 수 없습니다.';
      }

      // target이 requester를 차단했는지 확인
      final targetFriend = await getTargetUserFriend(requesterId, targetId);
      if (targetFriend?.status == FriendStatus.blocked) {
        return '이 사용자가 회원님을 차단하여 카테고리에 추가할 수 없습니다.';
      }

      return null; // 추가 가능
    } catch (e) {
      return '확인 중 오류가 발생했습니다.';
    }
  }

  /// 다른 사용자 관점에서 친구 정보 조회
  Future<FriendModel?> getTargetUserFriend(
    String requesterId,
    String targetId,
  ) async {
    try {
      final doc =
          await _usersCollection
              .doc(targetId) // target 사용자의
              .collection('friends') // friends 컬렉션에서
              .doc(requesterId) // requester에 대한 친구 정보 조회
              .get();

      return doc.exists ? FriendModel.fromFirestore(doc) : null;
    } catch (e) {
      debugPrint('_getTargetUserFriend 에러: $e');
      return null;
    }
  }

  /// 특정 사용자의 친구 ID 목록 조회
  Future<Set<String>> getFriendIdsForUser(String userId) async {
    if (userId.isEmpty) {
      return {};
    }

    try {
      final snapshot =
          await _usersCollection
              .doc(userId)
              .collection('friends')
              .where('status', isEqualTo: FriendStatus.active.value)
              .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      debugPrint('친구 ID 목록 조회 실패 ($userId): $e');
      return {};
    }
  }

  /// 현재 사용자가 차단한 사용자 목록 조회
  Future<List<String>> getBlockedUsers() async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      return [];
    }

    try {
      final snapshot =
          await _usersCollection
              .doc(currentUid)
              .collection('friends')
              .where('status', isEqualTo: 'blocked')
              .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('차단한 사용자 목록 조회 실패: $e');
      return [];
    }
  }

  /// 특정 사용자가 나를 차단했는지 확인 (간접 추정)
  Future<bool> amIBlockedBy(String targetUserId) async {
    try {
      final theirFriend = await getTargetUserFriend(
        _currentUserUid!,
        targetUserId,
      );
      return theirFriend?.status == FriendStatus.blocked;
    } catch (e) {
      debugPrint('차단 상태 확인 실패: $e');
      return false;
    }
  }

  /// 나를 차단한 사용자 목록 조회
  Future<List<String>> getUsersWhoBlockedMe() async {
    final currentUid = _currentUserUid;
    if (currentUid == null) {
      return [];
    }

    try {
      // 현재 사용자의 친구 목록을 조회
      final myFriends = await getFriendsList().first;
      final usersWhoBlockedMe = <String>[];

      // 각 친구에 대해 역방향 관계 확인
      for (final friend in myFriends) {
        try {
          final theirFriendData = await getTargetUserFriend(
            currentUid,
            friend.userId,
          );

          // 상대방이 나를 차단한 상태인지 확인
          if (theirFriendData?.status == FriendStatus.blocked) {
            usersWhoBlockedMe.add(friend.userId);
          }
        } catch (e) {
          // 개별 사용자 확인 실패는 무시하고 계속 진행
          debugPrint('사용자 ${friend.userId} 차단 상태 확인 실패: $e');
        }
      }

      return usersWhoBlockedMe;
    } catch (e) {
      debugPrint('나를 차단한 사용자 목록 조회 실패: $e');
      return [];
    }
  }
}
