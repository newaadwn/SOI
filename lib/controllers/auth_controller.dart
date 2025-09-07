import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:soi/models/auth_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../repositories/friend_repository.dart';
import '../controllers/comment_record_controller.dart';

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
  final FriendRepository _friendRepository = FriendRepository();

  // 프로필 이미지 캐싱을 위한 변수들 추가
  static final Map<String, String> _profileImageCache = {};
  static const int _maxCacheSize = 100;
  final Map<String, bool> _loadingStates = {}; // 로딩 상태 관리

  // Getters
  String get verificationId => _verificationId;
  List<String> get searchResults => _searchResults;
  List<String> get searchProfileImage => _searchProfileImage;
  bool get isUploading => _isUploading;

  // 현재 사용자 정보 관련 getters
  User? get currentUser => _authService.currentUser;
  String? get getUserId => _authService.getUserId;

  // ✅ 자동 로그인 관련 상수
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyPhoneNumber = 'user_phone_number';

  // 검색 결과 초기화
  void clearSearchResults() {
    _searchResults.clear();
    notifyListeners();
  }

  /// 프로필 이미지 URL 가져오기 (캐싱 포함)
  Future<String> getUserProfileImageUrlById(String userId) async {
    return await _authService.getUserProfileImageUrlById(userId);
  }

  /// 사용자 정보 가져오기
  Future<AuthModel?> getUserInfo(String userId) async {
    return await _authService.getUserInfo(userId);
  }

  /// 프로필 이미지 URL 가져오기 (캐싱 + 로딩 상태 관리)
  Future<String> getUserProfileImageUrlWithCache(String userId) async {
    // 이미 로딩 중인 경우 중복 요청 방지
    if (_loadingStates[userId] == true) {
      // 로딩이 완료될 때까지 대기
      while (_loadingStates[userId] == true) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // 캐시 크기 관리
    if (_profileImageCache.length > _maxCacheSize) {
      _profileImageCache.clear();
      // debugPrint('프로필 이미지 캐시 크기 초과로 초기화');
    }

    // 캐시 확인
    if (_profileImageCache.containsKey(userId)) {
      // debugPrint('캐시에서 프로필 이미지 발견 - UserID: $userId');
      return _profileImageCache[userId]!;
    }

    // 네트워크에서 로드
    try {
      _loadingStates[userId] = true;

      final profileImageUrl = await _authService.getUserProfileImageUrlById(
        userId,
      );

      // 캐시에 저장
      _profileImageCache[userId] = profileImageUrl;
      _loadingStates[userId] = false;

      return profileImageUrl;
    } catch (e) {
      _loadingStates[userId] = false;

      // 빈 문자열 반환하여 에러 상태 표시
      _profileImageCache[userId] = '';
      return '';
    }
  }

  // 사용자 검색
  Future<void> searchNickName(String userNickName) async {
    if (userNickName.isEmpty) return;

    try {
      _searchResults = await _authService.searchUsersByNickname(userNickName);
      notifyListeners();
    } catch (e) {
      rethrow;
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
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (String verificationId, int? token) {
          _verificationId = verificationId;

          onCodeSent(verificationId, token);
        },
        onTimeout: codeAutoRetrievalTimeout,
      );
    } catch (e) {
      rethrow;
    }
  }

  // SMS 코드로 로그인
  Future<void> signInWithSmsCode(String smsCode, Function() onSuccess) async {
    await _authService.signInWithSmsCode(
      verificationId: _verificationId,
      smsCode: smsCode,
    );
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
      // ✅ 로그아웃 성공 시 저장된 로그인 상태 삭제
      await clearLoginState();
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
        // 프로필 이미지 업데이트 성공 시, 음성 댓글들의 프로필 이미지 URL도 업데이트
        await _updateVoiceCommentsProfileImage(result.data);

        // 모든 친구들의 friends 서브컬렉션에 새 프로필 이미지 URL 전파
        await _propagateProfileImageToFriends(result.data);

        return true;
      } else {
        return false;
      }
    } catch (e) {
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  /// 음성 댓글들의 프로필 이미지 URL 업데이트
  Future<void> _updateVoiceCommentsProfileImage(
    String newProfileImageUrl,
  ) async {
    try {
      final currentUserId = getUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        return;
      }

      // CommentRecordController를 사용하여 업데이트
      final commentRecordController = CommentRecordController();
      final success = await commentRecordController.updateUserProfileImageUrl(
        userId: currentUserId,
        newProfileImageUrl: newProfileImageUrl,
      );

      if (success) {
        // 프로필 이미지 캐시 클리어 (새 이미지로 갱신)
        _profileImageCache.remove(currentUserId);

        // UI 갱신을 위해 notifyListeners 호출
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 친구들의 friends 서브컬렉션에 새 프로필 이미지 URL 전파
  Future<void> _propagateProfileImageToFriends(
    String newProfileImageUrl,
  ) async {
    try {
      await _friendRepository.propagateCurrentUserProfileImage(
        newProfileImageUrl,
      );
    } catch (e) {
      rethrow;
    }
  }

  // 회원 탈퇴
  Future<void> deleteUser() async {
    final result = await _authService.deleteAccount();

    if (result.isSuccess) {
      // debugPrint("계정이 삭제되었습니다.");
    } else {
      // debugPrint(result.error ?? "계정 삭제 중 오류가 발생했습니다.");
    }
  }

  // 프로필 이미지 URL 정리 (현재는 Service에서 처리하지 않으므로 빈 메서드로 유지)
  Future<void> cleanInvalidProfileImageUrl() async {
    notifyListeners();
  }

  // ✅ ===== 자동 로그인 관련 메서드들 =====

  /// 로그인 상태를 SharedPreferences에 저장
  Future<void> saveLoginState({
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserId, userId);
      await prefs.setString(_keyPhoneNumber, phoneNumber);
      // debugPrint('🔐 로그인 상태 저장 완료: $userId');
    } catch (e) {
      // debugPrint('❌ 로그인 상태 저장 실패: $e');
    }
  }

  /// 저장된 로그인 상태 확인
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      // debugPrint('🔍 저장된 로그인 상태: $isLoggedIn');
      return isLoggedIn;
    } catch (e) {
      // debugPrint('❌ 로그인 상태 확인 실패: $e');
      return false;
    }
  }

  /// 저장된 사용자 정보 가져오기
  Future<Map<String, String?>> getSavedUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'userId': prefs.getString(_keyUserId),
        'phoneNumber': prefs.getString(_keyPhoneNumber),
      };
    } catch (e) {
      // debugPrint('❌ 저장된 사용자 정보 가져오기 실패: $e');
      return {'userId': null, 'phoneNumber': null};
    }
  }

  /// 저장된 사용자의 Firestore 정보 가져오기 (auth_final용)
  Future<Map<String, String>?> getSavedUserFirestoreInfo() async {
    try {
      final savedInfo = await getSavedUserInfo();
      final userId = savedInfo['userId'];

      if (userId == null) {
        // debugPrint('❌ 저장된 사용자 ID 없음');
        return null;
      }

      // Firestore에서 사용자 정보 가져오기
      final userInfo = await getUserInfo(userId);
      if (userInfo != null) {
        return {
          'id': userInfo.id,
          'name': userInfo.name,
          'phone': userInfo.phone,
          'birthDate': userInfo.birthDate,
        };
      }

      // debugPrint('❌ Firestore에서 사용자 정보를 찾을 수 없음');
      return null;
    } catch (e) {
      // debugPrint('❌ 사용자 Firestore 정보 가져오기 실패: $e');
      return null;
    }
  }

  /// 자동 로그인 시도
  Future<bool> tryAutoLogin() async {
    try {
      // debugPrint('🔄 자동 로그인 시도 중...');

      // 저장된 로그인 상태 확인
      final isUserLoggedIn = await isLoggedIn();
      if (!isUserLoggedIn) {
        // debugPrint('❌ 저장된 로그인 정보 없음');
        return false;
      }

      // Firebase Auth 현재 사용자 확인
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        // debugPrint('❌ Firebase Auth 사용자 없음 - 로그인 상태 초기화');
        await clearLoginState();
        return false;
      }

      // debugPrint('✅ 자동 로그인 성공: ${currentUser.uid}');
      return true;
    } catch (e) {
      // debugPrint('❌ 자동 로그인 실패: $e');
      await clearLoginState();
      return false;
    }
  }

  /// 로그인 상태 삭제 (로그아웃 시 호출)
  Future<void> clearLoginState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyPhoneNumber);
      // debugPrint('🗑️ 로그인 상태 삭제 완료');
    } catch (e) {
      // debugPrint('❌ 로그인 상태 삭제 실패: $e');
    }
  }

  /// 로그인 성공 시 상태 저장하는 개선된 로그인 메서드
  Future<void> signInWithSmsCodeAndSave(
    String smsCode,
    String phoneNumber,
    Function() onSuccess,
  ) async {
    final result = await _authService.signInWithSmsCode(
      verificationId: _verificationId,
      smsCode: smsCode,
    );

    if (result.isSuccess) {
      // ✅ 로그인 성공 시 상태 저장
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        await saveLoginState(userId: currentUser.uid, phoneNumber: phoneNumber);
        // debugPrint("✅ 로그인 성공 및 상태 저장 완료!");
        onSuccess();
      }
    } else {
      // debugPrint(result.error ?? "로그인에 실패했습니다.");
    }
  }
}
