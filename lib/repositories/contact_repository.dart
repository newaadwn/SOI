import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/contact_data_model.dart';

/// Contact Repository - Firebase와 디바이스 연락처 관련 모든 데이터 액세스 로직을 담당
class ContactRepository {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Permission _contactsPermission = Permission.contacts;

  // ==================== Firebase 연락처 관리 ====================

  /// 현재 사용자 ID 가져오기
  String? get _userId => _auth.currentUser?.uid;

  /// 친구 컬렉션 참조 가져오기
  CollectionReference<Map<String, dynamic>> get _friendsCollection {
    if (_userId == null) {
      throw Exception('사용자가 로그인되어 있지 않습니다.');
    }
    return _firestore.collection('users').doc(_userId).collection('friends');
  }

  /// 연락처를 Firestore에 저장
  Future<String?> saveContactToFirestore(ContactDataModel contact) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      final docRef = await _friendsCollection.add(contact.toFirestore());
      return docRef.id;
    } catch (e) {
      debugPrint('연락처 저장 오류: $e');
      return null;
    }
  }

  /// Firestore에서 연락처 목록 조회
  Future<List<ContactDataModel>> getContactsFromFirestore() async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      final querySnapshot =
          await _friendsCollection
              .where('status', isEqualTo: ContactStatus.active.name)
              .orderBy('createdAt', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => ContactDataModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('연락처 목록 조회 오류: $e');
      return [];
    }
  }

  /// Firestore에서 연락처 목록 스트림
  Stream<List<ContactDataModel>> getContactsStreamFromFirestore() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _friendsCollection
        .where('status', isEqualTo: ContactStatus.active.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => ContactDataModel.fromFirestore(doc.data(), doc.id),
                  )
                  .toList(),
        );
  }

  /// 특정 연락처 조회
  Future<ContactDataModel?> getContactById(String contactId) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      final doc = await _friendsCollection.doc(contactId).get();

      if (doc.exists && doc.data() != null) {
        return ContactDataModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('연락처 조회 오류: $e');
      return null;
    }
  }

  /// 전화번호로 연락처 검색
  Future<ContactDataModel?> findContactByPhone(String phoneNumber) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      final querySnapshot =
          await _friendsCollection
              .where('phoneNumber', isEqualTo: phoneNumber)
              .where('status', isEqualTo: ContactStatus.active.name)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return ContactDataModel.fromFirestore(doc.data(), doc.id);
      }

      return null;
    } catch (e) {
      debugPrint('전화번호로 연락처 검색 오류: $e');
      return null;
    }
  }

  /// 연락처 업데이트
  Future<bool> updateContactInFirestore({
    required String contactId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      updates['updatedAt'] = Timestamp.now();

      await _friendsCollection.doc(contactId).update(updates);
      return true;
    } catch (e) {
      debugPrint('연락처 업데이트 오류: $e');
      return false;
    }
  }

  /// 연락처 삭제 (soft delete)
  Future<bool> deleteContactFromFirestore(String contactId) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      await _friendsCollection.doc(contactId).update({
        'status': ContactStatus.deleted.name,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint('연락처 삭제 오류: $e');
      return false;
    }
  }

  /// 연락처 완전 삭제 (hard delete)
  Future<bool> permanentDeleteContactFromFirestore(String contactId) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      await _friendsCollection.doc(contactId).delete();
      return true;
    } catch (e) {
      debugPrint('연락처 완전 삭제 오류: $e');
      return false;
    }
  }

  /// 즐겨찾기 토글
  Future<bool> toggleFavoriteInFirestore({
    required String contactId,
    required bool isFavorite,
  }) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      await _friendsCollection.doc(contactId).update({
        'isFavorite': isFavorite,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint('즐겨찾기 토글 오류: $e');
      return false;
    }
  }

  /// 연락처 검색 (필터링)
  Future<List<ContactDataModel>> searchContactsInFirestore({
    required ContactSearchFilter filter,
  }) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      Query query = _friendsCollection;

      // 상태 필터링
      if (filter.status != null) {
        query = query.where('status', isEqualTo: filter.status!.name);
      } else {
        query = query.where('status', isEqualTo: ContactStatus.active.name);
      }

      // 타입 필터링
      if (filter.type != null) {
        query = query.where('type', isEqualTo: filter.type!.name);
      }

      // 즐겨찾기 필터링
      if (filter.isFavorite != null) {
        query = query.where('isFavorite', isEqualTo: filter.isFavorite!);
      }

      // 날짜 범위 필터링
      if (filter.startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(filter.startDate!),
        );
      }
      if (filter.endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(filter.endDate!),
        );
      }

      query = query.orderBy('createdAt', descending: true);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map(
            (doc) => ContactDataModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('연락처 검색 오류: $e');
      return [];
    }
  }

  // ==================== 디바이스 연락처 관리 ====================

  /// 연락처 권한 상태 확인
  Future<PermissionStatus> checkContactsPermission() async {
    return await _contactsPermission.status;
  }

  /// 연락처 권한 요청
  Future<bool> requestContactsPermission() async {
    return await FlutterContacts.requestPermission();
  }

  /// 설정 앱으로 이동
  Future<bool> openAppSetting() async {
    return await openAppSettings();
  }

  /// 디바이스에서 모든 연락처 가져오기
  Future<List<Contact>> getAllDeviceContacts() async {
    try {
      // 연락처 권한 확인
      final permissionStatus = await checkContactsPermission();
      if (permissionStatus != PermissionStatus.granted) {
        throw Exception('연락처 권한이 필요합니다');
      }

      // Flutter Contacts로 직접 권한 재확인
      if (!await FlutterContacts.requestPermission()) {
        throw Exception('연락처 권한이 거부되었습니다');
      }

      final List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      return contacts;
    } catch (e) {
      debugPrint('디바이스 연락처 가져오기 오류: $e');
      return [];
    }
  }

  /// 이름으로 디바이스 연락처 검색
  Future<List<Contact>> searchDeviceContactsByName(String query) async {
    try {
      final contacts = await getAllDeviceContacts();
      return _filterDeviceContacts(contacts, query);
    } catch (e) {
      debugPrint('디바이스 연락처 검색 오류: $e');
      return [];
    }
  }

  /// 특정 연락처 ID로 디바이스 연락처 조회
  Future<Contact?> getDeviceContactById(String contactId) async {
    try {
      final permissionStatus = await checkContactsPermission();
      if (permissionStatus != PermissionStatus.granted) {
        return null;
      }

      return await FlutterContacts.getContact(
        contactId,
        withProperties: true,
        withPhoto: true,
      );
    } catch (e) {
      debugPrint('디바이스 연락처 조회 오류: $e');
      return null;
    }
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 기존 ContactModel과의 호환성을 위한 메서드
  Stream<List<Map<String, dynamic>>> getContactsAsMapStream() {
    if (_userId == null) {
      return Stream.value([]);
    }

    return _friendsCollection
        .where('status', isEqualTo: ContactStatus.active.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              }).toList(),
        );
  }

  /// 기존 ContactModel과의 호환성을 위한 추가 메서드
  Future<String> addContact(Map<String, dynamic> contactData) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      final docRef = await _friendsCollection.add(contactData);
      return docRef.id;
    } catch (e) {
      debugPrint('연락처 추가 오류: $e');
      rethrow;
    }
  }

  /// 기존 ContactModel과의 호환성을 위한 업데이트 메서드
  Future<void> updateContact(
    Map<String, dynamic> contactData,
    String contactId,
  ) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      await _friendsCollection.doc(contactId).update(contactData);
    } catch (e) {
      debugPrint('연락처 업데이트 오류: $e');
      rethrow;
    }
  }

  /// 기존 ContactModel과의 호환성을 위한 삭제 메서드
  Future<void> deleteContact(String contactId) async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      await _friendsCollection.doc(contactId).delete();
    } catch (e) {
      debugPrint('연락처 삭제 오류: $e');
      rethrow;
    }
  }

  // ==================== 유틸리티 메서드 ====================

  /// 디바이스 연락처 필터링
  List<Contact> _filterDeviceContacts(List<Contact> contacts, String query) {
    if (query.isEmpty) {
      return contacts;
    }

    final String lowercaseQuery = query.toLowerCase();

    return contacts.where((contact) {
      final String name = contact.displayName.toLowerCase();
      final String phone =
          contact.phones.isNotEmpty
              ? contact.phones.first.number.toLowerCase()
              : '';

      return name.contains(lowercaseQuery) || phone.contains(lowercaseQuery);
    }).toList();
  }

  /// 연락처 통계 조회
  Future<Map<String, int>> getContactStats() async {
    try {
      if (_userId == null) {
        throw Exception('사용자가 로그인되어 있지 않습니다.');
      }

      final querySnapshot = await _friendsCollection.get();

      int totalContacts = 0;
      int activeContacts = 0;
      int favoriteContacts = 0;
      int deletedContacts = 0;

      for (final doc in querySnapshot.docs) {
        totalContacts++;
        final data = doc.data();
        final status = data['status'] ?? ContactStatus.active.name;
        final isFavorite = data['isFavorite'] ?? false;

        if (status == ContactStatus.active.name) {
          activeContacts++;
          if (isFavorite) {
            favoriteContacts++;
          }
        } else if (status == ContactStatus.deleted.name) {
          deletedContacts++;
        }
      }

      return {
        'total': totalContacts,
        'active': activeContacts,
        'favorite': favoriteContacts,
        'deleted': deletedContacts,
      };
    } catch (e) {
      debugPrint('연락처 통계 조회 오류: $e');
      return {'total': 0, 'active': 0, 'favorite': 0, 'deleted': 0};
    }
  }

  /// 중복 연락처 확인
  Future<bool> isContactExists(String phoneNumber) async {
    try {
      final contact = await findContactByPhone(phoneNumber);
      return contact != null;
    } catch (e) {
      debugPrint('연락처 존재 확인 오류: $e');
      return false;
    }
  }
}
