# 🔧 reCAPTCHA 문제 해결 체크리스트

## 현재 상황
- reCAPTCHA가 여전히 나타나는 문제 발생
- APNs 토큰 설정과 Firebase 콘솔 설정이 필요

## ✅ 즉시 해결 방법 (임시)

### 1. Firebase 콘솔에서 테스트 전화번호 설정
```
1. Firebase 콘솔 접속: https://console.firebase.google.com/
2. 프로젝트 선택: soi-sns
3. Authentication > Sign-in method > Phone
4. Test phone numbers 추가:
   +821012345678 : 123456
   +821098765432 : 654321
   +821011112222 : 111111
```

### 2. 개발용 빌드로 테스트
```bash
# Debug 모드에서 테스트 (reCAPTCHA 우회 설정 활성화)
flutter run --debug
```

## 🔧 근본적 해결 방법

### 1. Apple Developer Program 등록 (필수)
- 비용: $99/년
- 목적: APNs 인증서 생성 및 Silent Push 사용

### 2. APNs 키 생성 및 설정
```
1. Apple Developer Console > Certificates, Identifiers & Profiles
2. Keys > Create a key
3. Apple Push Notifications service (APNs) 체크
4. 키 다운로드 (.p8 파일)
5. Key ID와 Team ID 기록
```

### 3. Firebase 콘솔에서 APNs 키 등록
```
1. Firebase 콘솔 > Project Settings
2. Cloud Messaging 탭
3. iOS 앱 구성 > APNs 인증 키
4. 위에서 생성한 키 정보 입력:
   - Key ID
   - Team ID
   - APNs 인증 키 파일 (.p8)
```

### 4. iOS 앱 설정 완료
```
1. Firebase 콘솔 > Project Settings > General
2. iOS 앱 > App Store ID 입력
3. Bundle ID 확인: com.newdawn.soiapp
```

## 🔍 디버깅 및 확인

### 1. 실행 시 로그 확인
```
# APNs 토큰 관련 로그:
📱 APNs Token received: [토큰값]
🔧 APNs Token set for SANDBOX environment
✅ APNs Token이 설정되어 reCAPTCHA 없이 SMS 인증이 가능해야 합니다.

# 전화번호 인증 관련 로그:
🔐 전화번호 인증 시작: +821012345678
📱 현재 플랫폼에서 APNs 토큰 사용 여부 확인 중...
✅ SMS 코드 전송 완료 - verificationId: [ID]
```

### 2. 에러 발생 시 확인사항
```
❌ APNs Token 등록 실패: [에러메시지]
💡 이 경우 reCAPTCHA가 표시될 수 있습니다.
💡 해결 방법:
   1. Apple Developer Program 가입 확인
   2. Provisioning Profile 확인
   3. Firebase 콘솔에서 APNs 키 설정
```

## 📱 테스트 시나리오

### 테스트 전화번호 사용 (즉시 가능)
```dart
// 테스트 번호로 인증 시도
전화번호: 01012345678
예상 동작: reCAPTCHA 없이 바로 SMS 코드 입력 화면
인증코드: 123456
```

### 실제 전화번호 사용 (APNs 설정 후)
```dart
// 실제 번호로 인증 시도
전화번호: 실제 전화번호
예상 동작: reCAPTCHA 없이 실제 SMS 수신
인증코드: SMS로 받은 실제 코드
```

## 🚀 배포 준비

### Release 빌드 테스트
```bash
# Release 모드로 빌드 및 테스트
flutter build ios --release
flutter install --release
```

### App Store 배포 시
- APNs 키가 Production 환경으로 설정되어야 함
- Firebase 콘솔에서 Production APNs 인증서 등록 필요

## 💡 주의사항

1. **개발 환경**: DEBUG 모드에서는 테스트 번호 사용 권장
2. **실제 기기**: 시뮬레이터에서는 APNs 토큰 등록 불가
3. **네트워크**: 안정한 인터넷 연결 필요
4. **시간**: APNs 설정 후 즉시 반영되지 않을 수 있음 (최대 1시간)
