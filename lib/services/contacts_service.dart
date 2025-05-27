import 'package:contacts_service/contacts_service.dart' as contact_plugin;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// 연락처 관련 서비스를 담당하는 클래스
/// 연락처 권한 관리와 연락처 데이터 접근을 처리합니다.
class ContactsService {
  /// 연락처 접근 권한 상태 확인
  Future<PermissionStatus> checkContactsPermission() async {
    // 현재 연락처 권한 상태를 반환합니다
    return await Permission.contacts.status;
  }

  /// 연락처 접근 권한 요청
  Future<PermissionStatus> requestContactsPermission() async {
    // 사용자에게 연락처 권한을 요청하고 결과를 반환합니다
    return await Permission.contacts.request();
  }

  /// 설정 앱으로 이동
  Future<bool> openSettings() async {
    // 사용자가 직접 권한을 설정할 수 있도록 설정 앱으로 이동합니다
    return await openAppSettings();
  }

  /// 모든 연락처 가져오기
  Future<List<contact_plugin.Contact>> getAllContacts() async {
    // 모든 연락처 목록을 가져옵니다
    final Iterable<contact_plugin.Contact> contacts =
        await contact_plugin.ContactsService.getContacts();
    return contacts.toList();
  }

  /// 이름으로 연락처 검색
  Future<List<contact_plugin.Contact>> searchContactsByName(
    String query,
  ) async {
    // 주어진 이름으로 연락처를 검색합니다
    final Iterable<contact_plugin.Contact> contacts = await contact_plugin
        .ContactsService.getContacts(query: query);
    return contacts.toList();
  }

  /// 연락처 목록 필터링 (이미 불러온 연락처에서 검색)
  List<contact_plugin.Contact> filterContacts(
    List<contact_plugin.Contact> contacts,
    String query,
  ) {
    if (query.isEmpty) {
      // 검색어가 없으면 모든 연락처 반환
      return contacts;
    }

    // 검색어를 소문자로 변환 (대소문자 구분 없이 검색하기 위함)
    final String lowercaseQuery = query.toLowerCase();

    // 이름이나 전화번호에 검색어가 포함된 연락처만 필터링
    return contacts.where((contact) {
      // 이름에서 검색
      final String name = contact.displayName?.toLowerCase() ?? '';

      // 전화번호에서 검색
      final String phone =
          contact.phones?.isNotEmpty == true
              ? (contact.phones!.first.value?.toLowerCase() ?? '')
              : '';

      // 이름이나 전화번호에 검색어가 포함되면 true 반환
      return name.contains(lowercaseQuery) || phone.contains(lowercaseQuery);
    }).toList();
  }

  /// 연락처 이니셜 가져오기
  String getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';

    // 이름을 공백으로 분리
    List<String> nameParts = name.split(' ');

    // 이름이 여러 부분으로 이루어진 경우 첫 글자 + 두번째 부분 첫 글자
    if (nameParts.length > 1) {
      return nameParts[0][0] + nameParts[1][0];
    }
    // 이름이 한 부분만 있는 경우 첫 글자만 사용
    else if (name.isNotEmpty) {
      return name[0];
    }
    // 이름이 없는 경우 물음표 반환
    else {
      return '?';
    }
  }

  /// 연락처 아바타 위젯 생성
  Widget buildContactAvatar(
    contact_plugin.Contact contact, {
    double radius = 20.0,
  }) {
    // 프로필 이미지가 있는 경우
    if (contact.avatar != null && contact.avatar!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(contact.avatar!),
      );
    }

    // 프로필 이미지가 없는 경우 이니셜 표시
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.blue,
      child: Text(
        getInitials(contact.displayName),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  /// 전화번호 포맷팅 (예: 010-1234-5678)
  String formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return '번호 없음';
    }

    // 특수문자 제거 (숫자만 남김)
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // 한국 전화번호 포맷 (010-XXXX-XXXX)
    if (cleaned.length == 11 && cleaned.startsWith('010')) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    }

    // 기타 전화번호는 원래 형식 반환
    return phone;
  }
}
