import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_data_model.dart';
import '../repositories/contact_repository.dart';

/// Contact Service - 연락처 관련 비즈니스 로직을 처리
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class ContactService {
  final ContactRepository _contactRepository = ContactRepository();

  // ==================== 연락처 추가 비즈니스 로직 ====================

  /// 연락처 추가
  Future<ContactSyncResult> addContact({
    required ContactDataModel contact,
    bool checkDuplicate = true,
  }) async {
    try {
      // 입력 검증
      final validationResult = _validateContact(contact);
      if (!validationResult.isValid) {
        return ContactSyncResult.failure(validationResult.error!);
      }

      // 중복 검사 (옵션)
      if (checkDuplicate) {
        final exists = await _contactRepository.isContactExists(
          contact.phoneNumber,
        );
        if (exists) {
          return ContactSyncResult.failure('이미 등록된 연락처입니다.');
        }
      }

      // 비즈니스 로직: 연락처 타입에 따른 추가 검증
      final typeValidation = _validateContactType(contact);
      if (!typeValidation.isValid) {
        return ContactSyncResult.failure(typeValidation.error!);
      }

      // Repository를 통해 저장
      final contactId = await _contactRepository.saveContactToFirestore(
        contact,
      );

      if (contactId != null) {
        return ContactSyncResult.success(addedCount: 1);
      } else {
        return ContactSyncResult.failure('연락처 저장에 실패했습니다.');
      }
    } catch (e) {
      return ContactSyncResult.failure('연락처 추가 중 오류가 발생했습니다: $e');
    }
  }

  /// 디바이스 연락처에서 가져와서 추가
  Future<ContactSyncResult> addContactFromDevice(Contact deviceContact) async {
    try {
      // 디바이스 연락처를 ContactDataModel로 변환
      final contactData = ContactDataModel.fromFlutterContact(deviceContact);

      // 비즈니스 로직: 최소 정보 검증
      if (contactData.displayName.isEmpty && contactData.phoneNumber.isEmpty) {
        return ContactSyncResult.failure('이름 또는 전화번호가 필요합니다.');
      }

      return await addContact(contact: contactData);
    } catch (e) {
      return ContactSyncResult.failure('디바이스 연락처 추가 중 오류가 발생했습니다: $e');
    }
  }

  /// 디바이스 연락처 일괄 동기화
  Future<ContactSyncResult> syncContactsFromDevice({
    bool skipDuplicates = true,
    int? maxCount,
  }) async {
    try {
      // 권한 확인
      final permissionStatus =
          await _contactRepository.checkContactsPermission();
      if (permissionStatus != PermissionStatus.granted) {
        return ContactSyncResult.failure('연락처 접근 권한이 필요합니다.');
      }

      // 디바이스 연락처 가져오기
      final deviceContacts = await _contactRepository.getAllDeviceContacts();

      if (deviceContacts.isEmpty) {
        return ContactSyncResult.failure('디바이스에 연락처가 없습니다.');
      }

      // 비즈니스 로직: 최대 개수 제한
      final contactsToSync =
          maxCount != null
              ? deviceContacts.take(maxCount).toList()
              : deviceContacts;

      int addedCount = 0;
      int errorCount = 0;
      List<String> errors = [];

      // 각 연락처 처리
      for (final deviceContact in contactsToSync) {
        try {
          final result = await addContactFromDevice(deviceContact);
          if (result.isSuccess) {
            addedCount++;
          } else {
            if (!skipDuplicates || !result.error!.contains('이미 등록된')) {
              errorCount++;
              errors.add('${deviceContact.displayName}: ${result.error}');
            }
          }
        } catch (e) {
          errorCount++;
          errors.add('${deviceContact.displayName}: $e');
        }
      }

      return ContactSyncResult(
        isSuccess: addedCount > 0,
        addedCount: addedCount,
        errorCount: errorCount,
        errors: errors,
      );
    } catch (e) {
      return ContactSyncResult.failure('연락처 동기화 중 오류가 발생했습니다: $e');
    }
  }

  // ==================== 연락처 조회 비즈니스 로직 ====================

  /// 연락처 목록 조회
  Future<List<ContactDataModel>> getContacts({
    ContactSearchFilter? filter,
  }) async {
    try {
      List<ContactDataModel> contacts;

      if (filter != null) {
        contacts = await _contactRepository.searchContactsInFirestore(
          filter: filter,
        );
      } else {
        contacts = await _contactRepository.getContactsFromFirestore();
      }

      // 비즈니스 로직: 정렬 및 필터링 적용
      return _applyContactBusinessRules(contacts, filter);
    } catch (e) {
      throw Exception('연락처 목록 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// 연락처 스트림 (실시간)
  Stream<List<ContactDataModel>> getContactsStream({
    ContactSearchFilter? filter,
  }) {
    return _contactRepository.getContactsStreamFromFirestore().map(
      (contacts) => _applyContactBusinessRules(contacts, filter),
    );
  }

  /// 특정 연락처 상세 조회
  Future<ContactDataModel?> getContactDetails(String contactId) async {
    try {
      if (contactId.isEmpty) {
        throw ArgumentError('연락처 ID가 필요합니다.');
      }

      return await _contactRepository.getContactById(contactId);
    } catch (e) {
      throw Exception('연락처 상세 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// 전화번호로 연락처 검색
  Future<ContactDataModel?> findContactByPhone(String phoneNumber) async {
    try {
      // 비즈니스 로직: 전화번호 정규화
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      if (normalizedPhone.isEmpty) {
        throw ArgumentError('유효한 전화번호가 필요합니다.');
      }

      return await _contactRepository.findContactByPhone(normalizedPhone);
    } catch (e) {
      throw Exception('전화번호 검색 중 오류가 발생했습니다: $e');
    }
  }

  /// 연락처 텍스트 검색
  Future<List<ContactDataModel>> searchContacts(String query) async {
    try {
      if (query.trim().isEmpty) {
        return await getContacts();
      }

      // 모든 연락처 가져와서 클라이언트 사이드 검색
      final allContacts = await _contactRepository.getContactsFromFirestore();

      final normalizedQuery = query.toLowerCase().trim();

      return allContacts.where((contact) {
        return contact.searchKeywords.any(
          (keyword) => keyword.contains(normalizedQuery),
        );
      }).toList();
    } catch (e) {
      throw Exception('연락처 검색 중 오류가 발생했습니다: $e');
    }
  }

  /// 즐겨찾기 연락처 조회
  Future<List<ContactDataModel>> getFavoriteContacts() async {
    try {
      final filter = ContactSearchFilter(isFavorite: true);
      return await getContacts(filter: filter);
    } catch (e) {
      throw Exception('즐겨찾기 연락처 조회 중 오류가 발생했습니다: $e');
    }
  }

  // ==================== 연락처 업데이트 비즈니스 로직 ====================

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
      // 기존 연락처 조회
      final existingContact = await _contactRepository.getContactById(
        contactId,
      );
      if (existingContact == null) {
        throw Exception('연락처를 찾을 수 없습니다.');
      }

      // 업데이트 데이터 준비
      final Map<String, dynamic> updates = {};

      if (displayName != null) {
        // 비즈니스 로직: 이름 길이 제한
        if (displayName.length > 50) {
          throw Exception('이름은 50자를 초과할 수 없습니다.');
        }
        updates['displayName'] = displayName;
      }

      if (phoneNumber != null) {
        // 비즈니스 로직: 전화번호 정규화 및 검증
        final normalizedPhone = _normalizePhoneNumber(phoneNumber);
        if (normalizedPhone.isEmpty) {
          throw Exception('유효한 전화번호를 입력해주세요.');
        }

        // 중복 검사 (본인 제외)
        final existingByPhone = await _contactRepository.findContactByPhone(
          normalizedPhone,
        );
        if (existingByPhone != null && existingByPhone.id != contactId) {
          throw Exception('이미 등록된 전화번호입니다.');
        }

        updates['phoneNumber'] = normalizedPhone;
      }

      if (email != null) {
        // 비즈니스 로직: 이메일 형식 검증
        if (email.isNotEmpty && !_isValidEmail(email)) {
          throw Exception('유효한 이메일 형식이 아닙니다.');
        }
        updates['email'] = email;
      }

      if (phoneNumbers != null) {
        updates['phoneNumbers'] = phoneNumbers;
      }

      if (emails != null) {
        // 모든 이메일 검증
        for (final emailAddr in emails) {
          if (emailAddr.isNotEmpty && !_isValidEmail(emailAddr)) {
            throw Exception('$emailAddr는 유효한 이메일 형식이 아닙니다.');
          }
        }
        updates['emails'] = emails;
      }

      if (type != null) {
        updates['type'] = type.name;
      }

      if (notes != null) {
        // 비즈니스 로직: 메모 길이 제한
        if (notes.length > 500) {
          throw Exception('메모는 500자를 초과할 수 없습니다.');
        }
        updates['notes'] = notes;
      }

      if (organization != null) {
        updates['organization'] = organization;
      }

      if (jobTitle != null) {
        updates['jobTitle'] = jobTitle;
      }

      if (updates.isEmpty) {
        return true; // 업데이트할 내용이 없음
      }

      return await _contactRepository.updateContactInFirestore(
        contactId: contactId,
        updates: updates,
      );
    } catch (e) {
      throw Exception('연락처 업데이트 중 오류가 발생했습니다: $e');
    }
  }

  /// 즐겨찾기 토글
  Future<bool> toggleFavorite(String contactId) async {
    try {
      final contact = await _contactRepository.getContactById(contactId);
      if (contact == null) {
        throw Exception('연락처를 찾을 수 없습니다.');
      }

      return await _contactRepository.toggleFavoriteInFirestore(
        contactId: contactId,
        isFavorite: !contact.isFavorite,
      );
    } catch (e) {
      throw Exception('즐겨찾기 토글 중 오류가 발생했습니다: $e');
    }
  }

  // ==================== 연락처 삭제 비즈니스 로직 ====================

  /// 연락처 삭제
  Future<bool> deleteContact({
    required String contactId,
    bool permanentDelete = false,
  }) async {
    try {
      final contact = await _contactRepository.getContactById(contactId);
      if (contact == null) {
        throw Exception('연락처를 찾을 수 없습니다.');
      }

      if (permanentDelete) {
        return await _contactRepository.permanentDeleteContactFromFirestore(
          contactId,
        );
      } else {
        return await _contactRepository.deleteContactFromFirestore(contactId);
      }
    } catch (e) {
      throw Exception('연락처 삭제 중 오류가 발생했습니다: $e');
    }
  }

  // ==================== 권한 관리 ====================

  /// 연락처 권한 확인
  Future<PermissionStatus> checkContactsPermission() async {
    return await _contactRepository.checkContactsPermission();
  }

  /// 연락처 권한 요청
  Future<bool> requestContactsPermission() async {
    return await _contactRepository.requestContactsPermission();
  }

  /// 설정 앱 열기
  Future<bool> openSettings() async {
    return await _contactRepository.openAppSetting();
  }

  // ==================== 디바이스 연락처 조회 ====================

  /// 디바이스 연락처 전체 조회
  Future<List<Contact>> getAllDeviceContacts() async {
    return await _contactRepository.getAllDeviceContacts();
  }

  /// 디바이스 연락처 검색
  Future<List<Contact>> searchDeviceContacts(String query) async {
    return await _contactRepository.searchDeviceContactsByName(query);
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 기존 ContactModel과의 호환성
  Stream<List<Map<String, dynamic>>> getContactsAsMapStream() {
    return _contactRepository.getContactsAsMapStream();
  }

  /// 기존 addContact 메서드 호환성
  Future<String> addContactLegacy(Map<String, dynamic> contactData) async {
    return await _contactRepository.addContact(contactData);
  }

  /// 기존 updateContact 메서드 호환성
  Future<void> updateContactLegacy(
    Map<String, dynamic> contactData,
    String contactId,
  ) async {
    return await _contactRepository.updateContact(contactData, contactId);
  }

  /// 기존 deleteContact 메서드 호환성
  Future<void> deleteContactLegacy(String contactId) async {
    return await _contactRepository.deleteContact(contactId);
  }

  // ==================== 통계 및 유틸리티 ====================

  /// 연락처 통계 조회
  Future<Map<String, int>> getContactStats() async {
    return await _contactRepository.getContactStats();
  }

  /// 연락처 이니셜 가져오기
  String getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';

    List<String> nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return nameParts[0][0] + nameParts[1][0];
    } else if (name.isNotEmpty) {
      return name[0];
    } else {
      return '?';
    }
  }

  /// 전화번호 포맷팅
  String formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return '번호 없음';
    }

    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 11 && cleaned.startsWith('010')) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    }

    return phone;
  }

  /// 연락처 아바타 위젯 생성
  Widget buildContactAvatar(Contact contact, {double radius = 20.0}) {
    if (contact.photo != null && contact.photo!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(contact.photo!),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue,
      child: Text(
        getInitials(contact.displayName),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  // ==================== 비즈니스 규칙 검증 ====================

  /// 연락처 검증
  ContactValidationResult _validateContact(ContactDataModel contact) {
    // 필수 필드 검증
    if (contact.displayName.isEmpty && contact.phoneNumber.isEmpty) {
      return ContactValidationResult.invalid('이름 또는 전화번호가 필요합니다.');
    }

    // 이름 길이 검증
    if (contact.displayName.length > 50) {
      return ContactValidationResult.invalid('이름은 50자를 초과할 수 없습니다.');
    }

    // 전화번호 검증
    if (contact.phoneNumber.isNotEmpty) {
      final normalizedPhone = _normalizePhoneNumber(contact.phoneNumber);
      if (normalizedPhone.isEmpty) {
        return ContactValidationResult.invalid('유효한 전화번호를 입력해주세요.');
      }
    }

    // 이메일 검증
    if (contact.email != null && contact.email!.isNotEmpty) {
      if (!_isValidEmail(contact.email!)) {
        return ContactValidationResult.invalid('유효한 이메일 형식이 아닙니다.');
      }
    }

    return ContactValidationResult.valid();
  }

  /// 연락처 타입 검증
  ContactValidationResult _validateContactType(ContactDataModel contact) {
    // 비즈니스 로직: 비상연락처는 전화번호 필수
    if (contact.type == ContactType.emergency && contact.phoneNumber.isEmpty) {
      return ContactValidationResult.invalid('비상연락처는 전화번호가 필수입니다.');
    }

    return ContactValidationResult.valid();
  }

  /// 연락처 비즈니스 규칙 적용
  List<ContactDataModel> _applyContactBusinessRules(
    List<ContactDataModel> contacts,
    ContactSearchFilter? filter,
  ) {
    // 활성 상태만 필터링 (기본)
    List<ContactDataModel> filteredContacts =
        contacts
            .where((contact) => contact.status == ContactStatus.active)
            .toList();

    // 텍스트 검색 (클라이언트 사이드)
    if (filter?.query != null && filter!.query!.isNotEmpty) {
      final query = filter.query!.toLowerCase();
      filteredContacts =
          filteredContacts.where((contact) {
            return contact.searchKeywords.any(
              (keyword) => keyword.contains(query),
            );
          }).toList();
    }

    // 정렬: 즐겨찾기 > 이름순
    filteredContacts.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return a.displayName.compareTo(b.displayName);
    });

    return filteredContacts;
  }

  /// 전화번호 정규화
  String _normalizePhoneNumber(String phone) {
    // 특수문자 제거 후 숫자만 남기기
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // 최소 길이 검증
    if (cleaned.length < 8) {
      return '';
    }

    // 한국 번호 형식 정규화
    if (cleaned.length == 11 && cleaned.startsWith('010')) {
      return cleaned;
    }

    // 기타 유효한 형식 확인
    if (cleaned.length >= 8 && cleaned.length <= 15) {
      return cleaned;
    }

    return '';
  }

  /// 이메일 형식 검증
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }
}

/// 연락처 검증 결과
class ContactValidationResult {
  final bool isValid;
  final String? error;

  ContactValidationResult._({required this.isValid, this.error});

  factory ContactValidationResult.valid() {
    return ContactValidationResult._(isValid: true);
  }

  factory ContactValidationResult.invalid(String error) {
    return ContactValidationResult._(isValid: false, error: error);
  }
}
