import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingFirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // 사용자 설정 가져오기
  static Future<Map<String, dynamic>?> getUserSettings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['settings'] as Map<String, dynamic>? ?? {};
      }

      return {};
    } catch (e) {
      print('Get user settings error: $e');
      return null;
    }
  }

  // 사용자 설정 업데이트
  static Future<bool> updateUserSettings(Map<String, dynamic> settings) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).update({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Update user settings error: $e');
      return false;
    }
  }

  // 특정 설정값 업데이트
  static Future<bool> updateSetting(String key, dynamic value) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).update({
        'settings.$key': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Update setting error: $e');
      return false;
    }
  }

  // 알림 설정 업데이트
  static Future<bool> updateNotificationSettings({
    bool? pushNotifications,
    bool? emailNotifications,
    bool? photoSharedNotifications,
    bool? newContactNotifications,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (pushNotifications != null) {
        updates['settings.notifications.push'] = pushNotifications;
      }
      if (emailNotifications != null) {
        updates['settings.notifications.email'] = emailNotifications;
      }
      if (photoSharedNotifications != null) {
        updates['settings.notifications.photoShared'] =
            photoSharedNotifications;
      }
      if (newContactNotifications != null) {
        updates['settings.notifications.newContact'] = newContactNotifications;
      }

      await _firestore.collection('users').doc(user.uid).update(updates);

      return true;
    } catch (e) {
      print('Update notification settings error: $e');
      return false;
    }
  }

  // 프라이버시 설정 업데이트
  static Future<bool> updatePrivacySettings({
    bool? publicProfile,
    bool? allowContactRequests,
    bool? showOnlineStatus,
    String? photoSharingPermission, // 'everyone', 'contacts', 'nobody'
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (publicProfile != null) {
        updates['settings.privacy.publicProfile'] = publicProfile;
      }
      if (allowContactRequests != null) {
        updates['settings.privacy.allowContactRequests'] = allowContactRequests;
      }
      if (showOnlineStatus != null) {
        updates['settings.privacy.showOnlineStatus'] = showOnlineStatus;
      }
      if (photoSharingPermission != null) {
        updates['settings.privacy.photoSharingPermission'] =
            photoSharingPermission;
      }

      await _firestore.collection('users').doc(user.uid).update(updates);

      return true;
    } catch (e) {
      print('Update privacy settings error: $e');
      return false;
    }
  }

  // 앱 설정 업데이트
  static Future<bool> updateAppSettings({
    bool? darkMode,
    String? language,
    String? imageQuality, // 'high', 'medium', 'low'
    bool? autoBackup,
    bool? wifiOnlyBackup,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (darkMode != null) {
        updates['settings.app.darkMode'] = darkMode;
      }
      if (language != null) {
        updates['settings.app.language'] = language;
      }
      if (imageQuality != null) {
        updates['settings.app.imageQuality'] = imageQuality;
      }
      if (autoBackup != null) {
        updates['settings.app.autoBackup'] = autoBackup;
      }
      if (wifiOnlyBackup != null) {
        updates['settings.app.wifiOnlyBackup'] = wifiOnlyBackup;
      }

      await _firestore.collection('users').doc(user.uid).update(updates);

      return true;
    } catch (e) {
      print('Update app settings error: $e');
      return false;
    }
  }

  // 사용자 프로필 정보 업데이트
  static Future<bool> updateUserProfile({
    String? displayName,
    String? bio,
    String? profileImageUrl,
    DateTime? birthDate,
    String? location,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) {
        updates['displayName'] = displayName;
        // Firebase Auth 프로필도 업데이트
        await user.updateDisplayName(displayName);
      }
      if (bio != null) {
        updates['bio'] = bio;
      }
      if (profileImageUrl != null) {
        updates['photoURL'] = profileImageUrl;
        // Firebase Auth 프로필도 업데이트
        await user.updatePhotoURL(profileImageUrl);
      }
      if (birthDate != null) {
        updates['birthDate'] = Timestamp.fromDate(birthDate);
      }
      if (location != null) {
        updates['location'] = location;
      }

      await _firestore.collection('users').doc(user.uid).update(updates);

      return true;
    } catch (e) {
      print('Update user profile error: $e');
      return false;
    }
  }

  // 계정 통계 가져오기
  static Future<Map<String, dynamic>?> getAccountStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // 병렬로 각 통계 가져오기
      final futures = await Future.wait([
        // 총 사진 수
        _firestore.collection('users').doc(user.uid).collection('photos').get(),
        // 카테고리 수
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('categories')
            .get(),
        // 연락처 수
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('contacts')
            .get(),
        // 공유된 사진 수
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('shared_photos')
            .get(),
      ]);

      return {
        'totalPhotos': futures[0].docs.length,
        'totalCategories': futures[1].docs.length,
        'totalContacts': futures[2].docs.length,
        'sharedPhotos': futures[3].docs.length,
        'storageUsed': await _calculateStorageUsage(),
        'accountCreated': await _getAccountCreationDate(),
      };
    } catch (e) {
      print('Get account stats error: $e');
      return null;
    }
  }

  // 스토리지 사용량 계산 (대략적)
  static Future<String> _calculateStorageUsage() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return '0 MB';

      final photos =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('photos')
              .get();

      // 대략적인 계산: 사진 1장당 평균 2MB로 가정
      final totalMB = photos.docs.length * 2;

      if (totalMB < 1024) {
        return '$totalMB MB';
      } else {
        final totalGB = (totalMB / 1024).toStringAsFixed(1);
        return '$totalGB GB';
      }
    } catch (e) {
      print('Calculate storage usage error: $e');
      return '0 MB';
    }
  }

  // 계정 생성일 가져오기
  static Future<DateTime?> _getAccountCreationDate() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final timestamp = data['createdAt'] as Timestamp?;
        return timestamp?.toDate();
      }

      return null;
    } catch (e) {
      print('Get account creation date error: $e');
      return null;
    }
  }

  // 데이터 내보내기 요청
  static Future<bool> requestDataExport() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('data_export_requests').add({
        'userId': user.uid,
        'userEmail': user.email,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'type': 'full_export',
      });

      return true;
    } catch (e) {
      print('Request data export error: $e');
      return false;
    }
  }

  // 계정 삭제 요청
  static Future<bool> requestAccountDeletion(String reason) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('account_deletion_requests').add({
        'userId': user.uid,
        'userEmail': user.email,
        'reason': reason,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      return true;
    } catch (e) {
      print('Request account deletion error: $e');
      return false;
    }
  }
}
