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
      // iOS에서 reCAPTCHA 관련 문제 해결을 위한 설정
      await _auth.setSettings(
        appVerificationDisabledForTesting: false,
        forceRecaptchaFlow: false,
      );

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) {
          // 자동 인증 완료 시 처리 (Android SMS 자동 감지)
        },
        verificationFailed: (exception) {
          print('전화번호 인증 실패: ${exception.message}');

          // reCAPTCHA 관련 에러는 무시하고 계속 진행
          if (exception.code.contains('web-internal-error') ||
              exception.message?.contains('reCAPTCHA') == true) {
            print('reCAPTCHA 에러 무시하고 계속 진행');
            return;
          }

          throw exception;
        },
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: onTimeout,
        timeout: const Duration(seconds: 120),
      );
    } catch (e) {
      print('전화번호 인증 중 오류: $e');

      // reCAPTCHA 관련 에러는 사용자에게 영향을 주지 않으므로 무시
      if (e.toString().contains('reCAPTCHA') ||
          e.toString().contains('web-internal-error')) {
        print('reCAPTCHA 관련 에러이므로 무시');
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
    await _firestore.collection('users').doc(user.uid).set(user.toFirestore());
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
