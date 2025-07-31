import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/contact_service.dart';

/// 연락처 관련 UI 상태 관리를 담당하는 Controller
class ContactController extends ChangeNotifier {
  final ContactService _contactService = ContactService();

  // 상태 변수들
  bool _contactSyncEnabled = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  // Getters
  bool get contactSyncEnabled => _contactSyncEnabled;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _contactService.initialize();
      _contactSyncEnabled = _contactService.contactSyncEnabled;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // debugPrint('ContactController 초기화 실패: $e');
    }
  }

  /// 페이지 진입 시 연락처 권한 자동 요청 및 설정 로드
  Future<ContactInitResult> initializeContactPermission() async {
    _setLoading(true);
    notifyListeners();

    try {
      final result = await _contactService.initializeContactPermission();

      // 상태 업데이트
      _contactSyncEnabled = result.isEnabled;
      _setLoading(false);
      notifyListeners();

      return result;
    } catch (e) {
      _setLoading(false);
      notifyListeners();

      return ContactInitResult.error(
        message: '초기화 중 오류가 발생했습니다: $e',
        isEnabled: false,
      );
    }
  }

  /// 토글 상태 변경 처리
  Future<ContactToggleResult> handleToggleChange() async {
    final result = await _contactService.handleToggleChange();

    // 성공한 경우에만 상태 업데이트
    if (result.type == ContactToggleResultType.success) {
      _contactSyncEnabled = result.isEnabled;
      notifyListeners();
    }

    return result;
  }

  /// 연락처 권한 요청
  Future<ContactToggleResult> requestContactPermission() async {
    _setLoading(true);
    notifyListeners();

    try {
      final result = await _contactService.requestContactPermission();

      // 성공한 경우에만 상태 업데이트
      if (result.type == ContactToggleResultType.success) {
        _contactSyncEnabled = result.isEnabled;
      }

      _setLoading(false);
      notifyListeners();

      return result;
    } catch (e) {
      _setLoading(false);
      notifyListeners();

      return ContactToggleResult.error(
        message: '권한 요청 중 오류가 발생했습니다: $e',
        isEnabled: false,
      );
    }
  }

  /// 설정에서 돌아온 후 권한 상태 재확인
  Future<ContactToggleResult> checkPermissionAfterSettings() async {
    _setLoading(true);
    notifyListeners();

    try {
      final result = await _contactService.checkPermissionAfterSettings();

      // 상태 업데이트
      _contactSyncEnabled = result.isEnabled;
      _setLoading(false);
      notifyListeners();

      return result;
    } catch (e) {
      _setLoading(false);
      notifyListeners();

      return ContactToggleResult.error(
        message: '권한 확인 중 오류가 발생했습니다: $e',
        isEnabled: false,
      );
    }
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 연락처 목록 가져오기 (권한이 있을 때)
  Future<List<Contact>> getContacts() async {
    return await _contactService.getContacts();
  }

  /// 특정 연락처 정보 가져오기
  Future<Contact?> getContact(String id) async {
    return await _contactService.getContact(id);
  }

  /// 연락처 검색
  Future<List<Contact>> searchContacts(String query) async {
    return await _contactService.searchContacts(query);
  }
}
