import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/auth_repository.dart';
import '../models/auth_model.dart';
import '../models/auth_result.dart';

// 비즈니스 로직을 처리하는 Service
// Repository를 사용해서 실제 비즈니스 규칙을 적용
class AuthService {
  final AuthRepository _repository = AuthRepository();

  // ==================== 현재 사용자 정보 ====================

  User? get currentUser => _repository.currentUser;
  String? get getUserId => _repository.getUserId;

  // ==================== 비즈니스 로직 ====================

  Future<String> getUserProfileImageUrlById(String userId) async {
    try {
      debugPrint('👤 프로필 이미지 URL 조회 시작 - UserId: $userId');
      return await _repository.getUserProfileImageUrlById(userId);
    } catch (e) {
      debugPrint('사용자 프로필 이미지 가져오기 실패: $e');
      return '';
    }
  }

  Future<AuthModel?> getUserInfo(String userId) async {
    try {
      debugPrint('👤 사용자 정보 조회 시작 - UserId: $userId');
      return await _repository.getUserInfo(userId);
    } catch (e) {
      debugPrint('사용자 정보 가져오기 실패: $e');
      return null;
    }
  }

  // 전화번호 형식 정규화
  String _formatPhoneNumber(String phone) {
    String formatted = phone;
    if (phone.startsWith('0')) {
      formatted = phone.substring(1);
    }
    return "+82$formatted";
  }

  // 전화번호 인증 요청
  Future<AuthResult> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) onCodeSent,
    required Function(String) onTimeout,
  }) async {
    try {
      final formattedPhone = _formatPhoneNumber(phoneNumber);

      await _repository.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        onCodeSent: onCodeSent,
        onTimeout: onTimeout,
      );

      return AuthResult.success();
    } catch (e) {
      debugPrint('전화번호 인증 오류: $e');

      // reCAPTCHA 관련 에러는 사용자에게 친숙한 메시지로 변경
      if (e.toString().contains('web-internal-error') ||
          e.toString().contains('reCAPTCHA')) {
        debugPrint('reCAPTCHA 관련 에러 발생, 사용자에게는 일반적인 메시지 표시');
        return AuthResult.success(); // 실제로는 성공으로 처리 (백그라운드 에러이므로)
      }

      // 네트워크 관련 에러
      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        return AuthResult.failure('네트워크 연결을 확인하고 다시 시도해주세요.');
      }

      // 잘못된 전화번호 형식
      if (e.toString().contains('invalid-phone-number')) {
        return AuthResult.failure('유효하지 않은 전화번호입니다. 형식을 확인해주세요.');
      }

      return AuthResult.failure('전화번호 인증 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  // SMS 코드로 로그인
  Future<AuthResult> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      if (verificationId.isEmpty) {
        return AuthResult.failure('인증 ID가 없습니다.');
      }

      final userCredential = await _repository.signInWithSmsCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      if (userCredential.user != null) {
        return AuthResult.success(userCredential.user);
      } else {
        return AuthResult.failure('로그인에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('SMS 로그인 오류: $e');
      return AuthResult.failure('인증 코드 확인 중 오류가 발생했습니다: $e');
    }
  }

  // 회원가입/사용자 정보 저장
  Future<AuthResult> createUser({
    required String uid,
    required String id,
    required String name,
    required String phone,
    required String birthDate,
  }) async {
    try {
      // 전화번호 정규화
      final formattedPhone = phone.startsWith('0') ? phone.substring(1) : phone;

      // 기존 사용자 확인
      final existingUser = await _repository.findUserByPhone(formattedPhone);

      final now = DateTime.now();
      final user = AuthModel(
        uid: uid,
        id: id,
        name: name,
        phone: formattedPhone,
        birthDate: birthDate,
        createdAt:
            existingUser == null
                ? now
                : (existingUser.data() as Map<String, dynamic>)['createdAt']
                        ?.toDate() ??
                    now,
        lastLogin: now,
      );

      if (existingUser != null) {
        // 기존 사용자 업데이트
        await _repository.updateUser(existingUser.id, {
          'uid': uid,
          'lastLogin': FieldValue.serverTimestamp(),
          'id': id,
          'name': name,
          'birth_date': birthDate,
        });

        // 다른 문서 ID인 경우 새 문서도 생성
        if (existingUser.id != uid) {
          await _repository.saveUser(user);
        }
      } else {
        // 새 사용자 생성
        await _repository.saveUser(user);
      }

      return AuthResult.success(user);
    } catch (e) {
      debugPrint('사용자 생성 오류: $e');
      return AuthResult.failure('사용자 정보 저장 중 오류가 발생했습니다: $e');
    }
  }

  // 로그아웃
  Future<AuthResult> signOut() async {
    try {
      await _repository.signOut();
      return AuthResult.success();
    } catch (e) {
      debugPrint('로그아웃 오류: $e');
      return AuthResult.failure('로그아웃 중 오류가 발생했습니다.');
    }
  }

  // 현재 사용자 정보 조회
  Future<AuthModel?> getCurrentUser() async {
    final currentUser = _repository.currentUser;
    if (currentUser == null) return null;

    return await _repository.getUser(currentUser.uid);
  }

  // 사용자 ID 조회
  Future<String> getUserID() async {
    final user = await getCurrentUser();
    return user?.id ?? '';
  }

  // 사용자 이름 조회
  Future<String> getUserName() async {
    final user = await getCurrentUser();
    return user?.name ?? '';
  }

  // 사용자 전화번호 조회
  Future<String> getUserPhoneNumber() async {
    final user = await getCurrentUser();
    return user?.phone ?? '';
  }

  // 프로필 이미지 URL 조회
  Future<String> getUserProfileImageUrl() async {
    final user = await getCurrentUser();
    return user?.profileImage ?? '';
  }

  // Firestore에서 ID 조회 (레거시 메서드)
  Future<String> getIdFromFirestore() async {
    return await getUserID();
  }

  // 사용자 생성 (레거시 호환)
  Future<void> createUserInFirestore(
    User user,
    String id,
    String name,
    String phone,
    String birthDate,
  ) async {
    await createUser(
      uid: user.uid,
      id: id,
      name: name,
      phone: phone,
      birthDate: birthDate,
    );
  }

  // 사용자 검색
  Future<List<String>> searchUsers(String nickname) async {
    if (nickname.isEmpty) return [];

    try {
      return await _repository.searchUsersByNickname(nickname);
    } catch (e) {
      debugPrint('사용자 검색 오류: $e');
      return [];
    }
  }

  // 프로필 이미지 업데이트
  Future<AuthResult> updateProfileImage() async {
    try {
      final currentUser = _repository.currentUser;
      if (currentUser == null) {
        return AuthResult.failure('로그인이 필요합니다.');
      }

      // 이미지 선택
      final imageFile = await _repository.pickImageFromGallery();
      if (imageFile == null) {
        return AuthResult.failure('이미지 선택이 취소되었습니다.');
      }

      // 이미지 업로드
      final downloadUrl = await _repository.uploadProfileImage(
        currentUser.uid,
        imageFile,
      );

      // Firestore 업데이트
      await _repository.updateUser(currentUser.uid, {
        'profile_image': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AuthResult.success(downloadUrl);
    } catch (e) {
      debugPrint('프로필 이미지 업데이트 오류: $e');
      return AuthResult.failure('프로필 이미지 업데이트 중 오류가 발생했습니다.');
    }
  }

  // 회원 탈퇴
  Future<AuthResult> deleteAccount() async {
    try {
      final currentUser = _repository.currentUser;
      if (currentUser == null) {
        return AuthResult.failure('로그인이 필요합니다.');
      }

      // Firestore에서 사용자 데이터 삭제
      await _repository.deleteUser(currentUser.uid);

      // Firebase Auth에서 계정 삭제
      await currentUser.delete();

      return AuthResult.success();
    } catch (e) {
      debugPrint('계정 삭제 오류: $e');
      return AuthResult.failure('계정 삭제 중 오류가 발생했습니다.');
    }
  }

  // 사용자 검색
  Future<List<String>> searchUsersByNickname(String nickname) async {
    return await _repository.searchUsersByNickname(nickname);
  }
}
