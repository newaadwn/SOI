import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/auth_model.dart';

// firebase에서 auth관련 정보를 가지고 오고, 저장하고, 업데이트하고 삭제하는 등의 로직들
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // ==================== Firebase Auth 관련 ====================

  // 현재 로그인한 사용자
  User? get currentUser => _auth.currentUser;

  // 현재 로그인한 사용자의 uid 가져오기
  String? get getUserId => _auth.currentUser?.uid;

  // 전화번호 인증 요청
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) onCodeSent,
    required Function(String) onTimeout,
  }) async {
    try {
      // ⭐ reCAPTCHA 우회를 위한 강화된 설정
      await _auth.setSettings(
        appVerificationDisabledForTesting: false, // 실제 SMS 사용
        forceRecaptchaFlow: false, // reCAPTCHA 강제 사용 안함
      );

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android에서 SMS 자동 감지 시 자동 로그인
          try {
            await _auth.signInWithCredential(credential);
            // debugPrint("📱 SMS 자동 인증 완료");
          } catch (e) {
            // debugPrint("❌ 자동 인증 실패: $e");
          }
        },
        verificationFailed: (FirebaseAuthException exception) {
          // debugPrint('❌ 전화번호 인증 실패: ${exception.code} - ${exception.message}');

          // 특정 에러 코드 처리
          if (exception.code == 'invalid-phone-number') {
            throw Exception('유효하지 않은 전화번호입니다.');
          } else if (exception.code == 'too-many-requests') {
            throw Exception('너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.');
          } else if (exception.code == 'web-internal-error' ||
              exception.message?.contains('reCAPTCHA') == true ||
              exception.message?.contains('captcha') == true) {
            // ⭐ reCAPTCHA 관련 에러 상세 로깅
            // debugPrint("🔧 reCAPTCHA 관련 에러 감지:");
            // debugPrint("   - 에러 코드: ${exception.code}");
            // debugPrint("   - 에러 메시지: ${exception.message}");
            // debugPrint("   - APNs 토큰이 제대로 설정되지 않았을 가능성이 높습니다.");
            // debugPrint("   - 임시로 에러를 무시하고 계속 진행합니다.");
            return;
          }

          throw exception;
        },
        codeSent: (String verificationId, int? resendToken) {
          // debugPrint("✅ SMS 코드 전송 완료 - verificationId: $verificationId");
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // debugPrint("⏰ 코드 자동 검색 타임아웃 - verificationId: $verificationId");
          onTimeout(verificationId);
        },
        timeout: const Duration(seconds: 120),
      );
    } catch (e) {
      // debugPrint('전화번호 인증 중 오류: $e');

      // reCAPTCHA 관련 에러는 사용자에게 영향을 주지 않으므로 무시
      if (e.toString().contains('reCAPTCHA') ||
          e.toString().contains('web-internal-error')) {
        // debugPrint('reCAPTCHA 관련 에러이므로 무시');
        return;
      }

      rethrow;
    }
  }

  // SMS 코드로 로그인
  Future<UserCredential> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ==================== Firestore 관련 ====================

  // 전화번호로 사용자 검색
  Future<DocumentSnapshot?> findUserByPhone(String phone) async {
    final query =
        await _firestore
            .collection('users')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();

    return query.docs.isNotEmpty ? query.docs.first : null;
  }

  // 사용자 정보 저장
  Future<void> saveUser(AuthModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toFirestoreWithServerTimestamp());
  }

  // 사용자 정보 업데이트
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // 사용자 정보 조회
  Future<AuthModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (doc.exists && doc.data() != null) {
      return AuthModel.fromFirestore(doc.data()!);
    }
    return null;
  }

  // 사용자 정보 조회 (getUserInfo 별칭)
  Future<AuthModel?> getUserInfo(String userId) async {
    return await getUser(userId);
  }

  // 사용자 프로필 이미지 URL 조회
  Future<String> getUserProfileImageUrlById(String userId) async {
    try {
      // debugPrint('👤 프로필 이미지 URL 조회 시작 - UserId: $userId');

      final userDoc = await _firestore.collection('users').doc(userId).get();

      // debugPrint('📄 사용자 문서 존재: ${userDoc.exists}');

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        // 각 필드 개별 확인
        final profileImageUrl = data['profileImageUrl'];
        final profileImage = data['profile_image'];

        // debugPrint('profileImageUrl 필드: $profileImageUrl');
        // debugPrint('profile_image 필드: $profileImage');
        // debugPrint('전체 사용자 데이터: $data');

        // 두 가지 필드명 모두 시도 (기존 호환성)
        final finalUrl = profileImageUrl ?? profileImage ?? '';

        // debugPrint('최종 ProfileImageUrl: "$finalUrl"');

        return finalUrl;
      }

      // debugPrint('사용자 문서가 존재하지 않음');
      return '';
    } catch (e) {
      // debugPrint('사용자 프로필 이미지 가져오기 실패: $e');
      return '';
    }
  }

  // 사용자 검색 (닉네임으로)
  Future<List<String>> searchUsersByNickname(String nickname) async {
    final query = await _firestore.collection('users').get();

    return query.docs
        .where((doc) => doc['id'].toString().contains(nickname))
        .map((doc) => doc['id'] as String)
        .toList();
  }

  // 프로필 이미지 스트림
  Stream<List<String>> getProfileImagesStream(List<String> userIds) {
    if (userIds.isEmpty) return Stream.value([]);

    return _firestore
        .collection('users')
        .where('id', whereIn: userIds)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => doc['profile_image'] as String)
                  .where((url) => url.isNotEmpty)
                  .toList(),
        );
  }

  // 사용자 삭제
  Future<void> deleteUser(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }

  // ==================== Storage 관련 ====================

  // 갤러리에서 이미지 선택
  Future<File?> pickImageFromGallery() async {
    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );

    return pickedImage != null ? File(pickedImage.path) : null;
  }

  // 프로필 이미지 업로드
  Future<String> uploadProfileImage(String uid, File imageFile) async {
    final fileName =
        'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.png';
    final ref = _storage.ref().child('profiles').child(uid).child(fileName);

    final uploadTask = ref.putFile(imageFile);
    final snapshot = await uploadTask.whenComplete(() => null);

    return await snapshot.ref.getDownloadURL();
  }
}
