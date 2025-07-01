import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_swift_camera/models/contact_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

/// 연락처 관련 서비스를 담당하는 클래스
/// 연락처 권한 관리와 연락처 데이터 접근을 처리합니다.
class ContactsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 로그인한 사용자 ID 가져오기
  String? get _userId => _auth.currentUser?.uid;

  // 친구 컬렉션 참조 가져오기
  CollectionReference<Map<String, dynamic>> get _friendsCollection {
    // 사용자가 로그인하지 않은 경우 예외 발생
    if (_userId == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다.');
    }

    return _firestore.collection('users').doc(_userId).collection('friends');
  }

  /// 친구 추가
  Future<String> addContact(ContactModel contact) async {
    try {
      final docRef = await _friendsCollection.add(contact.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('친구 추가 오류: $e');
      rethrow;
    }
  }

  /// 친구 목록 가져오기
  Stream<List<ContactModel>> getContacts() {
    try {
      return _friendsCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return ContactModel.fromMap(doc.data(), doc.id);
            }).toList();
          });
    } catch (e) {
      debugPrint('친구 목록 가져오기 오류: $e');
      rethrow;
    }
  }

  /// 친구 삭제
  Future<void> deleteContact(String contactId) async {
    try {
      await _friendsCollection.doc(contactId).delete();
    } catch (e) {
      debugPrint('친구 삭제 오류: $e');
      rethrow;
    }
  }

  /// 친구 정보 업데이트
  Future<void> updateContact(ContactModel contact) async {
    try {
      if (contact.id == null) {
        throw Exception('친구 ID가 없습니다.');
      }

      await _friendsCollection.doc(contact.id).update(contact.toMap());
    } catch (e) {
      debugPrint('친구 정보 업데이트 오류: $e');
      rethrow;
    }
  }

  /// 전화번호로 친구 검색
  Future<ContactModel?> findContactByPhone(String phoneNumber) async {
    try {
      final snapshot =
          await _friendsCollection
              .where('phoneNumber', isEqualTo: phoneNumber)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return ContactModel.fromMap(
          snapshot.docs.first.data(),
          snapshot.docs.first.id,
        );
      }

      return null;
    } catch (e) {
      debugPrint('전화번호로 친구 검색 오류: $e');
      rethrow;
    }
  }

  /// 이미 저장된 친구인지 확인
  Future<bool> isContactExists(String phoneNumber) async {
    try {
      final contact = await findContactByPhone(phoneNumber);
      return contact != null;
    } catch (e) {
      debugPrint('친구 존재 확인 오류: $e');
      return false;
    }
  }

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
  Future<List<Contact>> getAllContacts() async {
    // 연락처 권한 확인
    if (!await FlutterContacts.requestPermission()) {
      throw Exception('연락처 권한이 필요합니다');
    }

    // 모든 연락처 목록을 가져옵니다 (전화번호와 이메일 포함)
    final List<Contact> contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: true,
    );
    return contacts;
  }

  /// 이름으로 연락처 검색
  Future<List<Contact>> searchContactsByName(String query) async {
    // 모든 연락처를 가져온 후 필터링
    final contacts = await getAllContacts();
    return filterContacts(contacts, query);
  }

  /// 연락처 목록 필터링 (이미 불러온 연락처에서 검색)
  List<Contact> filterContacts(List<Contact> contacts, String query) {
    if (query.isEmpty) {
      // 검색어가 없으면 모든 연락처 반환
      return contacts;
    }

    // 검색어를 소문자로 변환 (대소문자 구분 없이 검색하기 위함)
    final String lowercaseQuery = query.toLowerCase();

    // 이름이나 전화번호에 검색어가 포함된 연락처만 필터링
    return contacts.where((contact) {
      // 이름에서 검색
      final String name = contact.displayName.toLowerCase();

      // 전화번호에서 검색
      final String phone =
          contact.phones.isNotEmpty
              ? contact.phones.first.number.toLowerCase()
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
  Widget buildContactAvatar(Contact contact, {double radius = 20.0}) {
    // 프로필 이미지가 있는 경우
    if (contact.photo != null && contact.photo!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(contact.photo!),
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
