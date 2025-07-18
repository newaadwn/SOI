import 'package:flutter/material.dart';
import 'dart:async';
import '../services/friend_request_service.dart';
import '../models/friend_request_model.dart';

/// 친구 요청 관련 UI 상태 관리를 담당하는 Controller
class FriendRequestController extends ChangeNotifier {
  final FriendRequestService _friendRequestService;

  // 상태 변수들
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // 친구 요청 목록
  List<FriendRequestModel> _receivedRequests = [];
  List<FriendRequestModel> _sentRequests = [];

  // 요청 전송 상태
  bool _isSendingRequest = false;
  Map<String, bool> _processingRequests = {}; // requestId -> isProcessing

  // 통계 정보
  Map<String, int> _requestStats = {'received': 0, 'sent': 0};

  // Stream 구독
  StreamSubscription<List<FriendRequestModel>>? _receivedRequestsSubscription;
  StreamSubscription<List<FriendRequestModel>>? _sentRequestsSubscription;

  FriendRequestController({required FriendRequestService friendRequestService})
    : _friendRequestService = friendRequestService;

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  List<FriendRequestModel> get receivedRequests => _receivedRequests;
  List<FriendRequestModel> get sentRequests => _sentRequests;
  bool get isSendingRequest => _isSendingRequest;
  Map<String, int> get requestStats => _requestStats;

  /// 특정 요청이 처리 중인지 확인
  bool isProcessingRequest(String requestId) {
    return _processingRequests[requestId] ?? false;
  }

  /// 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true);
      _clearError();

      // 실시간 친구 요청 목록 구독
      await _subscribeToRequests();

      // 통계 정보 로드
      await _loadRequestStats();

      _isInitialized = true;
      debugPrint('FriendRequestController 초기화 완료');
    } catch (e) {
      _setError('친구 요청 초기화 실패: $e');
      debugPrint('FriendRequestController 초기화 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 친구 요청 전송
  ///
  /// [receiverUid] 요청을 받을 사용자 UID
  /// [message] 선택적 메시지
  Future<bool> sendFriendRequest({
    required String receiverUid,
    String? message,
  }) async {
    try {
      _isSendingRequest = true;
      _clearError();
      notifyListeners();

      final requestId = await _friendRequestService.sendFriendRequest(
        receiverUid: receiverUid,
        message: message,
      );

      debugPrint('친구 요청 전송 성공: $requestId');

      // 통계 업데이트
      await _loadRequestStats();

      return true;
    } catch (e) {
      _setError('친구 요청 전송 실패: $e');
      debugPrint('친구 요청 전송 실패: $e');
      return false;
    } finally {
      _isSendingRequest = false;
      notifyListeners();
    }
  }

  /// 친구 요청 수락
  ///
  /// [requestId] 친구 요청 ID
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      _processingRequests[requestId] = true;
      _clearError();
      notifyListeners();

      await _friendRequestService.acceptFriendRequest(requestId);

      debugPrint('친구 요청 수락 성공: $requestId');

      // 통계 업데이트
      await _loadRequestStats();

      return true;
    } catch (e) {
      _setError('친구 요청 수락 실패: $e');
      debugPrint('친구 요청 수락 실패: $e');
      return false;
    } finally {
      _processingRequests[requestId] = false;
      notifyListeners();
    }
  }

  /// 친구 요청 거절
  ///
  /// [requestId] 친구 요청 ID
  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      _processingRequests[requestId] = true;
      _clearError();
      notifyListeners();

      await _friendRequestService.rejectFriendRequest(requestId);

      debugPrint('친구 요청 거절 성공: $requestId');

      // 통계 업데이트
      await _loadRequestStats();

      return true;
    } catch (e) {
      _setError('친구 요청 거절 실패: $e');
      debugPrint('친구 요청 거절 실패: $e');
      return false;
    } finally {
      _processingRequests[requestId] = false;
      notifyListeners();
    }
  }

  /// 친구 요청 취소
  ///
  /// [requestId] 친구 요청 ID
  Future<bool> cancelFriendRequest(String requestId) async {
    try {
      _processingRequests[requestId] = true;
      _clearError();
      notifyListeners();

      await _friendRequestService.cancelFriendRequest(requestId);

      debugPrint('친구 요청 취소 성공: $requestId');

      // 통계 업데이트
      await _loadRequestStats();

      return true;
    } catch (e) {
      _setError('친구 요청 취소 실패: $e');
      debugPrint('친구 요청 취소 실패: $e');
      return false;
    } finally {
      _processingRequests[requestId] = false;
      notifyListeners();
    }
  }

  /// 특정 사용자와의 친구 관계 상태 확인
  ///
  /// [userId] 확인할 사용자 ID
  Future<String> getFriendshipStatus(String userId) async {
    try {
      return await _friendRequestService.getFriendshipStatus(userId);
    } catch (e) {
      debugPrint('친구 관계 상태 확인 실패: $e');
      return 'none';
    }
  }

  /// 여러 사용자들과의 친구 관계 상태 일괄 확인
  ///
  /// [userIds] 확인할 사용자 ID 목록
  Future<Map<String, String>> getBatchFriendshipStatus(
    List<String> userIds,
  ) async {
    try {
      return await _friendRequestService.getBatchFriendshipStatus(userIds);
    } catch (e) {
      debugPrint('배치 친구 관계 상태 확인 실패: $e');
      return {};
    }
  }

  /// 실시간 친구 요청 목록 구독
  Future<void> _subscribeToRequests() async {
    try {
      // 받은 요청 구독
      _receivedRequestsSubscription = _friendRequestService
          .getReceivedRequests()
          .listen(
            (requests) {
              _receivedRequests = requests;
              notifyListeners();
            },
            onError: (error) {
              _setError('받은 요청 로드 실패: $error');
            },
          );

      // 보낸 요청 구독
      _sentRequestsSubscription = _friendRequestService
          .getSentRequests()
          .listen(
            (requests) {
              _sentRequests = requests;
              notifyListeners();
            },
            onError: (error) {
              _setError('보낸 요청 로드 실패: $error');
            },
          );
    } catch (e) {
      _setError('요청 목록 구독 실패: $e');
    }
  }

  /// 통계 정보 로드
  Future<void> _loadRequestStats() async {
    try {
      _requestStats = await _friendRequestService.getFriendRequestStats();
      notifyListeners();
    } catch (e) {
      debugPrint('요청 통계 로드 실패: $e');
    }
  }

  /// 새로고침
  Future<void> refresh() async {
    try {
      _setLoading(true);
      _clearError();

      await _loadRequestStats();

      debugPrint('친구 요청 정보 새로고침 완료');
    } catch (e) {
      _setError('새로고침 실패: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 에러 설정
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// 에러 클리어
  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _receivedRequestsSubscription?.cancel();
    _sentRequestsSubscription?.cancel();
    super.dispose();
  }
}
