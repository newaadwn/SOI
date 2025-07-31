import '../repositories/friend_repository.dart';
import '../repositories/user_search_repository.dart';
import '../models/friend_model.dart';

/// 친구 관리 Service 클래스
/// Repository들을 조합하여 친구 관련 고급 기능 제공
class FriendService {
  final FriendRepository _friendRepository;
  final UserSearchRepository _userSearchRepository;

  FriendService({
    required FriendRepository friendRepository,
    required UserSearchRepository userSearchRepository,
  }) : _friendRepository = friendRepository,
       _userSearchRepository = userSearchRepository;

  /// 친구 목록 조회 (실시간)
  Stream<List<FriendModel>> getFriendsList() {
    return _friendRepository.getFriendsList();
  }

  /// 즐겨찾기 친구 목록 조회 (실시간)
  Stream<List<FriendModel>> getFavoriteFriendsList() {
    return _friendRepository.getFavoriteFriendsList();
  }

  /// 친구 삭제 (확인 절차 포함)
  ///
  /// [friendUid] 삭제할 친구의 UID
  Future<void> removeFriend(String friendUid) async {
    try {
      // 1. 친구 관계 확인
      final friend = await _friendRepository.getFriend(friendUid);
      if (friend == null) {
        throw Exception('친구 관계가 존재하지 않습니다');
      }

      if (friend.status == FriendStatus.blocked) {
        throw Exception('차단된 사용자입니다');
      }

      // 2. 친구 삭제 실행
      await _friendRepository.removeFriend(friendUid);
    } catch (e) {
      throw Exception('친구 삭제 실패: $e');
    }
  }

  /// 친구 차단
  ///
  /// [friendUid] 차단할 친구의 UID
  Future<void> blockFriend(String friendUid) async {
    try {
      // 1. 친구 관계 확인
      final friend = await _friendRepository.getFriend(friendUid);
      if (friend == null) {
        throw Exception('친구 관계가 존재하지 않습니다');
      }

      if (friend.status == FriendStatus.blocked) {
        throw Exception('이미 차단된 사용자입니다');
      }

      // 2. 친구 차단 실행
      await _friendRepository.blockFriend(friendUid);
    } catch (e) {
      throw Exception('친구 차단 실패: $e');
    }
  }

  /// 친구 차단 해제
  ///
  /// [friendUid] 차단 해제할 친구의 UID
  Future<void> unblockFriend(String friendUid) async {
    try {
      // 1. 친구 관계 확인
      final friend = await _friendRepository.getFriend(friendUid);
      if (friend == null) {
        throw Exception('친구 관계가 존재하지 않습니다');
      }

      if (friend.status != FriendStatus.blocked) {
        throw Exception('차단된 사용자가 아닙니다');
      }

      // 2. 친구 차단 해제 실행
      await _friendRepository.unblockFriend(friendUid);
    } catch (e) {
      throw Exception('친구 차단 해제 실패: $e');
    }
  }

  /// 친구 즐겨찾기 토글
  ///
  /// [friendUid] 즐겨찾기 설정할 친구의 UID
  Future<void> toggleFriendFavorite(String friendUid) async {
    try {
      // 1. 현재 즐겨찾기 상태 확인
      final friend = await _friendRepository.getFriend(friendUid);
      if (friend == null) {
        throw Exception('친구 관계가 존재하지 않습니다');
      }

      if (friend.status != FriendStatus.active) {
        throw Exception('활성 상태가 아닌 친구입니다');
      }

      // 2. 즐겨찾기 상태 토글
      await _friendRepository.setFriendFavorite(friendUid, !friend.isFavorite);
    } catch (e) {
      throw Exception('즐겨찾기 설정 실패: $e');
    }
  }

  /// 친구 검색 (고급)
  ///
  /// [query] 검색 쿼리
  /// [includeBlocked] 차단된 친구 포함 여부
  Future<List<FriendModel>> searchFriends(
    String query, {
    bool includeBlocked = false,
  }) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final results = await _friendRepository.searchFriends(query);

      // 차단된 친구 필터링
      if (!includeBlocked) {
        return results
            .where((friend) => friend.status == FriendStatus.active)
            .toList();
      }

      return results;
    } catch (e) {
      throw Exception('친구 검색 실패: $e');
    }
  }

  /// 친구 정보 동기화 (프로필 변경사항 반영)
  ///
  /// [friendUid] 동기화할 친구의 UID
  Future<void> syncFriendInfo(String friendUid) async {
    try {
      // 1. 최신 사용자 정보 조회
      final userInfo = await _userSearchRepository.searchUserById(friendUid);
      if (userInfo == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      // 2. 친구 정보 업데이트
      await _friendRepository.updateFriend(friendUid, {
        'nickname': userInfo.id,
        'name': userInfo.name,
        'profileImageUrl': userInfo.profileImageUrl,
      });
    } catch (e) {
      throw Exception('친구 정보 동기화 실패: $e');
    }
  }

  /// 모든 친구 정보 일괄 동기화
  Future<void> syncAllFriendsInfo() async {
    try {
      final friends = await _friendRepository.getFriendsList().first;

      for (final friend in friends) {
        try {
          await syncFriendInfo(friend.userId);

          // API 요청 제한을 피하기 위한 지연
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          // 개별 친구 동기화 실패는 무시하고 계속 진행
          // print('친구 ${friend.id} 정보 동기화 실패: $e');
        }
      }
    } catch (e) {
      throw Exception('전체 친구 정보 동기화 실패: $e');
    }
  }

  /// 친구 활동 기록 업데이트
  ///
  /// [friendUid] 상호작용한 친구의 UID
  Future<void> recordFriendInteraction(String friendUid) async {
    try {
      await _friendRepository.updateLastInteraction(friendUid);
    } catch (e) {
      // 상호작용 기록 실패는 중요하지 않으므로 로그만 출력
      // print('친구 상호작용 기록 실패: $e');
    }
  }

  /// 친구 통계 정보
  ///
  /// Returns: Map with various friend statistics
  Future<Map<String, dynamic>> getFriendStats() async {
    try {
      final totalFriends = await _friendRepository.getFriendsCount();
      final favoriteFriends =
          await _friendRepository.getFavoriteFriendsList().first;
      final allFriends = await _friendRepository.getFriendsList().first;

      final blockedFriends =
          allFriends
              .where((friend) => friend.status == FriendStatus.blocked)
              .length;

      final activeFriends = totalFriends - blockedFriends;

      // 최근 추가된 친구 (7일 이내)
      final recentlyAdded =
          allFriends.where((friend) {
            final daysDiff = DateTime.now().difference(friend.addedAt).inDays;
            return daysDiff <= 7;
          }).length;

      return {
        'total': totalFriends,
        'active': activeFriends,
        'blocked': blockedFriends,
        'favorite': favoriteFriends.length,
        'recentlyAdded': recentlyAdded,
      };
    } catch (e) {
      return {
        'total': 0,
        'active': 0,
        'blocked': 0,
        'favorite': 0,
        'recentlyAdded': 0,
      };
    }
  }

  /// 친구 그룹 분류
  ///
  /// Returns: Map with categorized friends
  Future<Map<String, List<FriendModel>>> getCategorizedFriends() async {
    try {
      final allFriends = await _friendRepository.getFriendsList().first;

      final Map<String, List<FriendModel>> categories = {
        'favorites': [],
        'recent': [],
        'frequent': [],
        'others': [],
      };

      final now = DateTime.now();

      for (final friend in allFriends) {
        if (friend.status != FriendStatus.active) continue;

        // 즐겨찾기
        if (friend.isFavorite) {
          categories['favorites']!.add(friend);
          continue;
        }

        // 최근 추가 (7일 이내)
        final daysSinceAdded = now.difference(friend.addedAt).inDays;
        if (daysSinceAdded <= 7) {
          categories['recent']!.add(friend);
          continue;
        }

        // 자주 상호작용 (30일 이내)
        if (friend.lastInteraction != null) {
          final daysSinceInteraction =
              now.difference(friend.lastInteraction!).inDays;
          if (daysSinceInteraction <= 30) {
            categories['frequent']!.add(friend);
            continue;
          }
        }

        // 기타
        categories['others']!.add(friend);
      }

      return categories;
    } catch (e) {
      return {'favorites': [], 'recent': [], 'frequent': [], 'others': []};
    }
  }
}
