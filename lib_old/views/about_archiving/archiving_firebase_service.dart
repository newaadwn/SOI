import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class ArchivingFirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // 사진 업로드
  static Future<String?> uploadPhoto(File imageFile, String category) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final storageRef = _storage
          .ref()
          .child('photos')
          .child(user.uid)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await storageRef.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Firestore에 메타데이터 저장
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('photos')
          .add({
            'url': downloadUrl,
            'category': category,
            'createdAt': FieldValue.serverTimestamp(),
            'isShared': false,
          });

      return downloadUrl;
    } catch (e) {
      print('Photo upload error: $e');
      return null;
    }
  }

  // 모든 아카이브 가져오기
  static Stream<QuerySnapshot> getAllArchives() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('photos')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 개인 아카이브 가져오기
  static Stream<QuerySnapshot> getPersonalArchives() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('photos')
        .where('isShared', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 공유된 아카이브 가져오기
  static Stream<QuerySnapshot> getSharedArchives() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('photos')
        .where('isShared', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 카테고리별 사진 가져오기
  static Stream<QuerySnapshot> getCategoryPhotos(String category) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('photos')
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 사진 삭제
  static Future<bool> deletePhoto(String docId, String imageUrl) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Firestore에서 삭제
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('photos')
          .doc(docId)
          .delete();

      // Storage에서 삭제
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();

      return true;
    } catch (e) {
      print('Delete photo error: $e');
      return false;
    }
  }

  // 사진 공유 상태 변경
  static Future<bool> toggleShareStatus(String docId, bool isShared) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('photos')
          .doc(docId)
          .update({'isShared': isShared});

      return true;
    } catch (e) {
      print('Toggle share status error: $e');
      return false;
    }
  }
}
