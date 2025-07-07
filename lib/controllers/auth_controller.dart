import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// AuthController는 인증 관련 UI와 비즈니스 로직 사이의 중개 역할을 합니다.
class AuthController extends ChangeNotifier {
  // 상태 변수들
  String _verificationId = '';
  String smsCode = '';
  bool codeSent = false;
  bool _isUploading = false;
  List<String> _searchResults = [];
  final List<String> _searchProfileImage = [];

  // 네비게이션 키
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final AuthService _authService = AuthService();

  // Getters
  String get verificationId => _verificationId;
  List<String> get searchResults => _searchResults;
  List<String> get searchProfileImage => _searchProfileImage;
  bool get isUploading => _isUploading;

  // 현재 사용자 정보 관련 getters
  User? get currentUser => _authService.currentUser;
  String? get getUserId => _authService.getUserId;

  // 검색 결과 초기화
  void clearSearchResults() {
    _searchResults.clear();
    notifyListeners();
  }

  // 사용자 검색
  Future<void> searchNickName(String userNickName) async {
    if (userNickName.isEmpty) return;

    try {
      _searchResults = await _authService.searchUsersByNickname(userNickName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  // 아이디 조회
  Future<String> getIdFromFirestore() async {
    return _authService.getUserId!;
  }

  // 전화번호 인증
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(String, int?) onCodeSent,
    Function(String) codeAutoRetrievalTimeout,
  ) async {
    try {
      debugPrint('전화번호 인증 시작: $phoneNumber');

      final result = await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (String verificationId, int? token) {
          _verificationId = verificationId;
          debugPrint('인증 ID 설정 완료: $verificationId');
          onCodeSent(verificationId, token);
        },
        onTimeout: codeAutoRetrievalTimeout,
      );

      // ✅ 결과에 따른 UI 처리
      if (!result.isSuccess) {
        debugPrint(result.error ?? "전화번호 인증에 실패했습니다.");
      }
    } catch (e) {
      debugPrint('전화번호 인증 오류: $e');
      // ✅ 에러 시 UI 처리
      debugPrint("전화번호 인증 중 오류가 발생했습니다.");
    }
  }

  // SMS 코드로 로그인
  Future<void> signInWithSmsCode(String smsCode, Function() onSuccess) async {
    final result = await _authService.signInWithSmsCode(
      verificationId: _verificationId,
      smsCode: smsCode,
    );

    if (result.isSuccess) {
      // ✅ 성공 시 UI 처리
      debugPrint("로그인 성공!");
      onSuccess();
    } else {
      // ✅ 실패 시 UI 처리 (에러 메시지 표시)
      debugPrint(result.error ?? "로그인에 실패했습니다.");
    }
  }

  // 사용자 정보 저장
  Future<void> createUserInFirestore(
    User user,
    String id,
    String name,
    String phone,
    String birthDate,
  ) async {
    await _authService.createUserInFirestore(user, id, name, phone, birthDate);
  }

  // 사용자 정보 조회
  Future<String> getUserID() async {
    return await _authService.getUserID();
  }

  Future<String> getUserName() async {
    return await _authService.getUserName();
  }

  Future<String> getUserPhoneNumber() async {
    return await _authService.getUserPhoneNumber();
  }

  // 로그아웃
  Future<void> signOut() async {
    final result = await _authService.signOut();

    if (result.isSuccess) {
      debugPrint("로그아웃되었습니다.");
    } else {
      debugPrint(result.error ?? "로그아웃 중 오류가 발생했습니다.");
    }
  }

  // 프로필 이미지 URL 가져오기
  Future<String> getUserProfileImageUrl() async {
    return await _authService.getUserProfileImageUrl();
  }

  // 갤러리에서 이미지 선택 및 업로드
  Future<bool> updateProfileImage() async {
    try {
      // 상태 업데이트
      _isUploading = true;
      notifyListeners();

      // Service를 통해 프로필 이미지 업데이트
      final result = await _authService.updateProfileImage();

      _isUploading = false;
      notifyListeners();

      if (result.isSuccess) {
        debugPrint('프로필 이미지가 업데이트되었습니다');
        return true;
      } else {
        debugPrint(result.error ?? '프로필 이미지 업데이트에 실패했습니다');
        return false;
      }
    } catch (e) {
      debugPrint('프로필 이미지 업데이트 중 오류 발생: $e');
      debugPrint('프로필 이미지를 업데이트하는 중 오류가 발생했습니다');
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  // 회원 탈퇴
  Future<void> deleteUser() async {
    final result = await _authService.deleteAccount();

    if (result.isSuccess) {
      debugPrint("계정이 삭제되었습니다.");
    } else {
      debugPrint(result.error ?? "계정 삭제 중 오류가 발생했습니다.");
    }
  }

  // 프로필 이미지 URL 정리 (현재는 Service에서 처리하지 않으므로 빈 메서드로 유지)
  Future<void> cleanInvalidProfileImageUrl() async {
    notifyListeners();
  }
}
