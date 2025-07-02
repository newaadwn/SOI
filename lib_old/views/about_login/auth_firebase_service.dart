import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthFirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 사용자 가져오기
  static User? get currentUser => _auth.currentUser;

  // 인증 상태 변화 스트림
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 이메일/비밀번호로 회원가입
  static Future<UserCredential?> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 사용자 프로필 업데이트
      await credential.user?.updateDisplayName(displayName);

      // Firestore에 사용자 정보 저장
      await _createUserDocument(credential.user!, displayName);

      return credential;
    } on FirebaseAuthException catch (e) {
      print('Registration error: ${e.message}');
      throw e;
    } catch (e) {
      print('Unexpected registration error: $e');
      throw e;
    }
  }

  // 이메일/비밀번호로 로그인
  static Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 마지막 로그인 시간 업데이트
      await _updateLastLoginTime(credential.user!);

      return credential;
    } on FirebaseAuthException catch (e) {
      print('Sign in error: ${e.message}');
      throw e;
    } catch (e) {
      print('Unexpected sign in error: $e');
      throw e;
    }
  }

  // 로그아웃
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
      throw e;
    }
  }

  // 비밀번호 재설정 이메일 보내기
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.message}');
      throw e;
    } catch (e) {
      print('Unexpected password reset error: $e');
      throw e;
    }
  }

  // 비밀번호 변경
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // 현재 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // 새 비밀번호로 업데이트
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      print('Change password error: ${e.message}');
      throw e;
    } catch (e) {
      print('Unexpected change password error: $e');
      throw e;
    }
  }

  // 이메일 인증 보내기
  static Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      print('Send email verification error: $e');
      throw e;
    }
  }

  // 사용자 프로필 업데이트
  static Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      await user.updateProfile(displayName: displayName, photoURL: photoURL);

      // Firestore의 사용자 정보도 업데이트
      await _firestore.collection('users').doc(user.uid).update({
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Update user profile error: $e');
      throw e;
    }
  }

  // 계정 삭제
  static Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      // 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Firestore에서 사용자 데이터 삭제
      await _deleteUserData(user.uid);

      // 계정 삭제
      await user.delete();
    } on FirebaseAuthException catch (e) {
      print('Delete account error: ${e.message}');
      throw e;
    } catch (e) {
      print('Unexpected delete account error: $e');
      throw e;
    }
  }

  // 사용자 문서 생성
  static Future<void> _createUserDocument(User user, String displayName) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isEmailVerified': user.emailVerified,
        'settings': {
          'notifications': true,
          'darkMode': false,
          'language': 'ko',
        },
      });

      // 기본 카테고리 생성
      await _createDefaultUserCategories(user.uid);
    } catch (e) {
      print('Create user document error: $e');
    }
  }

  // 마지막 로그인 시간 업데이트
  static Future<void> _updateLastLoginTime(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isEmailVerified': user.emailVerified,
      });
    } catch (e) {
      print('Update last login time error: $e');
    }
  }

  // 사용자 데이터 삭제
  static Future<void> _deleteUserData(String uid) async {
    try {
      final batch = _firestore.batch();

      // 사용자 문서 삭제
      batch.delete(_firestore.collection('users').doc(uid));

      // 하위 컬렉션들 삭제 (photos, categories, contacts 등)
      final collections = [
        'photos',
        'categories',
        'contacts',
        'shared_photos',
        'camera_photos',
      ];

      for (final collectionName in collections) {
        final querySnapshot =
            await _firestore
                .collection('users')
                .doc(uid)
                .collection(collectionName)
                .get();

        for (final doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
    } catch (e) {
      print('Delete user data error: $e');
    }
  }

  // 기본 사용자 카테고리 생성
  static Future<void> _createDefaultUserCategories(String uid) async {
    try {
      final defaultCategories = [
        {'name': '일반', 'color': '#2196F3', 'icon': 'photo'},
        {'name': '가족', 'color': '#4CAF50', 'icon': 'family'},
        {'name': '여행', 'color': '#FF9800', 'icon': 'travel'},
        {'name': '음식', 'color': '#F44336', 'icon': 'restaurant'},
      ];

      final batch = _firestore.batch();

      for (final category in defaultCategories) {
        final docRef =
            _firestore
                .collection('users')
                .doc(uid)
                .collection('categories')
                .doc();

        batch.set(docRef, {
          ...category,
          'createdAt': FieldValue.serverTimestamp(),
          'photoCount': 0,
          'isDefault': true,
        });
      }

      await batch.commit();
    } catch (e) {
      print('Create default user categories error: $e');
    }
  }

  // 사용자 정보 가져오기
  static Future<DocumentSnapshot?> getUserDocument() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      return await _firestore.collection('users').doc(user.uid).get();
    } catch (e) {
      print('Get user document error: $e');
      return null;
    }
  }

  // 사용자 설정 업데이트
  static Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No user signed in');

      await _firestore.collection('users').doc(user.uid).update({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Update user settings error: $e');
      throw e;
    }
  }
}
