# 텍스트 댓글 기능 구현

## 개요

음성 댓글 기능을 확장하여 텍스트 댓글도 지원하도록 구현했습니다.

## 구현 완료 사항

### 1. 데이터 모델 업데이트 ✅

**파일**: `lib/models/comment_record_model.dart`

추가된 내용:

- `CommentType` enum (audio, text)
- `type` 필드 (댓글 타입)
- `text` 필드 (텍스트 댓글 내용)
- `fromFirestore()`, `toFirestore()`, `copyWith()` 메서드에 새 필드 지원 추가

### 2. Repository 레이어 업데이트 ✅

**파일**: `lib/repositories/comment_record_repository.dart`

추가된 메서드:

```dart
Future<CommentRecordModel> createTextComment({
  required String text,
  required String photoId,
  required String recorderUser,
  required String profileImageUrl,
  Offset? relativePosition,
})
```

특징:

- 오디오 파일 업로드 스킵
- audioUrl = '', waveformData = [], duration = 0
- type = CommentType.text

### 3. Service 레이어 업데이트 ✅

**파일**: `lib/services/comment_record_service.dart`

추가된 메서드:

```dart
Future<CommentRecordModel> createTextComment({
  required String text,
  required String photoId,
  required String recorderUser,
  required String profileImageUrl,
  Offset? relativePosition,
})
```

기능:

- 입력값 유효성 검사
- Repository를 통한 저장
- 알림 생성

### 4. Controller 레이어 업데이트 ✅

**파일**: `lib/controllers/comment_record_controller.dart`

추가된 메서드:

```dart
Future<CommentRecordModel?> createTextComment({
  required String text,
  required String photoId,
  required String recorderUser,
  required String profileImageUrl,
  Offset? relativePosition,
})
```

기능:

- 상태 관리 (loading, error)
- 캐시 업데이트
- UI 알림

### 5. UI 레이어 업데이트 ✅

**파일**: `lib/views/common_widget/about_voice_comment/voice_comment_text_widget.dart`

추가된 기능:

- `TextEditingController` 추가
- `_isSending` 상태 관리
- `_sendTextComment()` 메서드 구현
- `onTextCommentCreated` 콜백 추가
- 전송 버튼에 로딩 인디케이터 추가

**파일**: `lib/views/common_widget/about_voice_comment/voice_recording_widget.dart`

추가된 속성:

- `onTextCommentCreated` 콜백
- `VoiceCommentTextWidget`에 콜백 전달

## 남은 작업 (TODO)

### ✅ 완료된 추가 작업

#### 1. PhotoCardWidgetCommon 업데이트 ✅

**파일**: `lib/views/common_widget/abput_photo/photo_card_widget_common.dart`

구현 내용:

- `_handleTextCommentCreated()` 메서드 추가
- 텍스트 댓글 생성 시 `onToggleVoiceComment()` 호출하여 음성 댓글 모드 활성화
- `VoiceRecordingWidget`에 `onTextCommentCreated` 콜백 전달

#### 2. VoiceCommentListSheet 업데이트 ✅

**파일**: `lib/views/common_widget/about_voice_comment/voice_comment_list_sheet.dart`

구현 내용:

- `selectedCommentId` 파라미터 추가
- 선택된 댓글에 `isHighlighted` 플래그 전달

#### 3. VoiceCommentRow 업데이트 ✅

**파일**: `lib/views/common_widget/about_voice_comment/voice_comment_row_widget.dart`

구현 내용:

- `isHighlighted` 파라미터 추가
- `_buildTextCommentRow()` 메서드 추가 (텍스트 댓글 UI)
- `_buildAudioCommentRow()` 메서드 추가 (음성 댓글 UI)
- 하이라이트 시 `Colors.grey[800]` 배경색 적용
- `comment.type`에 따라 적절한 UI 렌더링

### ⏳ 남은 작업

#### 1. PhotoDisplayWidget 업데이트 필요

**파일**: `lib/views/common_widget/abput_photo/photo_display_widget.dart`

필요한 기능:

1. 댓글 클릭 시 Sheet 열기
2. 클릭된 댓글 ID 전달
3. Sheet에서 해당 댓글 하이라이트

```dart
// 프로필 아바타 클릭 핸들러
void _onCommentProfileTapped(CommentRecordModel comment) {
  showModalBottomSheet(
    context: context,
    builder: (context) => VoiceCommentListSheet(
      photoId: widget.photo.id,
      selectedCommentId: comment.id, // 선택된 댓글 ID 전달
    ),
  );
}
```

## 데이터 흐름

### 텍스트 댓글 생성 흐름

```
1. 사용자가 텍스트 입력 후 전송 버튼 클릭
2. VoiceCommentTextWidget._sendTextComment() 호출
3. CommentRecordController.createTextComment() 호출
4. CommentRecordService.createTextComment() 호출
5. CommentRecordRepository.createTextComment() 호출
6. Firestore에 저장 (type=text, text=내용)
7. 콜백을 통해 commentId 반환
8. onTextCommentCreated(commentId) 호출
9. 부모 위젯에서 프로필 드래그 모드 활성화
```

### 프로필 위치 저장 흐름

```
1. 사용자가 프로필을 드래그하여 사진 위에 배치
2. onProfileImageDragged(photoId, position) 호출
3. CommentRecordController.updateRelativeProfilePosition() 호출
4. Firestore에 relativePosition 업데이트
5. 드래그 모드 종료
```

### 댓글 보기 흐름

```
1. 사용자가 사진 위 프로필 아바타 클릭
2. VoiceCommentListSheet 열림 (selectedCommentId 전달)
3. 해당 commentId의 아이템 하이라이트
4. 텍스트 댓글: 텍스트 내용 표시
5. 음성 댓글: 오디오 플레이어 표시
```

## Firestore 데이터 구조

### 텍스트 댓글 예시

```json
{
  "id": "auto_generated_id",
  "type": "text",
  "text": "멋진 사진이네요!",
  "photoId": "photo123",
  "recorderUser": "user456",
  "profileImageUrl": "https://...",
  "relativePosition": {
    "x": 0.5,
    "y": 0.3
  },
  "createdAt": "2025-10-15T10:30:00Z",
  "isDeleted": false,
  "audioUrl": "",
  "waveformData": [],
  "duration": 0
}
```

### 음성 댓글 예시

```json
{
  "id": "auto_generated_id",
  "type": "audio",
  "audioUrl": "https://storage.../audio.aac",
  "photoId": "photo123",
  "recorderUser": "user789",
  "profileImageUrl": "https://...",
  "relativePosition": {
    "x": 0.7,
    "y": 0.4
  },
  "waveformData": [0.5, 0.8, 0.3, ...],
  "duration": 5000,
  "createdAt": "2025-10-15T10:35:00Z",
  "isDeleted": false
}
```

## 테스트 시나리오

1. ✅ 텍스트 입력 후 전송 버튼 클릭
2. ⏳ 댓글이 Firestore에 저장되는지 확인
3. ⏳ 프로필 드래그 모드로 전환되는지 확인
4. ⏳ 프로필을 드래그하여 위치 지정 가능한지 확인
5. ⏳ 위치 저장 후 프로필이 사진에 표시되는지 확인
6. ⏳ 프로필 클릭 시 댓글 목록이 열리는지 확인
7. ⏳ 텍스트 댓글이 올바르게 표시되는지 확인
8. ⏳ 선택된 댓글이 하이라이트되는지 확인

## 주의사항

1. **하위 호환성**: 기존 음성 댓글은 `type` 필드가 없을 수 있으므로 `fromFirestore()`에서 기본값을 `CommentType.audio`로 설정
2. **캐시 관리**: 텍스트 댓글도 `CommentRecordController`의 캐시에 포함되어야 함
3. **알림**: 텍스트 댓글도 음성 댓글과 동일하게 알림 생성
4. **성능**: 텍스트 댓글은 오디오 파일 업로드가 없어 빠름
5. **UI/UX**: 프로필 드래그 모드의 사용자 경험이 직관적이어야 함
