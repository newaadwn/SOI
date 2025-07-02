import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/contact_service.dart';
import '../models/contact_data_model.dart';

/// Contact Controller - UI와 비즈니스 로직을 연결하는 Controller
/// Service를 사용해서 UI 상태를 관리하고 사용자 피드백을 제공
class ContactController extends ChangeNotifier {
  // 상태 변수들
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _permissionDenied = false;
  String? _error;

  List<ContactDataModel> _contacts = [];
  List<ContactDataModel> _favoriteContacts = [];
  List<Contact> _deviceContacts = [];
  List<Contact> _filteredDeviceContacts = [];
  ContactDataModel? _selectedContact;
  Map<String, int> _contactStats = {};
  Set<String> _addedContactPhones = {};

  String _searchQuery = '';
  ContactSearchFilter? _currentFilter;
  StreamSubscription<List<ContactDataModel>>? _contactsSubscription;

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final ContactService _contactService = ContactService();

  // Getters
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get permissionDenied => _permissionDenied;
  String? get error => _error;
  List<ContactDataModel> get contacts => _contacts;
  List<ContactDataModel> get favoriteContacts => _favoriteContacts;
  List<Contact> get deviceContacts => _deviceContacts;
  List<Contact> get filteredDeviceContacts => _filteredDeviceContacts;
  ContactDataModel? get selectedContact => _selectedContact;
  Map<String, int> get contactStats => _contactStats;
  String get searchQuery => _searchQuery;
  bool get hasContacts => _contacts.isNotEmpty;
  bool get hasDeviceContacts => _deviceContacts.isNotEmpty;
  bool get hasFilteredContacts => _filteredDeviceContacts.isNotEmpty;

  // ==================== 초기화 ====================

  /// Controller 초기화
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 권한 요청 및 연락처 로드
      await requestContactPermission();

      if (!_permissionDenied) {
        await loadContacts();
        await loadContactStats();
        await loadAddedContacts();

        // 실시간 스트림 시작
        startContactsStream();
      }

      _isLoading = false;
      notifyListeners();

      if (!_permissionDenied) {
        Fluttertoast.showToast(msg: '연락처가 로드되었습니다.');
      }
    } catch (e) {
      debugPrint('연락처 컨트롤러 초기화 오류: $e');
      _isLoading = false;
      _error = '연락처 초기화 중 오류가 발생했습니다.';
      notifyListeners();
      Fluttertoast.showToast(msg: '연락처 초기화 중 오류가 발생했습니다.');
    }
  }

  // ==================== 권한 관리 ====================

  /// 연락처 권한 요청
  Future<void> requestContactPermission() async {
    try {
      final permissionStatus = await _contactService.checkContactsPermission();

      if (permissionStatus != PermissionStatus.granted) {
        final requestResult = await _contactService.requestContactsPermission();

        if (requestResult != PermissionStatus.granted) {
          _permissionDenied = true;
          notifyListeners();

          if (requestResult == PermissionStatus.permanentlyDenied) {
            Fluttertoast.showToast(msg: '설정에서 연락처 권한을 허용해주세요.');
          } else {
            Fluttertoast.showToast(msg: '연락처 권한이 필요합니다.');
          }
          return;
        }
      }

      _permissionDenied = false;
      notifyListeners();
    } catch (e) {
      debugPrint('연락처 권한 요청 오류: $e');
      _permissionDenied = true;
      notifyListeners();
      Fluttertoast.showToast(msg: '연락처 권한 요청 중 오류가 발생했습니다.');
    }
  }

  /// 설정 앱 열기
  Future<void> openAppSettings() async {
    try {
      final success = await _contactService.openSettings();
      if (!success) {
        Fluttertoast.showToast(msg: '설정 앱을 열 수 없습니다.');
      }
    } catch (e) {
      debugPrint('설정 앱 열기 오류: $e');
      Fluttertoast.showToast(msg: '설정 앱 열기 중 오류가 발생했습니다.');
    }
  }

  // ==================== 연락처 조회 ====================

  /// Firebase 연락처 목록 로드
  Future<void> loadContacts({ContactSearchFilter? filter}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final contacts = await _contactService.getContacts(filter: filter);

      _contacts = contacts;
      _currentFilter = filter;
      _isLoading = false;
      notifyListeners();

      if (contacts.isEmpty) {
        Fluttertoast.showToast(msg: '저장된 연락처가 없습니다.');
      }
    } catch (e) {
      debugPrint('연락처 로드 오류: $e');
      _isLoading = false;
      _error = '연락처를 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
      Fluttertoast.showToast(msg: '연락처를 불러오는 중 오류가 발생했습니다.');
    }
  }

  /// 즐겨찾기 연락처 로드
  Future<void> loadFavoriteContacts() async {
    try {
      final favorites = await _contactService.getFavoriteContacts();
      _favoriteContacts = favorites;
      notifyListeners();
    } catch (e) {
      debugPrint('즐겨찾기 연락처 로드 오류: $e');
    }
  }

  /// 디바이스 연락처 로드
  Future<void> loadDeviceContacts() async {
    try {
      if (_permissionDenied) {
        await requestContactPermission();
        if (_permissionDenied) return;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      final deviceContacts = await _contactService.getAllDeviceContacts();

      _deviceContacts = deviceContacts;
      _filteredDeviceContacts = deviceContacts;
      _isLoading = false;
      notifyListeners();

      if (deviceContacts.isEmpty) {
        Fluttertoast.showToast(msg: '디바이스에 연락처가 없습니다.');
      } else {
        Fluttertoast.showToast(msg: '${deviceContacts.length}개의 연락처를 찾았습니다.');
      }
    } catch (e) {
      debugPrint('디바이스 연락처 로드 오류: $e');
      _isLoading = false;
      _error = '디바이스 연락처를 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
      Fluttertoast.showToast(msg: '디바이스 연락처를 불러오는 중 오류가 발생했습니다.');
    }
  }

  /// 연락처 상세 정보 로드
  Future<void> loadContactDetails(String contactId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final contact = await _contactService.getContactDetails(contactId);

      _selectedContact = contact;
      _isLoading = false;
      notifyListeners();

      if (contact == null) {
        Fluttertoast.showToast(msg: '연락처를 찾을 수 없습니다.');
      }
    } catch (e) {
      debugPrint('연락처 상세 로드 오류: $e');
      _isLoading = false;
      _error = '연락처 상세 정보를 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
      Fluttertoast.showToast(msg: '연락처 상세 정보를 불러오는 중 오류가 발생했습니다.');
    }
  }

  /// 연락처 실시간 스트림 시작
  void startContactsStream() {
    _contactsSubscription?.cancel();
    _contactsSubscription = _contactService
        .getContactsStream(filter: _currentFilter)
        .listen(
          (contacts) {
            _contacts = contacts;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('연락처 스트림 오류: $error');
            _error = '실시간 연락처 업데이트 중 오류가 발생했습니다.';
            notifyListeners();
          },
        );
  }

  /// 연락처 스트림 중지
  void stopContactsStream() {
    _contactsSubscription?.cancel();
    _contactsSubscription = null;
  }

  // ==================== 연락처 검색 ====================

  /// 연락처 검색
  Future<void> searchContacts(String query) async {
    try {
      _searchQuery = query;

      if (query.trim().isEmpty) {
        await loadContacts(filter: _currentFilter);
        return;
      }

      _isLoading = true;
      notifyListeners();

      final searchResults = await _contactService.searchContacts(query);

      _contacts = searchResults;
      _isLoading = false;
      notifyListeners();

      if (searchResults.isEmpty) {
        Fluttertoast.showToast(msg: '검색 결과가 없습니다.');
      }
    } catch (e) {
      debugPrint('연락처 검색 오류: $e');
      _isLoading = false;
      _error = '연락처 검색 중 오류가 발생했습니다.';
      notifyListeners();
      Fluttertoast.showToast(msg: '연락처 검색 중 오류가 발생했습니다.');
    }
  }

  /// 디바이스 연락처 검색
  void filterDeviceContacts(String query) {
    _searchQuery = query;

    if (query.trim().isEmpty) {
      _filteredDeviceContacts = _deviceContacts;
    } else {
      final lowercaseQuery = query.toLowerCase();
      _filteredDeviceContacts =
          _deviceContacts.where((contact) {
            final name = contact.displayName.toLowerCase();
            final phone =
                contact.phones.isNotEmpty
                    ? contact.phones.first.number.toLowerCase()
                    : '';
            return name.contains(lowercaseQuery) ||
                phone.contains(lowercaseQuery);
          }).toList();
    }

    notifyListeners();
  }

  /// 검색 초기화
  void clearSearch() {
    _searchQuery = '';
    _filteredDeviceContacts = _deviceContacts;
    loadContacts(filter: _currentFilter);
    notifyListeners();
  }

  // ==================== 연락처 추가 ====================

  /// 연락처 추가
  Future<bool> addContact({
    required String displayName,
    required String phoneNumber,
    String? email,
    List<String>? phoneNumbers,
    List<String>? emails,
    ContactType type = ContactType.friend,
    String? notes,
    String? organization,
    String? jobTitle,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final contactData = ContactDataModel(
        id: '', // Firestore에서 자동 생성
        displayName: displayName,
        phoneNumber: phoneNumber,
        email: email,
        phoneNumbers: phoneNumbers ?? [phoneNumber],
        emails: emails ?? (email != null ? [email] : []),
        createdAt: DateTime.now(),
        type: type,
        notes: notes,
        organization: organization,
        jobTitle: jobTitle,
      );

      final result = await _contactService.addContact(contact: contactData);

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '연락처가 추가되었습니다.');

        // 추가된 연락처 전화번호 기록
        _addedContactPhones.add(phoneNumber);

        // 연락처 목록 새로고침
        await loadContacts(filter: _currentFilter);

        return true;
      } else {
        // ❌ 실패 시 UI 피드백
        _error = result.error;
        Fluttertoast.showToast(msg: result.error ?? '연락처 추가에 실패했습니다.');
        return false;
      }
    } catch (e) {
      debugPrint('연락처 추가 컨트롤러 오류: $e');
      _isLoading = false;
      _error = '연락처 추가 중 오류가 발생했습니다.';
      notifyListeners();
      Fluttertoast.showToast(msg: '연락처 추가 중 오류가 발생했습니다.');
      return false;
    }
  }

  /// 디바이스 연락처에서 추가
  Future<bool> addContactFromDevice(Contact deviceContact) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _contactService.addContactFromDevice(deviceContact);

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(
          msg: '${deviceContact.displayName}이(가) 추가되었습니다.',
        );

        // 추가된 연락처 전화번호 기록
        if (deviceContact.phones.isNotEmpty) {
          _addedContactPhones.add(deviceContact.phones.first.number);
        }

        // 연락처 목록 새로고침
        await loadContacts(filter: _currentFilter);

        return true;
      } else {
        // ❌ 실패 시 UI 피드백
        _error = result.error;
        Fluttertoast.showToast(msg: result.error ?? '연락처 추가에 실패했습니다.');
        return false;
      }
    } catch (e) {
      debugPrint('디바이스 연락처 추가 오류: $e');
      _isLoading = false;
      _error = '연락처 추가 중 오류가 발생했습니다.';
      notifyListeners();
      Fluttertoast.showToast(msg: '연락처 추가 중 오류가 발생했습니다.');
      return false;
    }
  }

  /// 디바이스 연락처 일괄 동기화
  Future<void> syncContactsFromDevice({
    bool skipDuplicates = true,
    int? maxCount,
  }) async {
    try {
      _isSyncing = true;
      _error = null;
      notifyListeners();

      final result = await _contactService.syncContactsFromDevice(
        skipDuplicates: skipDuplicates,
        maxCount: maxCount,
      );

      _isSyncing = false;
      notifyListeners();

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '${result.addedCount}개 연락처가 동기화되었습니다.');

        // 연락처 목록 새로고침
        await loadContacts(filter: _currentFilter);
        await loadContactStats();
      } else {
        // ❌ 실패 시 UI 피드백
        _error = result.error;
        Fluttertoast.showToast(msg: result.error ?? '연락처 동기화에 실패했습니다.');
      }

      // 오류가 있는 경우에도 부분적으로 성공했을 수 있음
      if (result.errorCount > 0) {
        Fluttertoast.showToast(msg: '${result.errorCount}개 연락처에서 오류가 발생했습니다.');
      }
    } catch (e) {
      debugPrint('연락처 동기화 오류: $e');
      _isSyncing = false;
      _error = '연락처 동기화 중 오류가 발생했습니다.';
      notifyListeners();
      Fluttertoast.showToast(msg: '연락처 동기화 중 오류가 발생했습니다.');
    }
  }

  // ==================== 연락처 업데이트 ====================

  /// 연락처 정보 업데이트
  Future<bool> updateContact({
    required String contactId,
    String? displayName,
    String? phoneNumber,
    String? email,
    List<String>? phoneNumbers,
    List<String>? emails,
    ContactType? type,
    String? notes,
    String? organization,
    String? jobTitle,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _contactService.updateContact(
        contactId: contactId,
        displayName: displayName,
        phoneNumber: phoneNumber,
        email: email,
        phoneNumbers: phoneNumbers,
        emails: emails,
        type: type,
        notes: notes,
        organization: organization,
        jobTitle: jobTitle,
      );

      _isLoading = false;
      notifyListeners();

      if (success) {
        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '연락처 정보가 업데이트되었습니다.');

        // 연락처 목록 새로고침
        await loadContacts(filter: _currentFilter);

        // 선택된 연락처 새로고침
        if (_selectedContact?.id == contactId) {
          await loadContactDetails(contactId);
        }

        return true;
      } else {
        // ❌ 실패 시 UI 피드백
        Fluttertoast.showToast(msg: '연락처 업데이트에 실패했습니다.');
        return false;
      }
    } catch (e) {
      debugPrint('연락처 업데이트 컨트롤러 오류: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      Fluttertoast.showToast(msg: e.toString());
      return false;
    }
  }

  /// 즐겨찾기 토글
  Future<bool> toggleFavorite(String contactId) async {
    try {
      final success = await _contactService.toggleFavorite(contactId);

      if (success) {
        // ✅ 성공 시 UI 피드백 (토스트는 표시하지 않음 - UX 고려)

        // 연락처 목록에서 해당 연락처 업데이트
        final contactIndex = _contacts.indexWhere((c) => c.id == contactId);
        if (contactIndex != -1) {
          await loadContacts(filter: _currentFilter);
        }

        // 선택된 연락처 업데이트
        if (_selectedContact?.id == contactId) {
          await loadContactDetails(contactId);
        }

        // 즐겨찾기 목록 새로고침
        await loadFavoriteContacts();

        return true;
      } else {
        Fluttertoast.showToast(msg: '즐겨찾기 처리에 실패했습니다.');
        return false;
      }
    } catch (e) {
      debugPrint('즐겨찾기 토글 오류: $e');
      Fluttertoast.showToast(msg: '즐겨찾기 처리 중 오류가 발생했습니다.');
      return false;
    }
  }

  // ==================== 연락처 삭제 ====================

  /// 연락처 삭제
  Future<bool> deleteContact({
    required String contactId,
    bool permanentDelete = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _contactService.deleteContact(
        contactId: contactId,
        permanentDelete: permanentDelete,
      );

      _isLoading = false;
      notifyListeners();

      if (success) {
        // ✅ 성공 시 UI 피드백
        final message = permanentDelete ? '연락처가 완전히 삭제되었습니다.' : '연락처가 삭제되었습니다.';
        Fluttertoast.showToast(msg: message);

        // 연락처 목록에서 제거
        _contacts.removeWhere((contact) => contact.id == contactId);
        _favoriteContacts.removeWhere((contact) => contact.id == contactId);

        // 선택된 연락처가 삭제된 경우 초기화
        if (_selectedContact?.id == contactId) {
          _selectedContact = null;
        }

        notifyListeners();

        // 통계 새로고침
        await loadContactStats();

        return true;
      } else {
        // ❌ 실패 시 UI 피드백
        Fluttertoast.showToast(msg: '연락처 삭제에 실패했습니다.');
        return false;
      }
    } catch (e) {
      debugPrint('연락처 삭제 컨트롤러 오류: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      Fluttertoast.showToast(msg: e.toString());
      return false;
    }
  }

  // ==================== 통계 및 유틸리티 ====================

  /// 연락처 통계 로드
  Future<void> loadContactStats() async {
    try {
      final stats = await _contactService.getContactStats();
      _contactStats = stats;
      notifyListeners();
    } catch (e) {
      debugPrint('연락처 통계 로드 오류: $e');
    }
  }

  /// 추가된 연락처 정보 로드
  Future<void> loadAddedContacts() async {
    try {
      final contacts = await _contactService.getContacts();
      _addedContactPhones =
          contacts
              .map((contact) => contact.phoneNumber)
              .where((phone) => phone.isNotEmpty)
              .toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('추가된 연락처 로드 오류: $e');
    }
  }

  /// 연락처가 이미 추가되었는지 확인
  bool isContactAdded(String phoneNumber) {
    return _addedContactPhones.contains(phoneNumber);
  }

  /// 연락처 이니셜 가져오기
  String getInitials(String? name) {
    return _contactService.getInitials(name);
  }

  /// 전화번호 포맷팅
  String formatPhoneNumber(String? phone) {
    return _contactService.formatPhoneNumber(phone);
  }

  /// 연락처 아바타 위젯 생성
  Widget buildContactAvatar(Contact contact, {double radius = 20.0}) {
    return _contactService.buildContactAvatar(contact, radius: radius);
  }

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 선택된 연락처 초기화
  void clearSelectedContact() {
    _selectedContact = null;
    notifyListeners();
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 기존 ContactsService와의 호환성을 위한 메서드들
  Stream<List<Map<String, dynamic>>> getContactsAsMapStream() {
    return _contactService.getContactsAsMapStream();
  }

  Future<String> addContactLegacy(Map<String, dynamic> contactData) async {
    return await _contactService.addContactLegacy(contactData);
  }

  Future<void> updateContactLegacy(
    Map<String, dynamic> contactData,
    String contactId,
  ) async {
    return await _contactService.updateContactLegacy(contactData, contactId);
  }

  Future<void> deleteContactLegacy(String contactId) async {
    return await _contactService.deleteContactLegacy(contactId);
  }

  Future<ContactDataModel?> findContactByPhone(String phoneNumber) async {
    return await _contactService.findContactByPhone(phoneNumber);
  }

  Future<bool> isContactExists(String phoneNumber) async {
    try {
      final contact = await _contactService.findContactByPhone(phoneNumber);
      return contact != null;
    } catch (e) {
      return false;
    }
  }

  Future<PermissionStatus> checkContactsPermission() async {
    return await _contactService.checkContactsPermission();
  }

  Future<PermissionStatus> requestContactsPermission() async {
    return await _contactService.requestContactsPermission();
  }

  Future<bool> openSettings() async {
    return await _contactService.openSettings();
  }

  Future<List<Contact>> getAllContacts() async {
    return await _contactService.getAllDeviceContacts();
  }

  Future<List<Contact>> searchContactsByName(String query) async {
    return await _contactService.searchDeviceContacts(query);
  }

  List<Contact> filterContacts(List<Contact> contacts, String query) {
    if (query.isEmpty) return contacts;

    final lowercaseQuery = query.toLowerCase();
    return contacts.where((contact) {
      final name = contact.displayName.toLowerCase();
      final phone =
          contact.phones.isNotEmpty
              ? contact.phones.first.number.toLowerCase()
              : '';
      return name.contains(lowercaseQuery) || phone.contains(lowercaseQuery);
    }).toList();
  }

  // ==================== 리소스 해제 ====================

  @override
  void dispose() {
    _contactsSubscription?.cancel();
    super.dispose();
  }
}
