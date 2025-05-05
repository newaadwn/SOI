import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _searchResults = [];
  List<String> _searchProfileImage = [];

  String _verificationId = '';
  String smsCode = '';
  bool codeSent = false;

  // Getter for verificationId
  String get verificationId => _verificationId;

  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // 개발 환경인지 확인하는 플래그
  final bool isTestMode = true;

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
        .where('id', whereIn: mates)
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

  // 전화번호로 기존 사용자를 찾는 메서드
  Future<DocumentSnapshot?> findUserByPhone(String phone) async {
    try {
      // 전화번호 형식 정규화
      String formattedPhone = phone;
      if (phone.startsWith('0')) {
        formattedPhone = phone.substring(1);
      }

      // users 컬렉션에서 phone 필드가 일치하는 문서 검색
      QuerySnapshot querySnapshot =
          await _firestore
              .collection('users')
              .where('phone', isEqualTo: formattedPhone)
              .limit(1)
              .get();

      // 검색 결과가 있으면 첫 번째 문서 반환, 없으면 null 반환
      return querySnapshot.docs.isNotEmpty ? querySnapshot.docs.first : null;
    } catch (e) {
      debugPrint('전화번호로 사용자 검색 중 오류 발생: $e');
      return null;
    }
  }

  // 회원가입 시 사용자 정보를 Firestore에 저장 (전화번호 중복 검사 추가)
  Future<void> createUserInFirestore(
    User user,
    String id,
    String name,
    String phone,
    String birthDate,
  ) async {
    try {
      // 전화번호 형식 정규화
      String formattedPhone = phone;
      if (phone.startsWith('0')) {
        formattedPhone = phone.substring(1);
      }

      // 전화번호로 기존 사용자 검색
      DocumentSnapshot? existingUser = await findUserByPhone(formattedPhone);

      if (existingUser != null) {
        // 기존 사용자가 있는 경우, 해당 문서 업데이트
        String existingUserId = existingUser.id;
        debugPrint('기존 사용자 발견 (ID: $existingUserId), 정보 업데이트');

        await _firestore.collection('users').doc(existingUserId).update({
          'uid': user.uid, // 새 Firebase Auth의 고유 ID로 업데이트
          'lastLogin': Timestamp.now(), // 마지막 로그인 시간 업데이트
          'id': id,
          'name': name,
          'birth_date': birthDate,
          // profile_image는 유지
        });

        // 필요한 경우 사용자 정보를 새 문서로도 복제 (기존 문서 ID와 새 Auth UID가 다른 경우)
        if (existingUserId != user.uid) {
          Map<String, dynamic> userData =
              existingUser.data() as Map<String, dynamic>;
          userData['uid'] = user.uid;
          userData['lastLogin'] = Timestamp.now();
          userData['id'] = id;
          userData['name'] = name;
          userData['birth_date'] = birthDate;

          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(userData, SetOptions(merge: true));
        }
      } else {
        // 새 사용자인 경우, 새 문서 생성
        debugPrint('새 사용자 생성 (ID: ${user.uid})');
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid, // Firebase Auth의 고유 ID
          'createdAt': Timestamp.now(), // 생성 시간
          'lastLogin': Timestamp.now(), // 마지막 로그인 시간
          'id': id,
          'name': name,
          'phone': formattedPhone, // 정규화된 전화번호 저장
          'birth_date': birthDate,
          'profile_image': '', // 프로필 이미지 URL
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('사용자 문서 생성/업데이트 중 오류 발생: $e');
      rethrow;
    }
  }

  // firestore에 id 필드의 값 가지고 오는 함수
  Future<String> getIdFromFirestore() async {
    try {
      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .get();
      if (documentSnapshot.exists) {
        // 닉네임 필드 가져오기
        String? fetchedId = documentSnapshot.get('id');
        debugPrint('Fetched Id: $fetchedId');
        return fetchedId ?? 'Default Nickname';
      } else {
        debugPrint('User document does not exist');
        return 'Default Nickname'; // 기본 닉네임 반환
      }
    } catch (e) {
      debugPrint('Error fetching user document: $e');
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
                String id = doc['id'] as String;

                // 정확히 일치하는 경우
                if (id == userNickName) return true;

                // 3글자 이상 비슷한지 확인
                int matchCount = 0;
                int minLength =
                    id.length < userNickName.length
                        ? id.length
                        : userNickName.length;

                for (int i = 0; i < minLength; i++) {
                  if (id[i] == userNickName[i]) matchCount++;
                }

                return matchCount >= 2;
              })
              .map((doc) => doc['id'] as String)
              .toList();

      _searchProfileImage =
          result.docs
              .where((doc) {
                String id = doc['id'] as String;

                // 정확히 일치하는 경우
                if (id == userNickName) return true;

                // 3글자 이상 비슷한지 확인
                int matchCount = 0;
                int minLength =
                    id.length < userNickName.length
                        ? id.length
                        : userNickName.length;

                for (int i = 0; i < minLength; i++) {
                  if (id[i] == userNickName[i]) matchCount++;
                }

                return matchCount >= 2;
              })
              .map((doc) => doc['profile_image'] as String)
              .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error searching users: $e');
      rethrow;
    }
  }

  // 메서드 이름 및 파라미터 복원
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(String verificationId, int? resendToken) onCodeSent,
    Function(String verificationId) codeAutoRetrievalTimeout,
  ) async {
    try {
      // 전화번호 형식 확인 및 정규화
      String formattedPhone = phoneNumber;
      if (phoneNumber.startsWith('0')) {
        formattedPhone = phoneNumber.substring(1);
      }
      final String fullPhoneNumber = "+82$formattedPhone";
      debugPrint('Formatted phone number: $fullPhoneNumber');

      // *** 주석 제거 또는 수정 ***
      // 클라이언트 측에서 verifyPhoneNumber를 호출

      await _auth.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _auth.signInWithCredential(credential);
            debugPrint('Auto verification completed successfully');
            // 자동 성공 시 처리 (예: 다음 화면 이동)
          } catch (e) {
            debugPrint('Error in auto verification: $e');
            Fluttertoast.showToast(msg: '자동 인증 중 오류가 발생했습니다: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Verification failed: ${e.code} - ${e.message}');
          Fluttertoast.showToast(msg: '인증 실패: ${e.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('SMS code sent. Verification ID: $verificationId');
          _verificationId = verificationId;
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint(
            'Auto retrieval timeout. Verification ID: $verificationId',
          );
          _verificationId = verificationId;
          codeAutoRetrievalTimeout(verificationId);
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint('Error verifying phone number: $e');
      Fluttertoast.showToast(msg: '전화번호 인증 중 오류가 발생했습니다: $e');
    }
  }

  // SMS 코드로 로그인 (기존 코드 유지)
  Future<void> signInWithSmsCode(String smsCode, Function() onSuccess) async {
    if (_verificationId.isEmpty) {
      Fluttertoast.showToast(msg: '인증 ID가 없습니다. 다시 시도해주세요.');
      return;
    }

    try {
      debugPrint('Signing in with SMS code. Verification ID: $_verificationId');
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      if (userCredential.user != null) {
        debugPrint('Successfully signed in: ${userCredential.user?.uid}');
        onSuccess(); // 인자 없이 호출
      } else {
        Fluttertoast.showToast(msg: '로그인에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('Error signing in with SMS code: $e');
      Fluttertoast.showToast(msg: '인증 코드 확인 중 오류가 발생했습니다: $e');
    }
  }

  // Firebase User 객체에 대한 getter 추가
  User? get currentUser => _auth.currentUser;

  // 사용자 아이디 가져오기
  Future<String> getUserID() async {
    try {
      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .get();

      if (documentSnapshot.exists) {
        // 아이디 필드 가져오기 (문서에 있는 실제 아이디 필드명에 맞게 수정 필요)
        return documentSnapshot.data()!.toString().contains('id')
            ? documentSnapshot.get('id').toString()
            : 'user id'; // 기본값
      } else {
        debugPrint('User document does not exist');
        return 'user id'; // 기본값
      }
    } catch (e) {
      debugPrint('Error fetching user id: $e');
      return 'user id'; // 오류 시 기본값
    }
  }

  Future<String> getUserName() async {
    try {
      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .get();

      if (documentSnapshot.exists) {
        // 아이디 필드 가져오기 (문서에 있는 실제 아이디 필드명에 맞게 수정 필요)
        return documentSnapshot.data()!.toString().contains('name')
            ? documentSnapshot.get('name').toString()
            : 'user name'; // 기본값
      } else {
        debugPrint('User document does not exist');
        return 'user name'; // 기본값
      }
    } catch (e) {
      debugPrint('Error fetching user id: $e');
      return 'user name'; // 오류 시 기본값
    }
  }

  Future<String> getUserPhoneNumber() async {
    try {
      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .get();

      if (documentSnapshot.exists) {
        // 아이디 필드 가져오기 (문서에 있는 실제 아이디 필드명에 맞게 수정 필요)
        return documentSnapshot.data()!.toString().contains('phone')
            ? documentSnapshot.get('phone').toString()
            : 'phone number'; // 기본값
      } else {
        debugPrint('User document does not exist');
        return 'phone number'; // 기본값
      }
    } catch (e) {
      debugPrint('Error fetching user id: $e');
      return 'phone number'; // 오류 시 기본값
    }
  }

  // 로그아웃 기능
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Error signing out: $e');
      Fluttertoast.showToast(msg: '로그아웃 중 오류가 발생했습니다.');
      rethrow;
    }
  }

  // 이미지 피커 인스턴스
  final ImagePicker _imagePicker = ImagePicker();

  // 이미지 업로드 중 상태
  bool _isUploading = false;
  bool get isUploading => _isUploading;

  // 프로필 이미지 URL 가져오기
  Future<String> getUserProfileImageUrl() async {
    try {
      // 현재 사용자의 UID 확인
      String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('사용자가 로그인되어 있지 않습니다');
        return '';
      }

      // users 컬렉션에서 문서 가져오기
      DocumentSnapshot documentSnapshot =
          await _firestore.collection('users').doc(uid).get();

      if (documentSnapshot.exists) {
        // profile_image 필드 가져오기
        return documentSnapshot.data()!.toString().contains('profile_image')
            ? documentSnapshot.get('profile_image').toString()
            : '';
      } else {
        debugPrint('사용자 문서가 존재하지 않습니다');
        return '';
      }
    } catch (e) {
      debugPrint('프로필 이미지 URL 가져오기 오류: $e');
      return '';
    }
  }

  // 갤러리에서 이미지 선택
  Future<File?> pickImageFromGallery() async {
    try {
      // 이미지 선택
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 이미지 품질 (0-100)
      );

      if (pickedImage == null) {
        debugPrint('이미지 선택이 취소되었습니다');
        return null;
      }

      // XFile을 File로 변환
      return File(pickedImage.path);
    } catch (e) {
      debugPrint('이미지 선택 중 오류 발생: $e');
      Fluttertoast.showToast(msg: '이미지를 선택하는 중 오류가 발생했습니다');
      return null;
    }
  }

  // 이미지 압축 함수
  Future<Object?> compressImage(File imageFile) async {
    try {
      // 원본 파일 경로 및 이름 가져오기
      final String fileName = path.basename(imageFile.path);
      final Directory tempDir = await getTemporaryDirectory();
      final String targetPath = '${tempDir.path}/$fileName';

      // 이미지 압축 실행
      final XFile? compressedFile =
          await FlutterImageCompress.compressAndGetFile(
            imageFile.absolute.path,
            targetPath,
            quality: 70, // 압축 품질 (0-100)
            minWidth: 1024, // 최소 너비
            minHeight: 1024, // 최소 높이
          );

      return compressedFile;
    } catch (e) {
      debugPrint('이미지 압축 중 오류 발생: $e');
      return imageFile; // 압축 실패 시 원본 반환
    }
  }

  // 프로필 이미지 업로드 및 Firestore 업데이트
  Future<bool> uploadProfileImage(File imageFile) async {
    try {
      // 업로드 상태 설정
      _isUploading = true;
      notifyListeners();

      // 현재 사용자의 UID 확인
      String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        debugPrint('사용자가 로그인되어 있지 않습니다');
        return false;
      }

      // 1. 이미지 압축
      final Object? compressedFile = await compressImage(imageFile);
      if (compressedFile == null) {
        debugPrint('이미지 압축 실패');
        return false;
      }

      // 2. 파일 이름 생성 (고유한 파일명 보장)
      final String fileName =
          'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 3. Firebase Storage에 업로드
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profiles')
          .child(uid)
          .child(fileName);

      // 업로드 작업 생성 및 진행
      UploadTask uploadTask;
      if (compressedFile is File) {
        // If compression returned a File object
        uploadTask = storageRef.putFile(compressedFile);
      } else if (compressedFile is XFile) {
        // If compression returned an XFile object
        uploadTask = storageRef.putFile(File((compressedFile as XFile).path));
      } else {
        // Fallback to original file if compression result is unexpected
        uploadTask = storageRef.putFile(imageFile);
        debugPrint(
          'Using original image as compression returned unexpected type',
        );
      }

      // 업로드 완료 대기
      TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);

      // 업로드된 파일의 다운로드 URL 가져오기
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // 4. Firestore 사용자 문서 업데이트
      await _firestore.collection('users').doc(uid).update({
        'profile_image': downloadUrl,
        'updatedAt': Timestamp.now(),
      });

      debugPrint('프로필 이미지 업로드 완료: $downloadUrl');

      // 업로드 성공
      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('프로필 이미지 업로드 중 오류 발생: $e');
      Fluttertoast.showToast(msg: '프로필 이미지를 업로드하는 중 오류가 발생했습니다');

      // 업로드 상태 초기화
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  // 프로필 이미지 업데이트 통합 함수 (이미지 선택 및 업로드)
  Future<bool> updateProfileImage() async {
    try {
      // 1. 갤러리에서 이미지 선택
      final File? selectedImage = await pickImageFromGallery();
      if (selectedImage == null) {
        return false; // 사용자가 이미지 선택을 취소함
      }

      // 2. 이미지 업로드
      return await uploadProfileImage(selectedImage);
    } catch (e) {
      debugPrint('프로필 이미지 업데이트 중 오류 발생: $e');
      Fluttertoast.showToast(msg: '프로필 이미지를 업데이트하는 중 오류가 발생했습니다');
      return false;
    }
  }
}
