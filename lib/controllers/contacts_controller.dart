import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_model.dart';
import '../services/contacts_service.dart';

/// 연락처 관련 비즈니스 로직을 처리하는 컨트롤러
class ContactsController with ChangeNotifier {
  // 서비스 객체 생성
  final ContactsService _contactsService = ContactsService();

  // 상태 변수
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  Set<String> _addedContactPhones = {};
  bool _isLoading = true;
  bool _permissionDenied = false;

  // 상태 getter
  List<Contact> get contacts => _contacts;
  List<Contact> get filteredContacts => _filteredContacts;
  bool get isLoading => _isLoading;
  bool get permissionDenied => _permissionDenied;
  bool get hasContacts => _contacts.isNotEmpty;
  bool get hasFilteredContacts => _filteredContacts.isNotEmpty;

  /// 초기화 - 권한 요청 및 연락처 로드
  Future<void> initialize() async {
    await requestContactPermission();
    loadAddedContacts();
  }

  /// 연락처 권한 요청
  Future<void> requestContactPermission() async {
    // 권한 상태 확인
    PermissionStatus permissionStatus =
        await _contactsService.checkContactsPermission();

    // 권한이 없는 경우 요청
    if (permissionStatus != PermissionStatus.granted) {
      permissionStatus = await _contactsService.requestContactsPermission();

      // 권한이 거부된 경우
      if (permissionStatus != PermissionStatus.granted) {
        _permissionDenied = true;
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    // 권한이 허용된 경우 연락처 가져오기
    loadContacts();
  }

  /// 설정 앱 열기
  Future<void> openSettings() async {
    await _contactsService.openSettings();
  }

  /// 이미 추가된 연락처 로드
  void loadAddedContacts() {
    try {
      // Firebase에서 이미 추가된 연락처 목록 가져오기
      _contactsService.getContacts().listen((contacts) {
        _addedContactPhones =
            contacts.map((contact) => contact.phoneNumber).toSet();
        notifyListeners();
      });
    } catch (e) {
      debugPrint('저장된 연락처 불러오기 오류: $e');
    }
  }

  /// 연락처 목록 로드
  Future<void> loadContacts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final contacts = await _contactsService.getAllContacts();
      _contacts = contacts;
      _filteredContacts = contacts;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      debugPrint('연락처 가져오기 오류: $e');
      notifyListeners();
    }
  }

  /// 연락처 검색
  void searchContacts(String query) {
    _filteredContacts = _contactsService.filterContacts(_contacts, query);
    notifyListeners();
  }

  /// 연락처가 이미 추가되었는지 확인
  bool isContactAdded(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;

    // 전화번호 형식 통일 (특수문자 제거)
    String cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // 이미 추가된 연락처 목록에서 확인
    return _addedContactPhones.any((phone) {
      String cleanedSavedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      return cleanedSavedPhone == cleanedPhone;
    });
  }

  /// 연락처 추가
  Future<bool> addContact(Contact contact) async {
    // 전화번호 확인
    final String phoneNumber =
        contact.phones.isNotEmpty ? contact.phones.first.number : '';

    if (phoneNumber.isEmpty) {
      return false;
    }

    // 이미 추가된 연락처인지 확인
    if (isContactAdded(phoneNumber)) {
      return false;
    }

    try {
      // ContactModel로 변환
      final contactModel = ContactModel.fromFlutterContact(contact);

      // Firebase에 저장
      await _contactsService.addContact(contactModel);

      // 추가된 연락처 목록 업데이트
      _addedContactPhones.add(phoneNumber);
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('연락처 추가 오류: $e');
      return false;
    }
  }

  /// 연락처 이니셜 가져오기
  String getInitials(String? name) {
    return _contactsService.getInitials(name);
  }

  /// 전화번호 포맷팅
  String formatPhoneNumber(String? phone) {
    return _contactsService.formatPhoneNumber(phone);
  }

  /// 연락처 아바타 위젯 생성
  Widget buildContactAvatar(Contact contact, {double radius = 20.0}) {
    return _contactsService.buildContactAvatar(contact, radius: radius);
  }
}
