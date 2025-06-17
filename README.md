# SOI 앱 프로젝트 전체 분석 보고서

## 📱 프로젝트 개요
**SOI (Social Imaging)** - 친구들과 함께 사진과 음성을 공유하는 소셜 이미징 플랫폼

- **프로젝트명**: flutter_swift_camera
- **플랫폼**: Android, iOS, Web, macOS, Linux, Windows (Flutter 멀티플랫폼)
- **언어**: Dart (Flutter), Swift (iOS 네이티브), Kotlin (Android 네이티브)
- **백엔드**: Firebase (Auth, Firestore, Storage)

---

## 🏗️ 아키텍처 패턴

### MVC + Provider 패턴
```
lib/
├── models/          # 데이터 모델 & 비즈니스 로직
├── views/           # UI 화면 (Pages & Widgets)
├── controllers/     # 상태 관리 & View-Model 중간 계층
├── services/        # 외부 서비스 연동
└── theme/           # 앱 디자인 시스템
```

### 상태 관리: Provider + ChangeNotifier
- **AuthController**: 사용자 인증 및 사용자 정보 관리
- **CategoryController**: 카테고리 및 사진 관리
- **AudioController**: 음성 녹음/재생 관리
- **CommentController**: 음성 댓글 시스템
- **ContactsController**: 연락처/친구 관리

---

## 🔧 기술 스택 상세

### **Frontend (Flutter)**
```yaml
dependencies:
  flutter: sdk
  provider: ^6.1.4               # 상태 관리
  firebase_core: ^3.13.0         # Firebase 기본
  firebase_auth: ^5.6.0          # 전화번호 인증
  cloud_firestore: ^5.6.9        # NoSQL 데이터베이스
  firebase_storage: ^12.4.5      # 파일 저장소
  
  # UI/UX
  google_fonts: ^6.2.1
  solar_icons: ^0.0.5
  fluentui_system_icons: ^1.1.273
  
  # 미디어 처리
  image_picker: ^*                # 이미지 선택
  flutter_image_compress: ^*      # 이미지 압축
  flutter_sound: ^*               # 음성 녹음/재생
  cached_network_image: ^3.4.1    # 이미지 캐싱
  
  # 시스템 연동
  flutter_contacts: ^*            # 연락처 접근
  permission_handler: ^12.0.0+1   # 권한 관리
  
  # 기타
  fluttertoast: ^8.2.12          # 토스트 메시지
  lottie: ^3.3.1                 # 애니메이션
```

### **Backend (Firebase)**
- **Authentication**: 전화번호 기반 인증 + reCAPTCHA
- **Firestore**: 실시간 NoSQL 데이터베이스
- **Storage**: 이미지/음성 파일 저장
- **Rules**: 인증 기반 보안 규칙

### **Native Integration**
- **iOS**: Swift로 카메라 플러그인 구현
- **Android**: Kotlin으로 플랫폼 채널 구현
- **Web**: HTML5 + reCAPTCHA 지원

---

## 📊 데이터베이스 구조 (Firestore)

### Collections
```javascript
users/
  {userId}/
    uid: String           // Firebase Auth UID
    id: String           // 사용자 닉네임
    name: String         // 실명
    phone: String        // 전화번호
    birth_date: String   // 생년월일
    profile_image: String // 프로필 이미지 URL
    createdAt: Timestamp
    lastLogin: Timestamp
    
    friends/             // 서브컬렉션
      {contactId}/
        displayName: String
        phoneNumber: String
        emails: Array<String>
        phoneNumbers: Array<String>
        createdAt: Timestamp

categories/
  {categoryId}/
    name: String              // 카테고리 이름
    userId: Array<String>     // 참여자 UID 배열
    mates: Array<String>      // 참여자 닉네임 배열
    photoCount: Number        // 사진 개수
    createdAt: Timestamp
    
    photos/                   // 서브컬렉션
      {photoId}/
        userId: String        // 업로더 UID
        imageUrl: String      // 이미지 URL
        audioUrl: String      // 음성 메모 URL
        createdAt: Timestamp
        
        comments/             // 서브컬렉션
          {userNickname}/     // 댓글 작성자 닉네임이 문서 ID
            userNickname: String
            userId: String
            audioUrl: String  // 음성 댓글 URL
            createdAt: Timestamp
```

### Storage 구조
```
profiles/{userId}/          // 프로필 이미지
  profile_{userId}_{timestamp}.png
  
categories/photos/          // 카테고리 사진들
  {categoryId}_{timestamp}.jpg
  
categories_comments_audio/  // 음성 댓글
  {nickname}_comment_{timestamp}.aac
  
audio/                     // 일반 음성 파일
  {timestamp}.aac
```

---

## 🎯 주요 기능 모듈

### 1. **인증 시스템** (`auth_model.dart`, `auth_controller.dart`)
**특징:**
- 전화번호 기반 인증 (국제 표준 +82 형식)
- 플랫폼별 구분 처리 (Web: reCAPTCHA, Native: SMS)
- 기존 사용자 자동 연동 시스템

**주요 메서드:**
- `verifyPhoneNumber()`: 플랫폼별 전화번호 인증
- `signInWithSmsCode()`: SMS 코드 확인
- `createUserInFirestore()`: 사용자 정보 저장/업데이트
- `findUserByPhone()`: 전화번호로 기존 사용자 검색

### 2. **카메라 & 사진 관리** (`camera_screen.dart`, `photo_editor_screen.dart`)
**특징:**
- iOS/Android 네이티브 카메라 플러그인
- 실시간 카메라 제어 (줌, 플래시, 밝기)
- 이미지 압축 및 최적화
- 드래그 가능한 카테고리 선택 UI

**주요 기능:**
- 실시간 카메라 미리보기
- 사진 촬영 및 편집
- 카테고리별 사진 분류
- 음성 메모 첨부

### 3. **음성 시스템** (`audio_controller.dart`, `comment_model.dart`)
**특징:**
- Flutter Sound 기반 녹음/재생
- 사진별 음성 메모
- 실시간 음성 댓글 시스템
- 권한 관리 자동화

**주요 기능:**
- 음성 녹음/재생/정지
- Firebase Storage 업로드
- 실시간 음성 댓글
- 음성 파일 압축

### 4. **소셜 기능** (`category_model.dart`, `contact_model.dart`)
**특징:**
- 연락처 기반 친구 시스템
- 카테고리 기반 그룹 공유
- 실시간 데이터 동기화
- 다중 사용자 카테고리 지원

**주요 기능:**
- 친구 추가/관리
- 카테고리 생성/공유
- 실시간 댓글 시스템
- 프로필 이미지 관리

### 5. **아카이빙 시스템** (`archive_*.dart`)
**특징:**
- 3가지 아카이브 뷰 (전체/개인/공유)
- 실시간 사진 스트리밍
- 카테고리별 필터링
- 그리드 기반 갤러리 UI

**화면 구성:**
- `AllArchivesScreen`: 모든 카테고리 보기
- `PersonalArchivesScreen`: 개인 카테고리만
- `SharedArchivesScreen`: 공유 카테고리만
- `CategoryPhotosScreen`: 카테고리 상세 사진 보기

---

## 🖥️ 화면 플로우

### 인증 플로우
```
StartScreen → LoginScreen ↔ RegisterScreen → AuthFinalScreen → HomeNavigatorScreen
```

### 메인 네비게이션 (하단 탭)
```
HomeScreen (카테고리 목록)
CameraScreen (실시간 카메라)
ArchiveMainScreen (아카이브 탭)
```

### 카테고리 관리 플로우
```
CategorySelectScreen → CategoryAddScreen
CategoryScreen → CategoryScreenPhoto → PhotoDetailScreen
```

### 사진 촬영 플로우
```
CameraScreen → PhotoEditorScreen → CategorySelection → Upload
```

---

## 🔒 보안 및 권한

### Firestore 보안 규칙
```javascript
// 개발 모드 (현재)
match /{document=**} {
  allow read, write: if request.auth != null;
}

// 프로덕션 권장 규칙
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}
match /categories/{categoryId} {
  allow read, write: if request.auth != null;
}
```

### 앱 권한
- **카메라**: 사진 촬영
- **마이크**: 음성 녹음
- **연락처**: 친구 추가
- **저장소**: 이미지 처리
- **알림**: 푸시 알림 (iOS)

---

## 🚀 플랫폼별 구현

### iOS (`ios/Runner/`)
- `AppDelegate.swift`: Firebase 초기화, 푸시 알림 설정
- `SwiftCameraPlugin.swift`: 커스텀 카메라 플러그인
- `SimpleCameraPlugin.swift`: 카메라 미리보기 구현
- `CameraViewController.swift`: 카메라 제어 로직

### Android (`android/app/src/main/kotlin/`)
- `FlutterSwiftCameraApplication.kt`: 멀티덱스 설정
- `google-services.json`: Firebase 구성

### Web (`web/`)
- `index.html`: reCAPTCHA 스크립트 포함
- Firebase JS SDK 자동 로드

---

## 📈 성능 최적화

### 이미지 최적화
- **압축**: `flutter_image_compress` 사용
- **캐싱**: `cached_network_image`로 네트워크 이미지 캐싱
- **지연 로딩**: `StreamBuilder`로 실시간 데이터 로딩

### 메모리 관리
- **Controller 해제**: `dispose()` 메서드 구현
- **스트림 구독 해제**: 자동 메모리 정리
- **이미지 압축**: 업로드 전 자동 압축

### 네트워크 최적화
- **실시간 동기화**: Firestore 실시간 리스너
- **오프라인 지원**: Firestore 오프라인 캐시
- **배치 업로드**: 대용량 파일 청크 업로드

---

## 🐛 에러 처리 및 로깅

### 전역 에러 처리 (`main.dart`)
```dart
FlutterError.onError = (FlutterErrorDetails details) {
  FlutterError.presentError(details);
  debugPrint('FlutterError: ${details.exception}');
};

PlatformDispatcher.instance.onError = (error, stack) {
  debugPrint('PlatformDispatcher Error: $error');
  return true;
};
```

### 모델별 에러 처리
- Try-catch 블록으로 세밀한 예외 처리
- 사용자 친화적 에러 메시지 (Fluttertoast)
- 디버그 로그로 개발자 디버깅 지원

---

## 🔄 상태 관리 패턴

### Provider + ChangeNotifier 구조
```dart
// Controller Layer (ChangeNotifier)
class AuthController extends ChangeNotifier {
  final AuthModel _authModel = AuthModel();
  
  // View에서 호출할 메서드들
  Future<void> signIn() async {
    // Model 호출 후 notifyListeners()
  }
}

// Model Layer (비즈니스 로직)
class AuthModel {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 실제 Firebase 연동 로직
}

// View Layer
Consumer<AuthController>(
  builder: (context, controller, child) {
    // UI 빌드
  }
)
```

---

## 📱 UI/UX 디자인 시스템

### 테마 (`theme/theme.dart`)
- **다크 테마 기반**: 검은색 배경 + 회색 톤
- **커스텀 컬러**: `Color(0xFF292929)`, `Color(0xFF232121)`
- **반응형 디자인**: MediaQuery 기반 화면 크기 대응

### 주요 UI 컴포넌트
- **드래그 가능한 바텀시트**: 카테고리 선택
- **그리드 갤러리**: 사진 표시
- **실시간 카메라 미리보기**: 네이티브 플러그인
- **프로필 이미지 행**: 참여자 표시

---

## 🔮 확장 가능성

### 현재 구조의 장점
1. **모듈화**: 각 기능이 독립적으로 구현
2. **확장성**: 새로운 기능 추가 용이
3. **재사용성**: 컴포넌트 기반 구조
4. **테스트 가능성**: 계층 분리로 단위 테스트 가능

### 향후 개선 방향
1. **프로덕션 보안**: Firestore 규칙 세분화
2. **성능 최적화**: 이미지 CDN 도입
3. **오프라인 지원**: 로컬 캐시 강화
4. **푸시 알림**: FCM 댓글 알림 시스템
5. **소셜 기능**: 좋아요, 팔로우 시스템

---

## 💾 프로젝트 설정

### 빌드 구성
- **개발**: `soi-sns` Firebase 프로젝트
- **디버그**: Hot Reload 지원
- **릴리즈**: 자동 코드 사이닝 및 최적화

### 의존성 관리
- **Flutter**: SDK 3.7.0+
- **Dart**: 최신 stable 버전
- **Firebase**: 최신 stable 버전들
- **네이티브**: iOS 12.0+, Android API 21+

이 SOI 앱은 현대적인 Flutter 아키텍처 패턴을 따라 구현되었으며, 확장 가능하고 유지보수가 용이한 구조로 설계되었습니다. 소셜 이미징 플랫폼으로서 필요한 모든 핵심 기능을 포함하고 있으며, 실시간 동기화와 멀티미디어 처리에 최적화되어 있습니다.
