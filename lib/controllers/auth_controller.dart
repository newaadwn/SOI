import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/auth_model.dart';

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

  // AuthModel 인스턴스 - 모든 비즈니스 로직은 여기서 처리됩니다
  final AuthModel _authModel = AuthModel();

  // Getters
  String get verificationId => _verificationId;
  List<String> get searchResults => _searchResults;
  List<String> get searchProfileImage => _searchProfileImage;
  bool get isUploading => _isUploading;

  // 현재 사용자 정보 관련 getters
  User? get currentUser => _authModel.currentUser;
  String? get getUserId => _authModel.getUserId;

  // 프로필 이미지 스트림
  Stream<List> getprofileImages(List mates) =>
      _authModel.getprofileImages(mates);

  // 검색 결과 초기화
  void clearSearchResults() {
    _searchResults.clear();
    notifyListeners();
  }

  // 사용자 검색
  Future<void> searchNickName(String userNickName) async {
    if (userNickName.isEmpty) return;

    try {
      _searchResults = await _authModel.searchNickName(userNickName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  // 아이디 조회
  Future<String> getIdFromFirestore() async {
    return await _authModel.getIdFromFirestore();
  }

  // 전화번호 인증
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(String, int?) onCodeSent,
    Function(String) codeAutoRetrievalTimeout,
  ) async {
    try {
      debugPrint('전화번호 인증 시작: $phoneNumber');

      // reCAPTCHA 초기화 (restart 후 캐시 문제 해결)
      await _authModel.resetRecaptcha();

      await _authModel.verifyPhoneNumber(phoneNumber, (
        String verificationId,
        int? token,
      ) {
        _verificationId = verificationId;
        debugPrint('인증 ID 설정 완료: $verificationId');
        onCodeSent(verificationId, token);
      }, codeAutoRetrievalTimeout);
    } catch (e) {
      debugPrint('전화번호 인증 중 오류: $e');

      // 구체적인 오류 메시지 제공
      String errorMessage = '전화번호 인증을 시작할 수 없습니다.';
      if (e.toString().contains('web-internal-error')) {
        errorMessage = '네트워크 연결을 확인하고 다시 시도해주세요.';
      } else if (e.toString().contains('reCAPTCHA')) {
        errorMessage = '보안 인증에 실패했습니다. 잠시 후 다시 시도해주세요.';
      } else if (e.toString().contains('invalid-phone-number')) {
        errorMessage = '유효하지 않은 전화번호입니다. 형식을 확인해주세요.';
      }

      Fluttertoast.showToast(msg: errorMessage);
    }
  }

  // SMS 코드로 로그인
  Future<void> signInWithSmsCode(String smsCode, Function() onSuccess) async {
    bool result = await _authModel.signInWithSmsCode(_verificationId, smsCode);
    if (result) {
      onSuccess();
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
    await _authModel.createUserInFirestore(user, id, name, phone, birthDate);
  }

  // 사용자 정보 조회
  Future<String> getUserID() async {
    return await _authModel.getUserID();
  }

  Future<String> getUserName() async {
    return await _authModel.getUserName();
  }

  Future<String> getUserPhoneNumber() async {
    return await _authModel.getUserPhoneNumber();
  }

  // 로그아웃
  Future<void> signOut() async {
    await _authModel.signOut();
  }

  // 프로필 이미지 URL 가져오기
  Future<String> getUserProfileImageUrl() async {
    return await _authModel.getUserProfileImageUrl();
  }

  // 갤러리에서 이미지 선택 및 업로드
  Future<bool> updateProfileImage() async {
    try {
      // 상태 업데이트 
      _isUploading = true;
      notifyListeners();

      // 1. 갤러리에서 이미지 선택
      final File? selectedImage = await _authModel.pickImageFromGallery();
      if (selectedImage == null) {
        _isUploading = false;
        notifyListeners();
        return false; // 사용자가 이미지 선택을 취소함
      }

      // 2. 이미지 업로드
      final result = await _authModel.uploadProfileImage(selectedImage);

      _isUploading = false;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('프로필 이미지 업데이트 중 오류 발생: $e');
      Fluttertoast.showToast(msg: '프로필 이미지를 업데이트하는 중 오류가 발생했습니다');
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  // 회원 탈퇴
  Future<void> deleteUser() async {
    await _authModel.deleteUser();
  }

  // 유효하지 않은 프로필 이미지 URL 초기화
  Future<void> cleanInvalidProfileImageUrl() async {
    await _authModel.cleanInvalidProfileImageUrl();
    notifyListeners();
  }
}
