import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class CameraFirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // 카메라로 찍은 사진 업로드
  static Future<String?> uploadCameraPhoto(
    File imageFile, {
    String? category,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage
          .ref()
          .child('camera_photos')
          .child(user.uid)
          .child(fileName);

      final uploadTask = await storageRef.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Firestore에 사진 정보 저장
      final photoData = {
        'url': downloadUrl,
        'fileName': fileName,
        'category': category ?? 'uncategorized',
        'createdAt': FieldValue.serverTimestamp(),
        'capturedAt': DateTime.now().toIso8601String(),
        'isEdited': false,
        'metadata': metadata ?? {},
      };

      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('camera_photos')
          .add(photoData);

      return docRef.id;
    } catch (e) {
      print('Camera photo upload error: $e');
      return null;
    }
  }

  // 편집된 사진 저장
  static Future<bool> saveEditedPhoto(
    String originalPhotoId,
    File editedImageFile,
    Map<String, dynamic> editingData,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 편집된 사진 업로드
      final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage
          .ref()
          .child('edited_photos')
          .child(user.uid)
          .child(fileName);

      final uploadTask = await storageRef.putFile(editedImageFile);
      final editedUrl = await uploadTask.ref.getDownloadURL();

      // 원본 사진 문서 업데이트
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('camera_photos')
          .doc(originalPhotoId)
          .update({
            'editedUrl': editedUrl,
            'isEdited': true,
            'editingData': editingData,
            'editedAt': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      print('Save edited photo error: $e');
      return false;
    }
  }

  // 카메라 사진 목록 가져오기
  static Stream<QuerySnapshot> getCameraPhotos() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('camera_photos')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 특정 사진 정보 가져오기
  static Future<DocumentSnapshot?> getPhotoById(String photoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      return await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('camera_photos')
          .doc(photoId)
          .get();
    } catch (e) {
      print('Get photo by ID error: $e');
      return null;
    }
  }

  // 사진 삭제
  static Future<bool> deleteCameraPhoto(String photoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final photoDoc =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('camera_photos')
              .doc(photoId)
              .get();

      if (photoDoc.exists) {
        final data = photoDoc.data() as Map<String, dynamic>;

        // 원본 사진 삭제
        if (data['url'] != null) {
          final originalRef = _storage.refFromURL(data['url']);
          await originalRef.delete();
        }

        // 편집된 사진이 있다면 삭제
        if (data['editedUrl'] != null) {
          final editedRef = _storage.refFromURL(data['editedUrl']);
          await editedRef.delete();
        }

        // Firestore 문서 삭제
        await photoDoc.reference.delete();
      }

      return true;
    } catch (e) {
      print('Delete camera photo error: $e');
      return false;
    }
  }

  // 사진 카테고리 업데이트
  static Future<bool> updatePhotoCategory(
    String photoId,
    String category,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('camera_photos')
          .doc(photoId)
          .update({
            'category': category,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      print('Update photo category error: $e');
      return false;
    }
  }
}
