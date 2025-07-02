import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactsFirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 연락처 추가
  static Future<String?> addContact({
    required String name,
    required String email,
    String? phoneNumber,
    String? profileImageUrl,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final contactData = {
        'name': name,
        'email': email,
        'phoneNumber': phoneNumber,
        'profileImageUrl': profileImageUrl,
        'additionalInfo': additionalInfo ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isBlocked': false,
        'isFavorite': false,
        'sharedPhotosCount': 0,
      };

      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .add(contactData);

      return docRef.id;
    } catch (e) {
      print('Add contact error: $e');
      return null;
    }
  }

  // 모든 연락처 가져오기
  static Stream<QuerySnapshot> getContacts() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .where('isBlocked', isEqualTo: false)
        .orderBy('name')
        .snapshots();
  }

  // 즐겨찾기 연락처 가져오기
  static Stream<QuerySnapshot> getFavoriteContacts() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('contacts')
        .where('isFavorite', isEqualTo: true)
        .where('isBlocked', isEqualTo: false)
        .orderBy('name')
        .snapshots();
  }

  // 특정 연락처 가져오기
  static Future<DocumentSnapshot?> getContactById(String contactId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      return await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactId)
          .get();
    } catch (e) {
      print('Get contact by ID error: $e');
      return null;
    }
  }

  // 이메일로 연락처 찾기
  static Future<DocumentSnapshot?> getContactByEmail(String email) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final query =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('contacts')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      return query.docs.isNotEmpty ? query.docs.first : null;
    } catch (e) {
      print('Get contact by email error: $e');
      return null;
    }
  }

  // 연락처 업데이트
  static Future<bool> updateContact(
    String contactId, {
    String? name,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (email != null) updateData['email'] = email;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (profileImageUrl != null)
        updateData['profileImageUrl'] = profileImageUrl;
      if (additionalInfo != null) updateData['additionalInfo'] = additionalInfo;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactId)
          .update(updateData);

      return true;
    } catch (e) {
      print('Update contact error: $e');
      return false;
    }
  }

  // 연락처 즐겨찾기 토글
  static Future<bool> toggleFavorite(String contactId, bool isFavorite) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactId)
          .update({
            'isFavorite': isFavorite,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      print('Toggle favorite error: $e');
      return false;
    }
  }

  // 연락처 차단/차단해제
  static Future<bool> toggleBlock(String contactId, bool isBlocked) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactId)
          .update({
            'isBlocked': isBlocked,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      print('Toggle block error: $e');
      return false;
    }
  }

  // 연락처 삭제
  static Future<bool> deleteContact(String contactId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactId)
          .delete();

      return true;
    } catch (e) {
      print('Delete contact error: $e');
      return false;
    }
  }

  // 연락처와 공유된 사진들 가져오기
  static Stream<QuerySnapshot> getSharedPhotosWithContact(String contactEmail) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('shared_photos')
        .where('sharedWith', arrayContains: contactEmail)
        .orderBy('sharedAt', descending: true)
        .snapshots();
  }

  // 사진을 연락처와 공유
  static Future<bool> sharePhotoWithContact(
    String photoId,
    String photoUrl,
    String contactEmail,
    String contactName,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('shared_photos')
          .add({
            'photoId': photoId,
            'photoUrl': photoUrl,
            'sharedWith': [contactEmail],
            'sharedWithNames': [contactName],
            'sharedAt': FieldValue.serverTimestamp(),
            'message': '',
          });

      // 연락처의 공유된 사진 수 증가
      await _updateSharedPhotosCount(contactEmail, 1);

      return true;
    } catch (e) {
      print('Share photo with contact error: $e');
      return false;
    }
  }

  // 연락처 검색
  static Future<List<DocumentSnapshot>> searchContacts(String query) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final nameQuery =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('contacts')
              .where('name', isGreaterThanOrEqualTo: query)
              .where('name', isLessThanOrEqualTo: query + '\uf8ff')
              .where('isBlocked', isEqualTo: false)
              .get();

      final emailQuery =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('contacts')
              .where('email', isGreaterThanOrEqualTo: query)
              .where('email', isLessThanOrEqualTo: query + '\uf8ff')
              .where('isBlocked', isEqualTo: false)
              .get();

      final allResults = <DocumentSnapshot>[];
      allResults.addAll(nameQuery.docs);

      // 중복 제거
      for (final doc in emailQuery.docs) {
        if (!allResults.any((existing) => existing.id == doc.id)) {
          allResults.add(doc);
        }
      }

      return allResults;
    } catch (e) {
      print('Search contacts error: $e');
      return [];
    }
  }

  // 연락처의 공유된 사진 수 업데이트
  static Future<void> _updateSharedPhotosCount(
    String contactEmail,
    int increment,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final contactDoc = await getContactByEmail(contactEmail);
      if (contactDoc != null && contactDoc.exists) {
        final currentCount =
            (contactDoc.data() as Map<String, dynamic>)['sharedPhotosCount'] ??
            0;
        await contactDoc.reference.update({
          'sharedPhotosCount': currentCount + increment,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Update shared photos count error: $e');
    }
  }
}
