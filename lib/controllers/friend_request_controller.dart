import 'dart:async';
import 'package:flutter/material.dart';
import '../models/friend_request_model.dart';
import '../services/friend_request_service.dart';
import '../controllers/contact_controller.dart';

/// 친구 요청 관련 UI와 비즈니스 로직 사이의 중개 역할을 합니다.
/// Provider + ChangeNotifier 패턴을 사용하여 상태 관리
/// ContactController와 연동하여 연락처 기반 친구 추천 제공
class FriendRequestController extends ChangeNotifier {
  // 상태 변수들
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isGeneratingSuggestions = false;
  String? _error;

  // 친구 요청 관련 상태
  List<FriendRequestModel> _receivedRequests = [];
  List<FriendRequestModel> _sentRequests = [];
  List<FriendSuggestionModel> _friendSuggestions = [];
  List<FriendModel> _friends = [];

  // 검색 및 필터 상태
  String _searchQuery = '';
  bool _contactSyncEnabled = false;

  // 스트림 구독 관리
  StreamSubscription<List<FriendRequestModel>>? _receivedRequestsSubscription;
  StreamSubscription<List<FriendRequestModel>>? _sentRequestsSubscription;
  StreamSubscription<List<FriendModel>>? _friendsSubscription;

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final FriendRequestService _friendRequestService = FriendRequestService();

  // 기존 ContactController와의 연동을 위한 참조
  ContactController? _contactController;

  // Getters
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isGeneratingSuggestions => _isGeneratingSuggestions;
  String? get error => _error;
  List<FriendRequestModel> get receivedRequests => _receivedRequests;
  List<FriendRequestModel> get sentRequests => _sentRequests;
  List<FriendSuggestionModel> get friendSuggestions => _friendSuggestions;
  List<FriendModel> get friends => _friends;
  String get searchQuery => _searchQuery;
  bool get contactSyncEnabled => _contactSyncEnabled;

  // 추가 상태 확인 getters
  bool get hasReceivedRequests => _receivedRequests.isNotEmpty;
  bool get hasSentRequests => _sentRequests.isNotEmpty;
  bool get hasFriendSuggestions => _friendSuggestions.isNotEmpty;
  bool get hasFriends => _friends.isNotEmpty;
  int get totalReceivedRequests => _receivedRequests.length;
  int get totalSentRequests => _sentRequests.length;

  // ContactController 연동 getters
  bool get hasContactPermission =>
      _contactController?.isContactSyncEnabled ?? false;
  bool get isContactPermissionDenied =>
      _contactController?.permissionDenied ?? true;

  // ==================== 초기화 ====================

  /// Controller 초기화 (ContactController와 연동)
  Future<void> initialize(
    String userId, {
    ContactController? contactController,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🚀 FriendRequestController 초기화 시작: $userId');

      // ContactController 연동 설정
      if (contactController != null) {
        _contactController = contactController;
        _contactSyncEnabled = contactController.isContactSyncEnabled;
        debugPrint(
          '📱 연락처 컨트롤러 연동 완료: 동기화 ${_contactSyncEnabled ? "활성화" : "비활성화"}',
        );
      }

      // 1. 기본 데이터 로드
      await loadAllData(userId);

      // 2. 실시간 스트림 시작
      startRealTimeStreams(userId);

      // 3. 연락처 권한이 있으면 친구 추천 생성 (백그라운드)
      if (_contactSyncEnabled) {
        generateFriendSuggestions(userId);
      } else {
        debugPrint('📱 연락처 권한이 없어 친구 추천을 생성하지 않습니다.');
      }

      _isLoading = false;
      notifyListeners();

      debugPrint('✅ FriendRequestController 초기화 완료');
    } catch (e) {
      debugPrint('❌ FriendRequestController 초기화 실패: $e');
      _isLoading = false;
      _error = '친구 시스템 초기화 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// ContactController 연동 설정
  void setContactController(ContactController contactController) {
    _contactController = contactController;
    _contactSyncEnabled = contactController.isContactSyncEnabled;
    notifyListeners();
    debugPrint('📱 연락처 컨트롤러 연동 설정 완료');
  }

  /// 모든 데이터 로드
  Future<void> loadAllData(String userId) async {
    try {
      debugPrint('📊 모든 친구 데이터 로드 시작');

      // 병렬 로드로 성능 최적화
      final futures = await Future.wait([
        _friendRequestService.getReceivedRequests(userId),
        _friendRequestService.getSentRequests(userId),
        _friendRequestService.getFriends(userId),
        _friendRequestService.getFriendSuggestions(userId),
      ]);

      _receivedRequests = futures[0] as List<FriendRequestModel>;
      _sentRequests = futures[1] as List<FriendRequestModel>;
      _friends = futures[2] as List<FriendModel>;
      _friendSuggestions = futures[3] as List<FriendSuggestionModel>;

      debugPrint('📈 데이터 로드 완료:');
      debugPrint('  - 받은 요청: ${_receivedRequests.length}개');
      debugPrint('  - 보낸 요청: ${_sentRequests.length}개');
      debugPrint('  - 친구: ${_friends.length}명');
      debugPrint('  - 추천: ${_friendSuggestions.length}개');

      notifyListeners();
    } catch (e) {
      debugPrint('❌ 데이터 로드 실패: $e');
      _error = '데이터 로드 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// 실시간 스트림 시작
  void startRealTimeStreams(String userId) {
    try {
      debugPrint('🔄 실시간 스트림 시작');

      // 받은 친구 요청 스트림
      _receivedRequestsSubscription?.cancel();
      _receivedRequestsSubscription = _friendRequestService
          .getReceivedRequestsStream(userId)
          .listen(
            (requests) {
              _receivedRequests = requests;
              notifyListeners();
              debugPrint('📥 받은 요청 업데이트: ${requests.length}개');
            },
            onError: (error) {
              debugPrint('❌ 받은 요청 스트림 오류: $error');
            },
          );

      // 보낸 친구 요청 스트림
      _sentRequestsSubscription?.cancel();
      _sentRequestsSubscription = _friendRequestService
          .getSentRequestsStream(userId)
          .listen(
            (requests) {
              _sentRequests = requests;
              notifyListeners();
              debugPrint('📤 보낸 요청 업데이트: ${requests.length}개');
            },
            onError: (error) {
              debugPrint('❌ 보낸 요청 스트림 오류: $error');
            },
          );

      // 친구 목록 스트림
      _friendsSubscription?.cancel();
      _friendsSubscription = _friendRequestService
          .getFriendsStream(userId)
          .listen(
            (friends) {
              _friends = friends;
              notifyListeners();
              debugPrint('👥 친구 목록 업데이트: ${friends.length}명');
            },
            onError: (error) {
              debugPrint('❌ 친구 목록 스트림 오류: $error');
            },
          );
    } catch (e) {
      debugPrint('❌ 스트림 시작 실패: $e');
    }
  }

  /// 실시간 스트림 중지
  void stopRealTimeStreams() {
    _receivedRequestsSubscription?.cancel();
    _sentRequestsSubscription?.cancel();
    _friendsSubscription?.cancel();
    debugPrint('🛑 실시간 스트림 중지 완료');
  }

  // ==================== 연락처 동기화 관련 ====================

  /// 연락처 권한 요청 및 동기화
  Future<bool> requestContactPermissionAndSync(String userId) async {
    try {
      _isSyncing = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 연락처 권한 요청 시작');

      // ContactController가 연결되어 있으면 연락처 권한 요청
      if (_contactController != null) {
        await _contactController!.requestContactPermission();

        // 권한 상태 업데이트
        _contactSyncEnabled = _contactController!.isContactSyncEnabled;

        if (_contactSyncEnabled) {
          debugPrint('✅ 연락처 권한 허용됨 - 친구 추천 생성 시작');

          // 연락처 동기화 후 친구 추천 생성
          await generateFriendSuggestions(userId, forceRefresh: true);

          _isSyncing = false;
          notifyListeners();
          return true;
        } else {
          debugPrint('❌ 연락처 권한 거부됨');
          _error = '연락처 권한이 필요합니다. 설정에서 허용해주세요.';
          _isSyncing = false;
          notifyListeners();
          return false;
        }
      } else {
        debugPrint('❌ ContactController가 연결되지 않음');
        _error = '연락처 시스템이 초기화되지 않았습니다.';
        _isSyncing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ 연락처 권한 요청 실패: $e');
      _error = '연락처 권한 요청 중 오류가 발생했습니다.';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// 연락처 동기화 토글
  Future<void> toggleContactSync(String userId) async {
    if (_contactSyncEnabled) {
      // 동기화 비활성화
      _contactSyncEnabled = false;
      _friendSuggestions.clear();
      notifyListeners();
      debugPrint('📱 연락처 동기화 비활성화');
    } else {
      // 동기화 활성화 시도
      await requestContactPermissionAndSync(userId);
    }
  }

  /// 설정 앱 열기 (연락처 권한 설정)
  Future<void> openContactSettings() async {
    if (_contactController != null) {
      await _contactController!.openAppSettings();
    }
  }

  // ==================== 친구 요청 보내기 ====================

  /// 전화번호로 친구 요청 보내기
  Future<bool> sendFriendRequestByPhone({
    required String fromUserId,
    required String fromUserNickname,
    required String phoneNumber,
    String? message,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📞 전화번호로 친구 요청: $phoneNumber');

      final result = await _friendRequestService.sendFriendRequestByPhone(
        fromUserId: fromUserId,
        fromUserNickname: fromUserNickname,
        phoneNumber: phoneNumber,
        message: message,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        debugPrint('✅ 친구 요청 전송 성공');
        return true;
      } else {
        _error = result.error;
        debugPrint('❌ 친구 요청 전송 실패: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 친구 요청 전송 중 오류: $e');
      _isLoading = false;
      _error = '친구 요청 전송 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 닉네임으로 친구 요청 보내기
  Future<bool> sendFriendRequestByNickname({
    required String fromUserId,
    required String fromUserNickname,
    required String targetNickname,
    String? message,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🔍 닉네임으로 친구 요청: $targetNickname');

      final result = await _friendRequestService.sendFriendRequestByNickname(
        fromUserId: fromUserId,
        fromUserNickname: fromUserNickname,
        targetNickname: targetNickname,
        message: message,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        debugPrint('✅ 친구 요청 전송 성공');
        return true;
      } else {
        _error = result.error;
        debugPrint('❌ 친구 요청 전송 실패: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 친구 요청 전송 중 오류: $e');
      _isLoading = false;
      _error = '친구 요청 전송 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 추천을 통한 친구 요청 보내기
  Future<bool> sendFriendRequestFromSuggestion({
    required String fromUserId,
    required String fromUserNickname,
    required FriendSuggestionModel suggestion,
    String? message,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('💡 추천을 통한 친구 요청: ${suggestion.nickname}');

      final result = await _friendRequestService
          .sendFriendRequestFromSuggestion(
            fromUserId: fromUserId,
            fromUserNickname: fromUserNickname,
            suggestion: suggestion,
            message: message,
          );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 성공 시 추천 목록에서 제거
        _friendSuggestions.removeWhere((s) => s.userId == suggestion.userId);
        notifyListeners();

        debugPrint('✅ 친구 요청 전송 성공');
        return true;
      } else {
        _error = result.error;
        debugPrint('❌ 친구 요청 전송 실패: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 친구 요청 전송 중 오류: $e');
      _isLoading = false;
      _error = '친구 요청 전송 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  // ==================== 친구 요청 응답 ====================

  /// 친구 요청 수락
  Future<bool> acceptFriendRequest({
    required String requestId,
    required String respondingUserId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('✅ 친구 요청 수락: $requestId');

      final result = await _friendRequestService.respondToFriendRequest(
        requestId: requestId,
        status: FriendRequestStatus.accepted,
        respondingUserId: respondingUserId,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        debugPrint('✅ 친구 요청 수락 완료');

        // 친구 추천 목록 새로고침 (새 친구가 추가되었으므로)
        if (_contactSyncEnabled) {
          generateFriendSuggestions(respondingUserId, forceRefresh: true);
        }

        return true;
      } else {
        _error = result.error;
        debugPrint('❌ 친구 요청 수락 실패: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 친구 요청 수락 중 오류: $e');
      _isLoading = false;
      _error = '친구 요청 수락 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 친구 요청 거절
  Future<bool> rejectFriendRequest({
    required String requestId,
    required String respondingUserId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('❌ 친구 요청 거절: $requestId');

      final result = await _friendRequestService.respondToFriendRequest(
        requestId: requestId,
        status: FriendRequestStatus.rejected,
        respondingUserId: respondingUserId,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        debugPrint('✅ 친구 요청 거절 완료');
        return true;
      } else {
        _error = result.error;
        debugPrint('❌ 친구 요청 거절 실패: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 친구 요청 거절 중 오류: $e');
      _isLoading = false;
      _error = '친구 요청 거절 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 친구 요청 취소
  Future<bool> cancelFriendRequest({
    required String requestId,
    required String cancellingUserId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🚫 친구 요청 취소: $requestId');

      final result = await _friendRequestService.cancelFriendRequest(
        requestId: requestId,
        cancellingUserId: cancellingUserId,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        debugPrint('✅ 친구 요청 취소 완료');
        return true;
      } else {
        _error = result.error;
        debugPrint('❌ 친구 요청 취소 실패: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 친구 요청 취소 중 오류: $e');
      _isLoading = false;
      _error = '친구 요청 취소 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  // ==================== 친구 추천 관리 ====================

  /// 친구 추천 생성 (연락처 기반)
  Future<void> generateFriendSuggestions(
    String userId, {
    bool forceRefresh = false,
  }) async {
    try {
      // 연락처 권한이 없으면 실행하지 않음
      if (!_contactSyncEnabled) {
        debugPrint('📱 연락처 동기화가 비활성화되어 친구 추천을 생성하지 않습니다.');
        return;
      }

      _isGeneratingSuggestions = true;
      if (forceRefresh) {
        _error = null;
      }
      notifyListeners();

      debugPrint('🔮 친구 추천 생성 시작 (forceRefresh: $forceRefresh)');

      final suggestions = await _friendRequestService.generateFriendSuggestions(
        userId,
        forceRefresh: forceRefresh,
      );

      _friendSuggestions = suggestions;
      _isGeneratingSuggestions = false;
      notifyListeners();

      debugPrint('✅ 친구 추천 생성 완료: ${suggestions.length}개');
    } catch (e) {
      debugPrint('❌ 친구 추천 생성 실패: $e');
      _isGeneratingSuggestions = false;
      if (forceRefresh) {
        _error = '친구 추천을 불러오는 중 오류가 발생했습니다.';
      }
      notifyListeners();
    }
  }

  /// 친구 추천 새로고침
  Future<void> refreshFriendSuggestions(String userId) async {
    if (!_contactSyncEnabled) {
      debugPrint('📱 연락처 동기화가 비활성화되어 친구 추천을 새로고침하지 않습니다.');
      return;
    }
    await generateFriendSuggestions(userId, forceRefresh: true);
  }

  /// 특정 추천 제거
  Future<bool> removeSuggestion(String userId, String targetUserId) async {
    try {
      final success = await _friendRequestService.removeSuggestion(
        userId,
        targetUserId,
      );

      if (success) {
        _friendSuggestions.removeWhere((s) => s.userId == targetUserId);
        notifyListeners();
        debugPrint('✅ 추천 제거 완료: $targetUserId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ 추천 제거 실패: $e');
      return false;
    }
  }

  // ==================== 친구 관리 ====================

  /// 친구 삭제
  Future<bool> removeFriend(String userId, String friendUserId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🗑️ 친구 삭제: $friendUserId');

      final success = await _friendRequestService.removeFriend(
        userId,
        friendUserId,
      );

      _isLoading = false;
      notifyListeners();

      if (success) {
        debugPrint('✅ 친구 삭제 완료');

        // 친구 추천 목록 새로고침 (친구가 삭제되었으므로 다시 추천될 수 있음)
        if (_contactSyncEnabled) {
          generateFriendSuggestions(userId, forceRefresh: true);
        }

        return true;
      } else {
        _error = '친구 삭제에 실패했습니다.';
        debugPrint('❌ 친구 삭제 실패');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 친구 삭제 중 오류: $e');
      _isLoading = false;
      _error = '친구 삭제 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 친구 관계 상태 확인
  Future<FriendshipStatus> getFriendshipStatus(
    String currentUserId,
    String targetUserId,
  ) async {
    try {
      return await _friendRequestService.getFriendshipStatus(
        currentUserId,
        targetUserId,
      );
    } catch (e) {
      debugPrint('❌ 친구 관계 상태 확인 실패: $e');
      return FriendshipStatus.none;
    }
  }

  // ==================== 검색 및 필터링 ====================

  /// 검색어 설정
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// 검색어 초기화
  void clearSearchQuery() {
    _searchQuery = '';
    notifyListeners();
  }

  /// 연락처 동기화 설정
  void setContactSyncEnabled(bool enabled) {
    _contactSyncEnabled = enabled;
    notifyListeners();
  }

  // ==================== 필터링된 데이터 제공 ====================

  /// 검색어로 필터링된 받은 요청
  List<FriendRequestModel> get filteredReceivedRequests {
    if (_searchQuery.isEmpty) return _receivedRequests;

    return _receivedRequests
        .where(
          (request) => request.fromUserNickname.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  /// 검색어로 필터링된 보낸 요청
  List<FriendRequestModel> get filteredSentRequests {
    if (_searchQuery.isEmpty) return _sentRequests;

    return _sentRequests
        .where(
          (request) => request.toUserNickname.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  /// 검색어로 필터링된 친구 목록
  List<FriendModel> get filteredFriends {
    if (_searchQuery.isEmpty) return _friends;

    return _friends
        .where(
          (friend) => friend.nickname.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  /// 검색어로 필터링된 친구 추천
  List<FriendSuggestionModel> get filteredFriendSuggestions {
    if (_searchQuery.isEmpty) return _friendSuggestions;

    return _friendSuggestions
        .where(
          (suggestion) => suggestion.nickname.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  // ==================== 유틸리티 메서드 ====================

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 특정 사용자의 요청 찾기
  FriendRequestModel? findRequestFromUser(String fromUserId) {
    try {
      return _receivedRequests.firstWhere(
        (request) => request.fromUserId == fromUserId,
      );
    } catch (e) {
      return null;
    }
  }

  /// 특정 사용자에게 보낸 요청 찾기
  FriendRequestModel? findRequestToUser(String toUserId) {
    try {
      return _sentRequests.firstWhere(
        (request) => request.toUserId == toUserId,
      );
    } catch (e) {
      return null;
    }
  }

  /// 특정 사용자가 친구인지 확인
  bool isFriend(String userId) {
    return _friends.any((friend) => friend.userId == userId);
  }

  /// 특정 사용자가 추천 목록에 있는지 확인
  bool isInSuggestions(String userId) {
    return _friendSuggestions.any((suggestion) => suggestion.userId == userId);
  }

  /// 강제 새로고침 (모든 데이터)
  Future<void> forceRefresh(String userId) async {
    try {
      debugPrint('🔄 전체 데이터 강제 새로고침');

      _isLoading = true;
      _error = null;
      notifyListeners();

      // 병렬로 모든 데이터 새로고침
      await Future.wait([
        loadAllData(userId),
        if (_contactSyncEnabled) refreshFriendSuggestions(userId),
      ]);

      _isLoading = false;
      notifyListeners();

      debugPrint('✅ 전체 데이터 새로고침 완료');
    } catch (e) {
      debugPrint('❌ 전체 데이터 새로고침 실패: $e');
      _isLoading = false;
      _error = '데이터 새로고침 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// 연락처 기반 친구 추천 통계
  Map<String, dynamic> get friendSuggestionStats {
    final totalSuggestions = _friendSuggestions.length;
    final contactBasedCount =
        _friendSuggestions
            .where((s) => s.reasons.contains('연락처에 저장된 친구'))
            .length;

    return {
      'total': totalSuggestions,
      'contactBased': contactBasedCount,
      'otherBased': totalSuggestions - contactBasedCount,
      'hasContactSync': _contactSyncEnabled,
    };
  }

  // ==================== 리소스 해제 ====================

  @override
  void dispose() {
    debugPrint('🔄 FriendRequestController dispose 시작');

    // 스트림 구독 해제
    stopRealTimeStreams();

    // ContactController 참조 해제
    _contactController = null;

    super.dispose();

    debugPrint('✅ FriendRequestController dispose 완료');
  }
}
