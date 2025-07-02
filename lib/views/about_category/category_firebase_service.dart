import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CategoryFirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 새 카테고리 생성
  static Future<String?> createCategory({
    required String name,
    required String description,
    String? color,
    String? icon,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final categoryData = {
        'name': name,
        'description': description,
        'color': color ?? '#2196F3',
        'icon': icon ?? 'folder',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'photoCount': 0,
        'isDefault': false,
      };

      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .add(categoryData);

      return docRef.id;
    } catch (e) {
      print('Create category error: $e');
      return null;
    }
  }

  // 모든 카테고리 가져오기
  static Stream<QuerySnapshot> getCategories() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // 특정 카테고리 가져오기
  static Future<DocumentSnapshot?> getCategoryById(String categoryId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      return await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId)
          .get();
    } catch (e) {
      print('Get category by ID error: $e');
      return null;
    }
  }

  // 카테고리 업데이트
  static Future<bool> updateCategory(
    String categoryId, {
    String? name,
    String? description,
    String? color,
    String? icon,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (description != null) updateData['description'] = description;
      if (color != null) updateData['color'] = color;
      if (icon != null) updateData['icon'] = icon;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId)
          .update(updateData);

      return true;
    } catch (e) {
      print('Update category error: $e');
      return false;
    }
  }

  // 카테고리 삭제
  static Future<bool> deleteCategory(String categoryId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 카테고리에 속한 사진들을 'uncategorized'로 이동
      final batch = _firestore.batch();

      // 해당 카테고리의 사진들 찾기
      final photosQuery =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('photos')
              .where('category', isEqualTo: categoryId)
              .get();

      // 각 사진의 카테고리를 'uncategorized'로 변경
      for (final doc in photosQuery.docs) {
        batch.update(doc.reference, {'category': 'uncategorized'});
      }

      // 카테고리 삭제
      final categoryRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId);

      batch.delete(categoryRef);

      await batch.commit();
      return true;
    } catch (e) {
      print('Delete category error: $e');
      return false;
    }
  }

  // 카테고리별 사진 개수 업데이트
  static Future<bool> updateCategoryPhotoCount(String categoryId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // 해당 카테고리의 사진 개수 계산
      final photosQuery =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('photos')
              .where('category', isEqualTo: categoryId)
              .get();

      final photoCount = photosQuery.docs.length;

      // 카테고리 문서 업데이트
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .doc(categoryId)
          .update({
            'photoCount': photoCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      return true;
    } catch (e) {
      print('Update category photo count error: $e');
      return false;
    }
  }

  // 기본 카테고리들 생성
  static Future<bool> createDefaultCategories() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final defaultCategories = [
        {
          'name': '일반',
          'description': '일반적인 사진들',
          'color': '#2196F3',
          'icon': 'photo',
          'isDefault': true,
        },
        {
          'name': '가족',
          'description': '가족과 함께한 소중한 순간들',
          'color': '#4CAF50',
          'icon': 'family',
          'isDefault': true,
        },
        {
          'name': '여행',
          'description': '여행 중 담은 추억들',
          'color': '#FF9800',
          'icon': 'travel',
          'isDefault': true,
        },
        {
          'name': '음식',
          'description': '맛있는 음식 사진들',
          'color': '#F44336',
          'icon': 'restaurant',
          'isDefault': true,
        },
      ];

      final batch = _firestore.batch();

      for (final category in defaultCategories) {
        final docRef =
            _firestore
                .collection('users')
                .doc(user.uid)
                .collection('categories')
                .doc();

        batch.set(docRef, {
          ...category,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'photoCount': 0,
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Create default categories error: $e');
      return false;
    }
  }

  // 카테고리별 사진 통계 가져오기
  static Future<Map<String, int>> getCategoryPhotoStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final stats = <String, int>{};

      // 모든 사진 가져오기
      final photosQuery =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('photos')
              .get();

      // 카테고리별로 개수 계산
      for (final doc in photosQuery.docs) {
        final data = doc.data();
        final category = data['category'] as String? ?? 'uncategorized';
        stats[category] = (stats[category] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Get category photo stats error: $e');
      return {};
    }
  }
}
