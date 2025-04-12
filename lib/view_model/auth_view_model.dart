import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _searchResults = [];
  List<String> _searchProfileImage = [];

  String verificationId = '';
  String smsCode = '';
  bool codeSent = false;

  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 검색 결과 리스트 가져오기
  List<String> get searchResults => _searchResults;

  // 프로필 이미지 가지고 오기
  List<String> get searchProfileImage => _searchProfileImage;

  // 현재 로그인한 사용자 가져오기
  User? get getCurrentUserId => _auth.currentUser;

  // 현재 사용자 ID 가져오기
  String? get getUserId => _auth.currentUser?.uid;

  // 사용자 로그인 상태 스트림
  //Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 로그인 여부 확인
  //bool get isLoggedIn => _auth.currentUser != null;

  // mates에 맞는 사용자들의 프로필 이미지 리스트 가지고 오기
  Stream<List> getprofileImages(List mates) {
    if (mates.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .where('nick_name', whereIn: mates)
        .snapshots()
        .map(
          (querySnapshot) =>
              querySnapshot.docs
                  .map((doc) => doc['profile_image'] as String)
                  .toList(),
        );
  }

  void clearSearchResults() {
    searchResults.clear();
    notifyListeners();
  }

  // 회원가입 시 사용자 정보를 Firestore에 저장
  Future<void> createUserInFirestore(
    User user,
    String token,
    String nickName,
    String name,
    String phone,
    String birthDate,
  ) async {
    try {
      // users 컬렉션에 문서 생성
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid, // Firebase Auth의 고유 ID
        'createdAt': Timestamp.now(), // 생성 시간
        'lastLogin': Timestamp.now(), // 마지막 로그인 시간
        'nick_name': nickName,
        'name': name,
        'phone': phone,
        'birth_date': birthDate,
        'profile_image': '', // 프로필 이미지 URL
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error creating user document: $e');
      rethrow;
    }
  }

  // firestore에 nick_name 필드의 값 가지고 오는 함수
  Future<String> getNickNameFromFirestore() async {
    try {
      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .get();
      if (documentSnapshot.exists) {
        // 닉네임 필드 가져오기
        String? fetchedNickName = documentSnapshot.get('nick_name');
        print('Fetched Nickname: $fetchedNickName');
        return fetchedNickName ?? 'Default Nickname';
      } else {
        print('User document does not exist');
        return 'Default Nickname'; // 기본 닉네임 반환
      }
    } catch (e) {
      print('Error fetching user document: $e');
      rethrow;
    }
  }

  // 사용자 검색 메서드
  Future<void> searchNickName(String userNickName) async {
    if (userNickName.isEmpty) return;

    try {
      // users 컬렉션의 모든 문서 가져오기
      final QuerySnapshot result = await _firestore.collection('users').get();

      // uid가 일치하거나 3글자 이상 비슷한 문서 필터링
      _searchResults =
          result.docs
              .where((doc) {
                String nickName = doc['nick_name'] as String;

                // 정확히 일치하는 경우
                if (nickName == userNickName) return true;

                // 3글자 이상 비슷한지 확인
                int matchCount = 0;
                int minLength =
                    nickName.length < userNickName.length
                        ? nickName.length
                        : userNickName.length;

                for (int i = 0; i < minLength; i++) {
                  if (nickName[i] == userNickName[i]) matchCount++;
                }

                return matchCount >= 2;
              })
              .map((doc) => doc['nick_name'] as String)
              .toList();

      _searchProfileImage =
          result.docs
              .where((doc) {
                String nickName = doc['nick_name'] as String;

                // 정확히 일치하는 경우
                if (nickName == userNickName) return true;

                // 3글자 이상 비슷한지 확인
                int matchCount = 0;
                int minLength =
                    nickName.length < userNickName.length
                        ? nickName.length
                        : userNickName.length;

                for (int i = 0; i < minLength; i++) {
                  if (nickName[i] == userNickName[i]) matchCount++;
                }

                return matchCount >= 2;
              })
              .map((doc) => doc['profile_image'] as String)
              .toList();

      notifyListeners();
    } catch (e) {
      print('Error searching users: $e');
      rethrow;
    }
  }

  // 전화번호 인증 요청
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(String verificationId, int? resendToken) codeSent,
    Function(String verificationId) codeAutoRetrievalTimeout,
  ) async {
    try {
      // 전화번호 형식 확인 및 정규화
      String formattedPhone = phoneNumber;
      if (phoneNumber.startsWith('0')) {
        // 앞의 0을 제거
        formattedPhone = phoneNumber.substring(1);
      }
      
      final String fullPhoneNumber = "+82$formattedPhone";
      print('Formatted phone number: $fullPhoneNumber');
      
      await _auth.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            print('Auto verification completed successfully');
          } catch (e) {
            print('Error in auto verification: $e');
            Fluttertoast.showToast(msg: '자동 인증 중 오류가 발생했습니다: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.message}');
          Fluttertoast.showToast(msg: '인증 실패: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          print('SMS code sent. Verification ID: $verificationId');
          this.verificationId = verificationId;
          codeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto retrieval timeout. Verification ID: $verificationId');
          this.verificationId = verificationId;
          codeAutoRetrievalTimeout(verificationId);
        },
        timeout: const Duration(seconds: 60), // 시간 증가
      );
    } catch (e) {
      print('Error verifying phone number: $e');
      Fluttertoast.showToast(msg: '전화번호 인증 중 오류가 발생했습니다: $e');
    }
  }

  // SMS 코드로 로그인
  Future<void> signInWithSmsCode(String smsCode, Function onSuccess) async {
    if (verificationId.isEmpty) {
      Fluttertoast.showToast(msg: '인증 ID가 없습니다. 다시 시도해주세요.');
      return;
    }
    
    try {
      print('Signing in with SMS code. Verification ID: $verificationId');
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        print('Successfully signed in: ${userCredential.user?.uid}');
        onSuccess();
      } else {
        Fluttertoast.showToast(msg: '로그인에 실패했습니다.');
      }
    } catch (e) {
      print('Error signing in with SMS code: $e');
      Fluttertoast.showToast(msg: '인증 코드 확인 중 오류가 발생했습니다: $e');
    }
  }
}
