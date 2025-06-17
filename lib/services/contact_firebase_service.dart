import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/contact_model.dart';

/// 연락처 정보를 Firebase에 저장하고 관리하는 서비스
class ContactFirebaseService {
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
}
