import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../repositories/comment_repository.dart';
import '../models/comment_data_model.dart';
import '../models/auth_result.dart';

/// 비즈니스 로직을 처리하는 Service
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class CommentService {
  final CommentRepository _repository = CommentRepository();

  // ==================== 비즈니스 로직 ====================

  /// 댓글 내용 검증
  String? _validateCommentContent(String? description) {
    if (description != null && description.trim().length > 200) {
      return '댓글 설명은 200글자 이하여야 합니다.';
    }
    return null;
  }

  /// 오디오 파일 크기 검증 (5MB 제한)
  bool _isValidFileSize(double fileSizeInMB) {
    return fileSizeInMB <= 5.0;
  }

  /// 오디오 녹음 시간 검증 (최대 2분)
  bool _isValidDuration(int durationInSeconds) {
    return durationInSeconds <= 120; // 2분
  }

  /// 닉네임 검증
  String? _validateNickName(String nickName) {
    if (nickName.trim().isEmpty) {
      return '닉네임을 입력해주세요.';
    }
    if (nickName.trim().length < 2) {
      return '닉네임은 2글자 이상이어야 합니다.';
    }
    if (nickName.trim().length > 10) {
      return '닉네임은 10글자 이하여야 합니다.';
    }
    return null;
  }

  /// 텍스트 정규화
  String _normalizeText(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  // ==================== 초기화 ====================

  /// 서비스 초기화
  Future<AuthResult> initialize() async {
    try {
      // 1. 권한 확인
      final micPermission = await _repository.requestMicrophonePermission();
      if (!micPermission) {
        return AuthResult.failure('마이크 권한이 필요합니다.');
      }

      // 2. 레코더 및 플레이어 초기화
      await _repository.initializeRecorder();
      await _repository.initializePlayer();

      return AuthResult.success();
    } catch (e) {
      debugPrint('댓글 서비스 초기화 오류: $e');
      return AuthResult.failure('댓글 서비스 초기화에 실패했습니다.');
    }
  }

  /// 서비스 종료
  Future<void> dispose() async {
    try {
      await _repository.disposeRecorder();
      await _repository.disposePlayer();
    } catch (e) {
      debugPrint('댓글 서비스 종료 오류: $e');
    }
  }

  // ==================== 녹음 관리 ====================

  /// 녹음 시작
  Future<AuthResult> startRecording() async {
    try {
      if (_repository.isRecording) {
        return AuthResult.failure('이미 녹음이 진행 중입니다.');
      }

      await _repository.startRecording();
      return AuthResult.success();
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
      return AuthResult.failure('녹음을 시작할 수 없습니다.');
    }
  }

  /// 녹음 중지
  Future<AuthResult> stopRecording() async {
    try {
      if (!_repository.isRecording) {
        return AuthResult.failure('진행 중인 녹음이 없습니다.');
      }

      final recordingPath = await _repository.stopRecording();
      if (recordingPath == null) {
        return AuthResult.failure('녹음 파일을 저장할 수 없습니다.');
      }

      // 파일 정보 수집
      final fileSize = await _repository.getFileSize(recordingPath);
      final duration = await _repository.getAudioDuration(recordingPath);

      // 비즈니스 규칙 검증
      if (!_isValidFileSize(fileSize)) {
        await _repository.deleteLocalFile(recordingPath);
        return AuthResult.failure('파일 크기가 너무 큽니다. (최대 5MB)');
      }

      if (!_isValidDuration(duration)) {
        await _repository.deleteLocalFile(recordingPath);
        return AuthResult.failure('녹음 시간이 너무 깁니다. (최대 2분)');
      }

      return AuthResult.success({
        'filePath': recordingPath,
        'fileSize': fileSize,
        'duration': duration,
      });
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
      return AuthResult.failure('녹음을 완료할 수 없습니다.');
    }
  }

  /// 녹음 상태 확인
  bool get isRecording => _repository.isRecording;

  /// 녹음 진행률 스트림
  Stream<RecordingDisposition>? get recordingStream =>
      _repository.recordingStream;

  // ==================== 재생 관리 ====================

  /// 댓글 오디오 재생
  Future<AuthResult> playComment(CommentDataModel comment) async {
    try {
      if (_repository.isPlaying) {
        await _repository.stopPlaying();
      }

      if (comment.audioUrl.isEmpty) {
        return AuthResult.failure('재생할 수 있는 오디오가 없습니다.');
      }

      await _repository.playFromUrl(comment.audioUrl);
      return AuthResult.success();
    } catch (e) {
      debugPrint('댓글 재생 오류: $e');
      return AuthResult.failure('댓글을 재생할 수 없습니다.');
    }
  }

  /// 재생 중지
  Future<AuthResult> stopPlaying() async {
    try {
      await _repository.stopPlaying();
      return AuthResult.success();
    } catch (e) {
      debugPrint('재생 중지 오류: $e');
      return AuthResult.failure('재생을 중지할 수 없습니다.');
    }
  }

  /// 재생 상태 확인
  bool get isPlaying => _repository.isPlaying;

  /// 재생 진행률 스트림
  Stream<PlaybackDisposition>? get playbackStream => _repository.playbackStream;

  // ==================== 댓글 관리 ====================

  /// 댓글 생성 및 업로드
  Future<AuthResult> createComment({
    required String categoryId,
    required String photoId,
    required String userId,
    required String nickName,
    required String audioFilePath,
    String? description,
  }) async {
    try {
      // 1. 입력값 검증
      final nickNameError = _validateNickName(nickName);
      if (nickNameError != null) {
        return AuthResult.failure(nickNameError);
      }

      final contentError = _validateCommentContent(description);
      if (contentError != null) {
        return AuthResult.failure(contentError);
      }

      // 2. 파일 존재 여부 확인
      if (!File(audioFilePath).existsSync()) {
        return AuthResult.failure('오디오 파일이 존재하지 않습니다.');
      }

      // 3. 파일 정보 수집
      final fileSize = await _repository.getFileSize(audioFilePath);
      final duration = await _repository.getAudioDuration(audioFilePath);

      // 4. 비즈니스 규칙 재검증
      if (!_isValidFileSize(fileSize)) {
        return AuthResult.failure('파일 크기가 너무 큽니다. (최대 5MB)');
      }

      if (!_isValidDuration(duration)) {
        return AuthResult.failure('녹음 시간이 너무 깁니다. (최대 2분)');
      }

      // 5. 오디오 파일 업로드
      final audioUrl = await _repository.uploadAudioFile(
        audioFilePath,
        _normalizeText(nickName),
      );

      // 6. 댓글 데이터 생성
      final comment = CommentDataModel(
        id: '', // Repository에서 생성됨
        categoryId: categoryId,
        photoId: photoId,
        userId: userId,
        nickName: _normalizeText(nickName),
        audioUrl: audioUrl,

        status: CommentStatus.active,
        createdAt: DateTime.now(),
      );

      // 7. Firestore에 저장
      final commentId = await _repository.saveComment(comment);
      final savedComment = comment.copyWith(id: commentId);

      // 8. 로컬 파일 정리
      await _repository.deleteLocalFile(audioFilePath);

      return AuthResult.success(savedComment);
    } catch (e) {
      debugPrint('댓글 생성 오류: $e');
      // 실패 시 로컬 파일 정리
      try {
        await _repository.deleteLocalFile(audioFilePath);
      } catch (_) {}
      return AuthResult.failure('댓글 생성 중 오류가 발생했습니다.');
    }
  }

  /// 댓글 수정
  Future<AuthResult> updateComment({
    required String commentId,
    required String currentUserId,
    String? description,
  }) async {
    try {
      // 1. 기존 댓글 조회
      final existingComment = await _repository.getComment(commentId);
      if (existingComment == null) {
        return AuthResult.failure('댓글을 찾을 수 없습니다.');
      }

      // 2. 권한 확인
      if (!existingComment.canEdit(currentUserId)) {
        return AuthResult.failure('댓글을 수정할 권한이 없습니다.');
      }

      // 3. 입력값 검증
      final contentError = _validateCommentContent(description);
      if (contentError != null) {
        return AuthResult.failure(contentError);
      }

      // 4. 업데이트 데이터 준비
      final updateData = <String, dynamic>{'updatedAt': DateTime.now()};

      if (description != null) {
        updateData['description'] = _normalizeText(description);
      }

      // 5. 업데이트 실행
      await _repository.updateComment(commentId, updateData);

      return AuthResult.success();
    } catch (e) {
      debugPrint('댓글 수정 오류: $e');
      return AuthResult.failure('댓글 수정 중 오류가 발생했습니다.');
    }
  }

  /// 댓글 삭제
  Future<AuthResult> deleteComment({
    required String commentId,
    required String currentUserId,
    bool hardDelete = false,
  }) async {
    try {
      // 1. 기존 댓글 조회
      final existingComment = await _repository.getComment(commentId);
      if (existingComment == null) {
        return AuthResult.failure('댓글을 찾을 수 없습니다.');
      }

      // 2. 권한 확인
      if (!existingComment.canDelete(currentUserId)) {
        return AuthResult.failure('댓글을 삭제할 권한이 없습니다.');
      }

      // 3. 삭제 실행
      if (hardDelete) {
        // Storage에서 오디오 파일 삭제
        await _repository.deleteAudioFile(existingComment.audioUrl);
        // Firestore에서 완전 삭제
        await _repository.hardDeleteComment(commentId);
      } else {
        // 소프트 삭제 (상태만 변경)
        await _repository.deleteComment(commentId);
      }

      return AuthResult.success();
    } catch (e) {
      debugPrint('댓글 삭제 오류: $e');
      return AuthResult.failure('댓글 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 댓글 신고
  Future<AuthResult> reportComment({
    required String commentId,
    required String reporterId,
    required String reason,
  }) async {
    try {
      if (reason.trim().isEmpty) {
        return AuthResult.failure('신고 사유를 입력해주세요.');
      }

      await _repository.reportComment(commentId, reporterId, reason);
      return AuthResult.success();
    } catch (e) {
      debugPrint('댓글 신고 오류: $e');
      return AuthResult.failure('댓글 신고 중 오류가 발생했습니다.');
    }
  }

  // ==================== 데이터 조회 ====================

  /// 특정 댓글 조회
  Future<CommentDataModel?> getComment(String commentId) async {
    return await _repository.getComment(commentId);
  }

  /// 사진별 댓글 목록 조회
  Future<List<CommentDataModel>> getCommentsByPhoto(
    String categoryId,
    String photoId,
  ) async {
    return await _repository.getCommentsByPhoto(categoryId, photoId);
  }

  /// 사용자별 댓글 목록 조회
  Future<List<CommentDataModel>> getCommentsByUser(String userId) async {
    return await _repository.getCommentsByUser(userId);
  }

  /// 사진별 댓글 스트림
  Stream<List<CommentDataModel>> getCommentsByPhotoStream(
    String categoryId,
    String photoId,
  ) {
    return _repository.getCommentsByPhotoStream(categoryId, photoId);
  }

  /// 사진의 닉네임 조회 (기존 호환성)
  Future<String> getNickNameFromPhoto(String categoryId, String photoId) async {
    return await _repository.getNickNameFromPhoto(categoryId, photoId);
  }

  // ==================== 유틸리티 ====================

  /// 업로드 진행률 스트림
  Stream<double> getUploadProgressStream(String filePath, String nickName) {
    return _repository
        .getUploadProgressStream(filePath, nickName)
        .map((snapshot) => snapshot.bytesTransferred / snapshot.totalBytes);
  }

  /// 댓글 수 계산
  Future<int> getCommentCount(String categoryId, String photoId) async {
    try {
      final comments = await getCommentsByPhoto(categoryId, photoId);
      return comments.length;
    } catch (e) {
      debugPrint('댓글 수 계산 오류: $e');
      return 0;
    }
  }

  /// 사용자가 특정 사진에 댓글을 작성했는지 확인
  Future<bool> hasUserCommented(
    String categoryId,
    String photoId,
    String userId,
  ) async {
    try {
      final comments = await getCommentsByPhoto(categoryId, photoId);
      return comments.any((comment) => comment.userId == userId);
    } catch (e) {
      debugPrint('댓글 작성 여부 확인 오류: $e');
      return false;
    }
  }
}
