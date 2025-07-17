import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/friend_request_model.dart';
import '../services/friend_request_service.dart';
import '../repositories/auth_repository.dart';

/// 친구 요청 관련 UI와 비즈니스 로직 사이의 중개 역할을 합니다.
/// Provider + ChangeNotifier 패턴을 사용하여 상태 관리
/// 단순한 연락처 목록 표시 및 친구 추가 기능 제공
class FriendRequestController extends ChangeNotifier {
  // 상태 변수들
  bool _isLoading = false;
  bool _isLoadingContacts = false;
  String? _error;
  String? _successMessage;
  bool _hasContactPermission = false;

  // 친구 요청 관련 상태
  List<FriendRequestModel> _receivedRequests = [];
  List<FriendRequestModel> _sentRequests = [];
  List<FriendModel> _friends = [];

  // 연락처 목록 (새로운 단순한 방식)
  List<ContactItem> _contactList = [];

  // 검색 및 필터 상태
  String _searchQuery = '';

  // 스트림 구독 관리
  StreamSubscription<List<FriendRequestModel>>? _receivedRequestsSubscription;
  StreamSubscription<List<FriendRequestModel>>? _sentRequestsSubscription;
  StreamSubscription<List<FriendModel>>? _friendsSubscription;

  // Service 인스턴스
  final FriendRequestService _friendRequestService = FriendRequestService();
  final AuthRepository _authRepository = AuthRepository();

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingContacts => _isLoadingContacts;
  String? get error => _error;
  String? get successMessage => _successMessage;
  List<FriendRequestModel> get receivedRequests => _receivedRequests;
  List<FriendRequestModel> get sentRequests => _sentRequests;
  List<FriendModel> get friends => _friends;
  List<ContactItem> get contactList => _contactList; // 새로운 연락처 목록
  String get searchQuery => _searchQuery;
  bool get hasContactPermission => _hasContactPermission;

  // 추가 상태 확인 getters
  bool get hasReceivedRequests => _receivedRequests.isNotEmpty;
  bool get hasSentRequests => _sentRequests.isNotEmpty;
  bool get hasContacts => _contactList.isNotEmpty;
  bool get hasFriends => _friends.isNotEmpty;
  int get totalReceivedRequests => _receivedRequests.length;
  int get totalSentRequests => _sentRequests.length;
  int get totalContacts => _contactList.length;

  // ==================== 권한 관리 ====================

  /// 연락처 권한 상태를 확인하고 업데이트
  Future<bool> checkContactPermission() async {
    try {
      final status = await Permission.contacts.status;
      final hasPermission = status.isGranted || status.isLimited;

      if (_hasContactPermission != hasPermission) {
        _hasContactPermission = hasPermission;
        debugPrint('📱 연락처 권한 상태 변경: $_hasContactPermission');
        notifyListeners();
      }

      return _hasContactPermission;
    } catch (e) {
      debugPrint('❌ 연락처 권한 확인 실패: $e');
      _hasContactPermission = false;
      notifyListeners();
      return false;
    }
  }

  /// 연락처 권한 요청
  Future<bool> requestContactPermission() async {
    try {
      debugPrint('📱 연락처 권한 요청 시작');

      // 먼저 현재 권한 상태를 확인
      final currentStatus = await Permission.contacts.status;
      debugPrint('📱 현재 권한 상태: $currentStatus');

      if (currentStatus.isPermanentlyDenied) {
        // 영구적으로 거부된 경우, 설정 앱으로 이동해야 함
        debugPrint('❌ 권한이 영구적으로 거부됨 - 설정 앱으로 이동 필요');
        _hasContactPermission = false;
        _error = '연락처 권한이 거부되었습니다. 설정에서 권한을 허용해주세요.';
        notifyListeners();
        return false;
      }

      final status = await Permission.contacts.request();
      _hasContactPermission = status.isGranted || status.isLimited;

      debugPrint('📱 권한 요청 결과: $_hasContactPermission (status: $status)');

      if (status.isPermanentlyDenied) {
        _error = '연락처 권한이 거부되었습니다. 설정에서 권한을 허용해주세요.';
      } else if (!_hasContactPermission) {
        _error = '연락처 권한이 필요합니다.';
      } else {
        _error = null;
      }

      notifyListeners();
      return _hasContactPermission;
    } catch (e) {
      debugPrint('❌ 연락처 권한 요청 실패: $e');
      _hasContactPermission = false;
      _error = '연락처 권한 요청 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 설정 앱으로 이동하여 권한 설정 변경
  Future<bool> openAppSettings() async {
    try {
      debugPrint('📱 설정 앱 열기 시도');

      // permission_handler의 openAppSettings 사용
      final success = await Permission.contacts.request();

      if (success.isGranted || success.isLimited) {
        debugPrint('✅ 설정 앱 열기 성공');
        // 설정 앱에서 돌아온 후 권한 상태 재확인
        await Future.delayed(const Duration(milliseconds: 500));
        await checkContactPermission();
        return true;
      } else {
        debugPrint('❌ 설정 앱 열기 실패');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 설정 앱 열기 오류: $e');
      return false;
    }
  }

  /// 권한 상태가 영구적으로 거부되었는지 확인
  Future<bool> get isPermissionPermanentlyDenied async {
    try {
      final status = await Permission.contacts.status;
      return status.isPermanentlyDenied;
    } catch (e) {
      debugPrint('❌ 권한 상태 확인 실패: $e');
      return false;
    }
  }

  // ==================== 연락처 관리 ====================

  /// 연락처 목록 로드 (단순한 방식)
  Future<void> loadContactList() async {
    try {
      _isLoadingContacts = true;
      _error = null;
      notifyListeners();

      debugPrint('📱 연락처 목록 로드 시작');

      // 권한 확인
      if (!await checkContactPermission()) {
        debugPrint('❌ 연락처 권한이 없습니다');
        _isLoadingContacts = false;
        _error = '연락처 권한이 필요합니다.';
        notifyListeners();
        return;
      }

      // 연락처 가져오기
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      debugPrint('📱 기기에서 ${contacts.length}개 연락처 가져옴');

      // ContactItem으로 변환
      final contactItems = <ContactItem>[];
      for (final contact in contacts) {
        try {
          final contactItem = ContactItem.fromFlutterContact(contact);

          // 전화번호가 있는 연락처만 추가
          if (contactItem.phoneNumber.isNotEmpty) {
            contactItems.add(contactItem);
          }
        } catch (e) {
          debugPrint('⚠️ 연락처 변환 중 오류: ${contact.displayName} - $e');
        }
      }

      // 이름순으로 정렬
      contactItems.sort((a, b) => a.displayName.compareTo(b.displayName));

      _contactList = contactItems;
      _isLoadingContacts = false;
      notifyListeners();

      debugPrint('✅ 연락처 목록 로드 완료: ${_contactList.length}개');
    } catch (e) {
      debugPrint('❌ 연락처 목록 로드 실패: $e');
      _isLoadingContacts = false;
      _error = '연락처를 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// 연락처 새로고침
  Future<void> refreshContactList() async {
    await loadContactList();
  }

  // ==================== 초기화 ====================

  /// Controller 초기화 (단순화된 버전)
  Future<void> initialize(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('🚀 FriendRequestController 초기화 시작: $userId');

      // 1. 기본 데이터 로드
      await loadAllData(userId);

      // 2. 실시간 스트림 시작
      startRealTimeStreams(userId);

      // 3. 연락처 권한 확인 후 연락처 목록 로드
      await checkContactPermission();
      if (_hasContactPermission) {
        debugPrint('📱 연락처 권한 확인됨 - 연락처 목록 로드 시작');
        await loadContactList();
      } else {
        debugPrint('📱 연락처 권한이 없습니다.');
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

  /// 모든 데이터 로드
  Future<void> loadAllData(String userId) async {
    try {
      debugPrint('📊 친구 데이터 로드 시작');

      // 병렬 로드로 성능 최적화
      final futures = await Future.wait([
        _friendRequestService.getReceivedRequests(userId),
        _friendRequestService.getSentRequests(userId),
        _friendRequestService.getFriends(userId),
      ]);

      _receivedRequests = futures[0] as List<FriendRequestModel>;
      _sentRequests = futures[1] as List<FriendRequestModel>;
      _friends = futures[2] as List<FriendModel>;

      debugPrint('📈 데이터 로드 완료:');
      debugPrint('  - 받은 요청: ${_receivedRequests.length}개');
      debugPrint('  - 보낸 요청: ${_sentRequests.length}개');
      debugPrint('  - 친구: ${_friends.length}명');

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
      _successMessage = null; // 성공 메시지 초기화
      notifyListeners();

      debugPrint('📞 전화번호로 친구 요청/초대: $phoneNumber');

      final result = await _friendRequestService.sendFriendRequestByPhone(
        fromUserId: fromUserId,
        fromUserNickname: fromUserNickname,
        phoneNumber: phoneNumber,
        message: message,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        if (result.isSmsInvitation) {
          // SMS 초대인 경우
          _successMessage = result.actionMessage ?? '앱 설치 링크를 문자로 보냈습니다.';
          debugPrint('✅ SMS 초대 발송 성공');
        } else {
          // 일반 친구 요청인 경우
          _successMessage = result.actionMessage ?? '친구 요청을 보냈습니다.';
          debugPrint('✅ 친구 요청 전송 성공');
        }
        return true;
      } else {
        _error = result.error;
        debugPrint('❌ 요청 처리 실패: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 친구 요청/초대 처리 중 오류: $e');
      _isLoading = false;
      _error = '요청 처리 중 오류가 발생했습니다.';
      _successMessage = null;
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

  /// 연락처 아이템으로 친구 요청 보내기 (새로운 단순한 방식)
  Future<bool> sendFriendRequestToContact({
    required String fromUserId,
    required String fromUserNickname,
    required ContactItem contact,
    String? message,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      _successMessage = null;
      notifyListeners();

      debugPrint(
        '📞 연락처로 친구 요청/초대: ${contact.displayName} (${contact.phoneNumber})',
      );

      final result = await _friendRequestService.sendFriendRequestByPhone(
        fromUserId: fromUserId,
        fromUserNickname: fromUserNickname,
        phoneNumber: contact.phoneNumber,
        message: message,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        if (result.isSmsInvitation) {
          // SMS 초대인 경우
          _successMessage = '${contact.displayName}님에게 앱 설치 링크를 문자로 보냈습니다.';
          debugPrint('✅ SMS 초대 발송 성공');
        } else {
          // 일반 친구 요청인 경우
          _successMessage = '${contact.displayName}님에게 친구 요청을 보냈습니다.';
          debugPrint('✅ 친구 요청 전송 성공');
        }
        return true;
      } else {
        _error = result.error;
        debugPrint('❌ 요청 처리 실패: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 친구 요청/초대 처리 중 오류: $e');
      _isLoading = false;
      _error = '요청 처리 중 오류가 발생했습니다.';
      _successMessage = null;
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
        // generateFriendSuggestions(respondingUserId, forceRefresh: true); // 추천 목록 새로고침 로직 제거

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
        // if (_hasContactPermission) { // 추천 목록 새로고침 로직 제거
        //   generateFriendSuggestions(userId, forceRefresh: true);
        // }

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
    // 이 함수는 더 이상 사용되지 않으므로 제거
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

  // ==================== 유틸리티 메서드 ====================

  /// 에러 및 성공 메시지 상태 초기화
  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  /// 에러 상태 초기화 (하위 호환성)
  void clearError() {
    clearMessages();
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
        refreshContactList(), // 연락처 목록 새로고침
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

  // ==================== 리소스 해제 ====================

  @override
  void dispose() {
    debugPrint('🔄 FriendRequestController dispose 시작');

    // 스트림 구독 해제
    stopRealTimeStreams();

    super.dispose();

    debugPrint('✅ FriendRequestController dispose 완료');
  }
}
