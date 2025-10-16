# 텍스트 댓글 흐름 수정

## 문제점

텍스트 댓글 전송 시 바로 Firestore에 저장되고 음성 녹음 위젯으로 전환되는 문제가 있었습니다.

## 해결 방법

음성 댓글과 동일한 pending 패턴을 적용하여 다음 흐름으로 변경했습니다:

### 새로운 흐름

#### 1. 텍스트 입력 및 전송

- 사용자가 텍스트 입력 후 send_icon 클릭
- `VoiceCommentTextWidget._sendTextComment()` 호출
- **Firestore에 바로 저장하지 않음**
- 텍스트를 `onTextCommentCreated` 콜백으로 전달

#### 2. Pending 상태 저장

- `PhotoCardWidgetCommon._handleTextCommentCreated(text)` 호출
- `onTextCommentCompleted(photoId, text)` 콜백 전달
- `VoiceCommentStateManager.onTextCommentCompleted()` 호출
- `_pendingVoiceComments[photoId]`에 임시 저장:
  ```dart
  PendingVoiceComment(
    text: text,
    isTextComment: true,
  )
  ```

#### 3. 프로필 드래그 모드 활성화

- `onToggleVoiceComment(photoId)` 호출
- `voiceCommentActiveStates[photoId] = true`
- **음성 녹음 위젯이 아닌 VoiceCommentWidget이 활성화됨**
- 드래그 가능한 프로필 표시

#### 4. 프로필 위치 지정

- 사용자가 프로필을 드래그하여 사진 위에 배치
- `onProfileImageDragged(photoId, offset)` 호출
- 위치 정보를 `_profileImagePositions[photoId]`에 저장

#### 5. 실제 저장 (프로필 클릭 시)

- 사용자가 프로필(파형) 클릭
- `saveVoiceComment(photoId, context)` 호출
- `_pendingVoiceComments[photoId]`에서 pending 댓글 가져오기
- `isTextComment` 여부에 따라 분기:
  - **텍스트 댓글**: `createTextComment()` 호출
  - **음성 댓글**: `createCommentRecord()` 호출
- `relativePosition`과 함께 Firestore에 저장

## 수정된 파일들

### 1. `PendingVoiceComment` 클래스 확장

**파일**: `lib/views/about_feed/manager/voice_comment_state_manager.dart`

```dart
class PendingVoiceComment {
  final String? audioPath;
  final List<double>? waveformData;
  final int? duration;
  final String? text; // 텍스트 댓글용
  final bool isTextComment; // 텍스트 댓글 여부
  final Offset? relativePosition;
}
```

### 2. 텍스트 댓글 완료 메서드 추가

**파일**: `lib/views/about_feed/manager/voice_comment_state_manager.dart`

```dart
Future<void> onTextCommentCompleted(
  String photoId,
  String text,
) async {
  if (text.isEmpty) return;

  _pendingVoiceComments[photoId] = PendingVoiceComment(
    text: text,
    isTextComment: true,
  );
  _notifyStateChanged();
}
```

### 3. 저장 메서드 수정

**파일**: `lib/views/about_feed/manager/voice_comment_state_manager.dart`

```dart
Future<void> saveVoiceComment(String photoId, BuildContext context) async {
  final pendingComment = _pendingVoiceComments[photoId];

  CommentRecordModel? commentRecord;

  if (pendingComment.isTextComment) {
    // 텍스트 댓글 저장
    commentRecord = await commentRecordController.createTextComment(
      text: pendingComment.text!,
      photoId: photoId,
      recorderUser: currentUserId,
      profileImageUrl: profileImageUrl,
      relativePosition: currentProfilePosition,
    );
  } else {
    // 음성 댓글 저장
    commentRecord = await commentRecordController.createCommentRecord(
      audioFilePath: pendingComment.audioPath!,
      // ...
    );
  }
}
```

### 4. `VoiceCommentTextWidget` 수정

**파일**: `lib/views/common_widget/about_voice_comment/voice_comment_text_widget.dart`

```dart
Future<void> _sendTextComment() async {
  final text = _textController.text.trim();
  if (text.isEmpty || _isSending) return;

  setState(() {
    _isSending = true;
  });

  try {
    _textController.clear();
    FocusScope.of(context).unfocus();

    // 콜백을 통해 pending 상태로 전환 (Firestore 저장 안 함)
    widget.onTextCommentCreated?.call(text);

    debugPrint('✅ 텍스트 댓글 임시 저장 완료');
  } finally {
    if (mounted) {
      setState(() {
        _isSending = false;
      });
    }
  }
}
```

### 5. Feed Home 콜백 연결

**파일**: `lib/views/about_feed/feed_home.dart`

```dart
Future<void> _onTextCommentCompleted(
  String photoId,
  String text,
) async {
  await _voiceCommentStateManager?.onTextCommentCompleted(
    photoId,
    text,
  );
}

// PhotoCardWidgetCommon에 전달
PhotoCardWidgetCommon(
  // ...
  onTextCommentCompleted: _onTextCommentCompleted,
)
```

### 6. `PhotoCardWidgetCommon` 수정

**파일**: `lib/views/common_widget/abput_photo/photo_card_widget_common.dart`

```dart
final Function(String, String) onTextCommentCompleted;

void _handleTextCommentCreated(String text) {
  // 임시 저장
  widget.onTextCommentCompleted(widget.photo.id, text);
  // 프로필 드래그 모드 활성화
  widget.onToggleVoiceComment(widget.photo.id);
}
```

## 데이터 흐름

```
[사용자 입력]
    ↓
VoiceCommentTextWidget._sendTextComment()
    ↓ (text)
onTextCommentCreated callback
    ↓
PhotoCardWidgetCommon._handleTextCommentCreated()
    ↓ (photoId, text)
onTextCommentCompleted callback
    ↓
FeedHome._onTextCommentCompleted()
    ↓
VoiceCommentStateManager.onTextCommentCompleted()
    ↓
_pendingVoiceComments[photoId] = PendingVoiceComment(text, isTextComment: true)
    ↓
[동시에] onToggleVoiceComment(photoId)
    ↓
voiceCommentActiveStates[photoId] = true
    ↓
[VoiceCommentWidget 활성화 - 프로필 드래그 가능]
    ↓
[사용자가 프로필 드래그]
    ↓
onProfileImageDragged(photoId, offset)
    ↓
_profileImagePositions[photoId] = offset
    ↓
[사용자가 프로필 클릭]
    ↓
saveVoiceComment(photoId, context)
    ↓
isTextComment ? createTextComment() : createCommentRecord()
    ↓
[Firestore에 저장 - relativePosition 포함]
```

## 테스트 시나리오

1. **텍스트 입력**

   - 댓글 입력창에 텍스트 입력
   - Send 아이콘 클릭
   - ✅ 로딩 인디케이터 표시
   - ✅ 입력창 클리어 및 포커스 해제

2. **Pending 상태 확인**

   - `_pendingVoiceComments`에 텍스트 저장 확인
   - Firestore에는 아직 저장되지 않음 확인

3. **프로필 드래그 모드**

   - ✅ VoiceCommentWidget 활성화 (음성 녹음 위젯 아님)
   - ✅ 드래그 가능한 프로필 표시
   - ✅ 프로필을 사진 위로 드래그 가능

4. **위치 지정**

   - 프로필을 원하는 위치에 드래그
   - ✅ 위치 정보 저장 확인

5. **실제 저장**

   - 프로필(파형) 클릭
   - ✅ `saveVoiceComment` 호출
   - ✅ `createTextComment` 호출 (isTextComment=true)
   - ✅ Firestore에 저장 확인
   - ✅ relativePosition 포함 확인

6. **댓글 표시**
   - 댓글 목록에서 텍스트 댓글 확인
   - ✅ 텍스트 내용 표시
   - ✅ 프로필 위치 올바름

## 음성 댓글과의 차이점

| 항목              | 음성 댓글                         | 텍스트 댓글         |
| ----------------- | --------------------------------- | ------------------- |
| Pending 저장 시점 | 녹음 완료 후                      | 텍스트 전송 후      |
| Pending 데이터    | audioPath, waveformData, duration | text                |
| 실제 저장 메서드  | createCommentRecord()             | createTextComment() |
| UI 표시           | 오디오 플레이어                   | 텍스트              |
| 프로필 드래그     | ✅ 동일                           | ✅ 동일             |
| 위치 저장         | ✅ 동일                           | ✅ 동일             |

## 결론

텍스트 댓글도 음성 댓글과 동일한 pending 패턴을 따르게 되어, 사용자가 프로필 위치를 지정한 후에 Firestore에 저장됩니다. 이로써 음성 댓글과 텍스트 댓글의 사용자 경험이 일관되게 유지됩니다.
