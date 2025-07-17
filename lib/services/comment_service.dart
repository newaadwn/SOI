import 'dart:io';
import 'package:flutter/material.dart';
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
  bool _isValidDuration(double durationInSeconds) {
    return durationInSeconds <= 120.0; // 2분
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
      final micPermission =
          await CommentRepository.requestMicrophonePermission();
      if (!micPermission) {
        return AuthResult.failure('마이크 권한이 필요합니다.');
      }

      // 2. 레코더 및 플레이어 초기화
      await _repository.initializeRecorder();
      await CommentRepository.initializePlayer();

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
      await CommentRepository.disposePlayer();
    } catch (e) {
      debugPrint('댓글 서비스 종료 오류: $e');
    }
  }

  // ==================== 네이티브 녹음 관리 ====================

  /// 네이티브 녹음 시작
  Future<AuthResult> startRecording() async {
    try {
      if (await CommentRepository.isRecording()) {
        return AuthResult.failure('이미 녹음이 진행 중입니다.');
      }

      final recordingPath = await CommentRepository.startRecording();

      if (recordingPath.isEmpty) {
        return AuthResult.failure('네이티브 녹음을 시작할 수 없습니다.');
      }

      debugPrint('댓글 네이티브 녹음 시작됨: $recordingPath');
      return AuthResult.success(recordingPath);
    } catch (e) {
      debugPrint('댓글 네이티브 녹음 시작 오류: $e');
      return AuthResult.failure('네이티브 녹음을 시작할 수 없습니다.');
    }
  }

  /// 네이티브 녹음 중지 및 댓글 데이터 생성
  Future<AuthResult> stopRecording({
    required String categoryId,
    required String photoId,
    required String userId,
    required String nickName,
    String? description,
  }) async {
    try {
      if (!await CommentRepository.isRecording()) {
        return AuthResult.failure('진행 중인 녹음이 없습니다.');
      }

      final recordingPath = await CommentRepository.stopRecording();
      if (recordingPath == null || recordingPath.isEmpty) {
        return AuthResult.failure('네이티브 녹음 파일을 저장할 수 없습니다.');
      }

      debugPrint('댓글 네이티브 녹음 완료: $recordingPath');

      // 파일 존재 여부 확인
      final file = File(recordingPath);
      if (!await file.exists()) {
        return AuthResult.failure('녹음된 파일이 존재하지 않습니다.');
      }

      // 파일 정보 수집 (네이티브로)
      final fileSize = await CommentRepository.getFileSize(recordingPath);
      final duration = await CommentRepository.getAudioDuration(recordingPath);

      debugPrint(
        '📊 댓글 녹음 파일 정보: ${fileSize.toStringAsFixed(2)}MB, ${duration}초',
      );

      // 비즈니스 규칙 검증
      if (!_isValidFileSize(fileSize)) {
        await _repository.deleteLocalFile(recordingPath);
        return AuthResult.failure('파일 크기가 너무 큽니다. (최대 5MB)');
      }

      if (!_isValidDuration(duration)) {
        await _repository.deleteLocalFile(recordingPath);
        return AuthResult.failure('녹음 시간이 너무 깁니다. (최대 2분)');
      }

      // 닉네임 검증
      final nickNameError = _validateNickName(nickName);
      if (nickNameError != null) {
        await _repository.deleteLocalFile(recordingPath);
        return AuthResult.failure(nickNameError);
      }

      // 설명 검증
      final contentError = _validateCommentContent(description);
      if (contentError != null) {
        await _repository.deleteLocalFile(recordingPath);
        return AuthResult.failure(contentError);
      }

      return AuthResult.success({
        'filePath': recordingPath,
        'fileSize': fileSize,
        'duration': duration,
        'categoryId': categoryId,
        'photoId': photoId,
        'userId': userId,
        'nickName': _normalizeText(nickName),
        'description': description != null ? _normalizeText(description) : null,
      });
    } catch (e) {
      debugPrint('댓글 네이티브 녹음 중지 오류: $e');
      return AuthResult.failure('네이티브 녹음을 완료할 수 없습니다.');
    }
  }

  /// 간단한 네이티브 녹음 중지 (UI용)
  Future<AuthResult> stopRecordingSimple() async {
    try {
      final filePath = await CommentRepository.stopRecording();

      if (filePath != null && filePath.isNotEmpty) {
        debugPrint('댓글 간단 녹음 중지: $filePath');
        return AuthResult.success(filePath);
      } else {
        return AuthResult.failure('네이티브 녹음 중지 실패');
      }
    } catch (e) {
      debugPrint('댓글 간단 녹음 중지 오류: $e');
      return AuthResult.failure('네이티브 녹음 중지 중 오류 발생: $e');
    }
  }

  /// 녹음 상태 확인
  Future<bool> get isRecording => CommentRepository.isRecording();

  /// 네이티브 녹음 레벨 스트림 (UI 표시용)
  Future<Stream<double>> getRecordingAmplitudeStream() async {
    return await CommentRepository.getRecordingAmplitudeStream();
  }

  // ==================== 네이티브 재생 관리 ====================

  /// 댓글 오디오 재생 (네이티브)
  Future<AuthResult> playComment(CommentDataModel comment) async {
    try {
      if (await CommentRepository.isPlaying()) {
        await CommentRepository.stopPlaying();
      }

      if (comment.audioUrl.isEmpty) {
        return AuthResult.failure('재생할 수 있는 오디오가 없습니다.');
      }

      await CommentRepository.playFromUrl(comment.audioUrl);
      debugPrint('댓글 오디오 재생 시작: ${comment.audioUrl}');
      return AuthResult.success();
    } catch (e) {
      debugPrint('댓글 재생 오류: $e');
      return AuthResult.failure('댓글을 재생할 수 없습니다.');
    }
  }

  /// 네이티브 재생 중지
  Future<AuthResult> stopPlaying() async {
    try {
      await CommentRepository.stopPlaying();
      debugPrint('댓글 재생 중지');
      return AuthResult.success();
    } catch (e) {
      debugPrint('재생 중지 오류: $e');
      return AuthResult.failure('재생을 중지할 수 없습니다.');
    }
  }

  /// 네이티브 재생 일시정지
  Future<AuthResult> pausePlaying() async {
    try {
      await CommentRepository.pausePlaying();
      debugPrint('댓글 재생 일시정지');
      return AuthResult.success();
    } catch (e) {
      debugPrint('재생 일시정지 오류: $e');
      return AuthResult.failure('재생을 일시정지할 수 없습니다.');
    }
  }

  /// 네이티브 재생 재개
  Future<AuthResult> resumePlaying() async {
    try {
      await CommentRepository.resumePlaying();
      debugPrint('댓글 재생 재개');
      return AuthResult.success();
    } catch (e) {
      debugPrint('재생 재개 오류: $e');
      return AuthResult.failure('재생을 재개할 수 없습니다.');
    }
  }

  /// 네이티브 재생 상태 확인
  Future<bool> get isPlaying => CommentRepository.isPlaying();

  /// 네이티브 재생 위치 설정
  Future<AuthResult> seekTo(double positionInSeconds) async {
    try {
      await CommentRepository.seekTo(positionInSeconds);
      debugPrint('댓글 재생 위치 설정: ${positionInSeconds}초');
      return AuthResult.success();
    } catch (e) {
      debugPrint('재생 위치 설정 오류: $e');
      return AuthResult.failure('재생 위치를 설정할 수 없습니다.');
    }
  }

  /// 네이티브 재생 진행률 스트림
  Future<Stream<Map<String, dynamic>>> getPlaybackProgressStream() async {
    return await CommentRepository.getPlaybackProgressStream();
  }

  // ==================== 댓글 관리 ====================

  /// 댓글 생성 및 업로드 (네이티브 기반)
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

      // 3. 네이티브로 파일 정보 수집
      final fileSize = await CommentRepository.getFileSize(audioFilePath);
      final duration = await CommentRepository.getAudioDuration(audioFilePath);

      debugPrint(
        '📊 댓글 생성 파일 정보: ${fileSize.toStringAsFixed(2)}MB, ${duration}초',
      );

      // 4. 비즈니스 규칙 재검증
      if (!_isValidFileSize(fileSize)) {
        return AuthResult.failure('파일 크기가 너무 큽니다. (최대 5MB)');
      }

      if (!_isValidDuration(duration)) {
        return AuthResult.failure('녹음 시간이 너무 깁니다. (최대 2분)');
      }

      // 5. 네이티브로 오디오 품질 개선 (선택적)
      String uploadFilePath = audioFilePath;
      try {
        // 노이즈 제거
        final noiseCleaned = await CommentRepository.removeNoise(audioFilePath);
        if (noiseCleaned != null) {
          // 볼륨 정규화
          final normalized = await CommentRepository.normalizeVolume(
            noiseCleaned,
          );
          if (normalized != null) {
            uploadFilePath = normalized;
            debugPrint('오디오 품질 개선 완료: $uploadFilePath');
          } else {
            uploadFilePath = noiseCleaned;
            debugPrint('노이즈 제거 완료: $uploadFilePath');
          }
        }
      } catch (e) {
        debugPrint('오디오 품질 개선 실패, 원본 사용: $e');
      }

      // 6. 오디오 파일 업로드
      final audioUrl = await _repository.uploadAudioFile(
        uploadFilePath,
        _normalizeText(nickName),
      );

      // 7. 댓글 데이터 생성 (기존 모델 구조 유지)
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

      // 8. Firestore에 저장
      final commentId = await _repository.saveComment(comment);
      final savedComment = comment.copyWith(id: commentId);

      // 9. 로컬 파일 정리
      await _repository.deleteLocalFile(audioFilePath);
      if (uploadFilePath != audioFilePath) {
        await _repository.deleteLocalFile(uploadFilePath);
      }

      debugPrint('댓글 생성 완료: $commentId');
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

  /// 네이티브 업로드 진행률 스트림
  Stream<Map<String, dynamic>> getUploadProgressStream(
    String filePath,
    String nickName,
  ) {
    return _repository.getUploadProgressStreamWithInfo(filePath, nickName);
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
