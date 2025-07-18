# 친구 추가 기능 설계서

## 개요

SOI 앱에 친구 추가 기능을 구현하기 위한 상세 설계 문서입니다. 기존 MVC 아키텍처 패턴을 유지하면서 Flutter + Firebase Firestore 환경에서 친구 요청 시스템을 구현합니다.

## 기능 플로우

### 친구 요청 프로세스
1. 사용자 A가 친구추가 버튼 클릭
2. 사용자 B에게 친구 요청이 전송됨
3. 사용자 B는 수락 또는 거절 선택 가능
4. 수락 시: 양쪽 사용자의 친구 목록에 추가
5. 거절 시: 요청이 삭제되고 아무 일도 일어나지 않음

## 데이터베이스 구조 설계

### 1. 친구 요청 컬렉션 (friend_requests)
```
friend_requests/
  {requestId}/  // 자동 생성 ID
    senderUid: String           // 요청 보낸 사용자 UID
    receiverUid: String         // 요청 받은 사용자 UID
    senderNickname: String      // 요청 보낸 사용자 닉네임
    receiverNickname: String    // 요청 받은 사용자 닉네임
    status: String              // pending, accepted, rejected
    message: String             // 요청 메시지 (선택사항)
    createdAt: Timestamp        // 요청 생성 시간
    updatedAt: Timestamp        // 마지막 수정 시간
```

### 2. 사용자별 친구 목록 (users/{userId}/friends 서브컬렉션)
```
users/
  {userId}/
    friends/
      {friendUserId}/  // 친구의 UID가 문서 ID
        userId: String           // 친구의 UID
        nickname: String         // 친구의 닉네임
        name: String            // 친구의 실명
        profileImageUrl: String  // 친구의 프로필 이미지
        status: String          // active, blocked
        isFavorite: Boolean     // 즐겨찾기 여부
        addedAt: Timestamp      // 친구 추가된 시간
        lastInteraction: Timestamp // 마지막 상호작용 시간
```

### 3. Firestore 인덱스 (기존 firestore.indexes.json 활용)
```json
{
  "collectionGroup": "friend_requests",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "receiverUid", "order": "ASCENDING" },
    { "fieldPath": "status", "order": "ASCENDING" },
    { "fieldPath": "createdAt", "order": "DESCENDING" }
  ]
}
```

## MVC 아키텍처 구현

### Model 계층

#### FriendRequestModel (lib/models/friend_request_model.dart)
```dart
class FriendRequestModel {
  final String id;
  final String senderUid;
  final String receiverUid;
  final String senderNickname;
  final String receiverNickname;
  final FriendRequestStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime? updatedAt;
}

enum FriendRequestStatus {
  pending,
  accepted, 
  rejected
}
```

#### FriendModel (lib/models/friend_model.dart)
```dart
class FriendModel {
  final String userId;
  final String nickname;
  final String name;
  final String? profileImageUrl;
  final FriendStatus status;
  final bool isFavorite;
  final DateTime addedAt;
  final DateTime? lastInteraction;
}

enum FriendStatus {
  active,
  blocked
}
```

### Repository 계층

#### FriendRequestRepository (lib/repositories/friend_request_repository.dart)
주요 메서드:
- `sendFriendRequest()`: 친구 요청 전송
- `getPendingRequests()`: 대기 중인 요청 목록 조회
- `acceptFriendRequest()`: 친구 요청 수락
- `rejectFriendRequest()`: 친구 요청 거절
- `cancelFriendRequest()`: 친구 요청 취소

#### FriendRepository (lib/repositories/friend_repository.dart)
주요 메서드:
- `getFriendsList()`: 친구 목록 조회
- `addFriend()`: 친구 추가 (양방향)
- `removeFriend()`: 친구 삭제
- `searchFriends()`: 친구 검색
- `updateFriendStatus()`: 친구 상태 업데이트

### Service 계층

#### FriendRequestService (lib/services/friend_request_service.dart)
비즈니스 로직 처리:
- 중복 요청 검증
- 자기 자신에게 요청 방지
- 이미 친구인 경우 처리
- 알림 발송 연동

#### FriendService (lib/services/friend_service.dart)
비즈니스 로직 처리:
- 친구 목록 캐싱
- 친구 상태 동기화
- 친구 검색 최적화

### Controller 계층

#### FriendRequestController (lib/controllers/friend_request_controller.dart)
상태 관리 및 UI 연동:
- 요청 전송 상태 관리
- 받은 요청 목록 관리
- 보낸 요청 목록 관리
- 요청 처리 결과 알림

#### FriendController (lib/controllers/friend_controller.dart)
상태 관리 및 UI 연동:
- 친구 목록 상태 관리
- 검색 상태 관리
- 친구 추가/삭제 상태 관리

## 보안 규칙

### Firestore Security Rules
```javascript
// 친구 요청 컬렉션
match /friend_requests/{requestId} {
  allow read: if request.auth != null && 
    (request.auth.uid == resource.data.senderUid || 
     request.auth.uid == resource.data.receiverUid);
  
  allow create: if request.auth != null && 
    request.auth.uid == request.resource.data.senderUid;
  
  allow update: if request.auth != null && 
    request.auth.uid == resource.data.receiverUid;
  
  allow delete: if request.auth != null && 
    (request.auth.uid == resource.data.senderUid || 
     request.auth.uid == resource.data.receiverUid);
}

// 사용자별 친구 목록
match /users/{userId}/friends/{friendId} {
  allow read, write: if request.auth != null && 
    request.auth.uid == userId;
}
```

## 중복 및 유효성 검증

### 요청 전송 전 검증 사항
1. 자기 자신에게 요청하는지 확인
2. 이미 친구인지 확인
3. 이미 대기 중인 요청이 있는지 확인
4. 차단된 사용자인지 확인
5. 존재하는 사용자인지 확인

### 데이터 일관성 보장
1. 친구 요청 수락 시 양방향 친구 관계 생성
2. 트랜잭션을 사용한 원자적 연산
3. 실패 시 롤백 처리

## 성능 최적화

### 쿼리 최적화
1. 복합 인덱스 활용으로 빠른 검색
2. 페이지네이션을 통한 대용량 데이터 처리
3. 실시간 리스너 최소화

### 캐싱 전략
1. 친구 목록 로컬 캐싱
2. 프로필 이미지 캐싱
3. 자주 접근하는 데이터 메모리 캐싱

## 사용자 경험 (UX) 고려사항

### 실시간 알림
1. 친구 요청 도착 시 푸시 알림
2. 요청 수락/거절 시 결과 알림
3. 앱 내 실시간 상태 업데이트

### UI/UX 상태 관리
1. 로딩 상태 표시
2. 에러 상태 처리
3. 성공/실패 피드백
4. 오프라인 상태 대응

## 테스트 시나리오

### 단위 테스트
1. 친구 요청 전송 테스트
2. 친구 요청 수락/거절 테스트
3. 친구 목록 조회 테스트
4. 유효성 검증 테스트

### 통합 테스트
1. 전체 친구 추가 플로우 테스트
2. 동시 요청 처리 테스트
3. 네트워크 오류 상황 테스트

## 구현 순서

### 1단계: 데이터 모델 및 Repository
- FriendRequestModel, FriendModel 구현
- FriendRequestRepository, FriendRepository 구현
- Firestore 보안 규칙 설정

### 2단계: 서비스 계층
- FriendRequestService, FriendService 구현
- 비즈니스 로직 및 유효성 검증 구현

### 3단계: 컨트롤러 계층
- FriendRequestController, FriendController 구현
- Provider를 통한 상태 관리

### 4단계: UI 구현
- 친구 요청 화면
- 친구 목록 화면
- 친구 검색 화면

### 5단계: 테스트 및 최적화
- 단위 테스트 작성
- 성능 측정 및 최적화
- 사용자 피드백 반영

## 추후 확장 가능성

### 고급 기능
1. 친구 그룹 관리
2. 친구 추천 시스템
3. 소셜 그래프 분석
4. 친구 활동 피드

### 보안 강화
1. 스팸 요청 방지
2. 사용자 신고 시스템
3. 자동 차단 기능

이 설계서는 SOI 앱의 기존 아키텍처와 완벽하게 호환되며, 확장 가능한 친구 추가 시스템을 제공합니다. 