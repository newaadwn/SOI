# 🚀 Firebase 테스트 전화번호 설정 가이드

## APNs 설정 완료 후 즉시 테스트하는 방법

### 1. Firebase 콘솔 설정
```
1. https://console.firebase.google.com/ 접속
2. 프로젝트 선택: soi-sns
3. Authentication > Sign-in method 메뉴
4. Phone 항목 클릭
5. "Test phone numbers" 섹션에서 추가 버튼 클릭
```

### 2. 테스트 번호 추가
```
전화번호: +821012345678
SMS 코드: 123456

전화번호: +821098765432  
SMS 코드: 654321

전화번호: +821011112222
SMS 코드: 111111
```

### 3. 앱에서 테스트
```
1. 앱 실행
2. 전화번호 입력: 01012345678
3. "인증번호 받기" 버튼 클릭
4. reCAPTCHA 없이 바로 인증번호 입력 화면으로 이동
5. 인증번호 입력: 123456
6. 로그인 성공 확인
```

## 🔧 APNs 설정 적용 확인 방법

### 1시간 후 실제 번호로 테스트:
```
1. 실제 전화번호 입력 (예: 010-1234-5678)
2. "인증번호 받기" 버튼 클릭  
3. reCAPTCHA 없이 실제 SMS 수신 확인
4. 받은 인증번호로 로그인 성공
```

## 📱 로그 확인 포인트

앱 실행 시 다음 로그들을 확인:

### Firebase 초기화 로그:
```
🔥 Firebase 초기화 완료
🔥 프로젝트 ID: soi-sns-xxxxx
🔥 Bundle ID: com.newdawn.soiapp
```

### APNs 토큰 등록 로그:
```
📱 APNs Token received: [32자리 토큰]
🔧 APNs Token set for SANDBOX environment
✅ APNs Token이 Firebase Auth에 등록되었습니다.
```

### 전화번호 인증 로그:
```
🔐 전화번호 인증 시작: +821012345678
📱 현재 플랫폼에서 APNs 토큰 사용 여부 확인 중...
✅ SMS 코드 전송 완료 - verificationId: [ID]
```

## ⚠️ 문제 지속 시 체크리스트

### 1. Firebase 콘솔에서 확인:
- [ ] APNs 키가 올바른 앱에 등록됨
- [ ] Bundle ID 정확히 일치 (com.newdawn.soiapp)
- [ ] Key ID, Team ID 정확함
- [ ] Development/Production 키 모두 등록됨

### 2. 앱 설정 확인:
- [ ] 실제 iPhone 기기 사용 (시뮬레이터 X)
- [ ] 안정적인 네트워크 연결
- [ ] iOS 설정에서 알림 허용
- [ ] Debug 모드로 테스트

### 3. 시간 확인:
- [ ] APNs 키 등록 후 1시간 경과
- [ ] Firebase 콘솔에서 테스트 번호 설정 완료

## 🎯 권장 테스트 순서

1. **즉시 (테스트 번호)**: Firebase 콘솔에서 테스트 번호 설정 → 앱에서 테스트
2. **1시간 후 (실제 번호)**: APNs 설정 적용 확인 → 실제 번호로 테스트  
3. **문제 지속시**: Firebase Support 문의 또는 설정 재검토
