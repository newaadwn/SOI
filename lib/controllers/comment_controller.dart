import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/comment_service.dart';
import '../models/comment_data_model.dart';

/// 댓글 관련 UI와 비즈니스 로직 사이의 중개 역할을 합니다.
class CommentController extends ChangeNotifier {
  // 상태 변수들
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isUploading = false;
  String? _currentRecordingPath;
  String? _currentPlayingCommentId;
  int _recordingDuration = 0;
  double _recordingLevel = 0.0;
  double _playbackPosition = 0.0;
  double _playbackDuration = 0.0;
  double _uploadProgress = 0.0;
  String? _error;

  List<CommentDataModel> _comments = [];
  Timer? _recordingTimer;
  StreamSubscription<RecordingDisposition>? _recordingSubscription;
  StreamSubscription<PlaybackDisposition>? _playbackSubscription;
  StreamSubscription<double>? _uploadSubscription;

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final CommentService _commentService = CommentService();

  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get currentRecordingPath => _currentRecordingPath;
  String? get currentPlayingCommentId => _currentPlayingCommentId;
  int get recordingDuration => _recordingDuration;
  double get recordingLevel => _recordingLevel;
  double get playbackPosition => _playbackPosition;
  double get playbackDuration => _playbackDuration;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  List<CommentDataModel> get comments => _comments;

  // ==================== 초기화 ====================

  /// Controller 초기화
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _commentService.initialize();

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '댓글 기능이 준비되었습니다.');

        // 녹음 진행률 모니터링 시작
        _startRecordingMonitoring();
      } else {
        // ✅ 실패 시 UI 피드백
        _error = result.error;
        Fluttertoast.showToast(msg: result.error ?? '댓글 초기화에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('댓글 컨트롤러 초기화 오류: $e');
      _isLoading = false;
      _error = '댓글 초기화 중 오류가 발생했습니다.';
      notifyListeners();
      Fluttertoast.showToast(msg: '댓글 초기화 중 오류가 발생했습니다.');
    }
  }

  /// Controller 종료
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recordingSubscription?.cancel();
    _playbackSubscription?.cancel();
    _uploadSubscription?.cancel();
    _commentService.dispose();
    super.dispose();
  }

  // ==================== 녹음 관리 ====================

  /// 녹음 시작
  Future<void> startRecording() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _commentService.startRecording();

      if (result.isSuccess) {
        _isRecording = true;
        _recordingDuration = 0;

        // 녹음 시간 타이머 시작
        _startRecordingTimer();

        _isLoading = false;
        notifyListeners();

        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '녹음이 시작되었습니다.');
      } else {
        _isLoading = false;
        notifyListeners();

        // ✅ 실패 시 UI 피드백
        Fluttertoast.showToast(msg: result.error ?? '녹음을 시작할 수 없습니다.');
      }
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
      _isLoading = false;
      notifyListeners();
      Fluttertoast.showToast(msg: '녹음 시작 중 오류가 발생했습니다.');
    }
  }

  /// 녹음 중지
  Future<void> stopRecording() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 타이머 정리
      _stopRecordingTimer();

      final result = await _commentService.stopRecording();

      _isRecording = false;
      _recordingDuration = 0;
      _recordingLevel = 0.0;
      _isLoading = false;

      if (result.isSuccess) {
        final recordingData = result.data as Map<String, dynamic>;
        _currentRecordingPath = recordingData['filePath'];

        notifyListeners();

        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '녹음이 완료되었습니다.');
      } else {
        _currentRecordingPath = null;
        notifyListeners();

        // ✅ 실패 시 UI 피드백
        Fluttertoast.showToast(msg: result.error ?? '녹음 완료에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      _isLoading = false;
      notifyListeners();
      Fluttertoast.showToast(msg: '녹음 중지 중 오류가 발생했습니다.');
    }
  }

  /// 녹음 시간 타이머 시작
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration++;
      notifyListeners();

      // 최대 녹음 시간 (2분) 체크
      if (_recordingDuration >= 120) {
        stopRecording();
        Fluttertoast.showToast(msg: '최대 녹음 시간(2분)에 도달했습니다.');
      }
    });
  }

  /// 녹음 시간 타이머 중지
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  /// 녹음 진행률 모니터링 시작
  void _startRecordingMonitoring() {
    _recordingSubscription = _commentService.recordingStream?.listen((
      disposition,
    ) {
      _recordingLevel = disposition.decibels ?? 0.0;
      notifyListeners();
    });
  }

  /// 녹음 시간을 MM:SS 형식으로 포맷팅
  String get formattedRecordingDuration {
    final minutes = _recordingDuration ~/ 60;
    final seconds = _recordingDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ==================== 재생 관리 ====================

  /// 댓글 재생
  Future<void> playComment(CommentDataModel comment) async {
    try {
      // 이미 재생 중인 댓글이 있으면 중지
      if (_isPlaying) {
        await stopPlaying();
      }

      _isLoading = true;
      notifyListeners();

      final result = await _commentService.playComment(comment);

      if (result.isSuccess) {
        _isPlaying = true;
        _currentPlayingCommentId = comment.id;

        // 재생 진행률 모니터링 시작
        _startPlaybackMonitoring();

        _isLoading = false;
        notifyListeners();

        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '댓글 재생을 시작합니다.');
      } else {
        _isLoading = false;
        notifyListeners();

        // ✅ 실패 시 UI 피드백
        Fluttertoast.showToast(msg: result.error ?? '댓글을 재생할 수 없습니다.');
      }
    } catch (e) {
      debugPrint('댓글 재생 오류: $e');
      _isLoading = false;
      notifyListeners();
      Fluttertoast.showToast(msg: '댓글 재생 중 오류가 발생했습니다.');
    }
  }

  /// 재생 중지
  Future<void> stopPlaying() async {
    try {
      final result = await _commentService.stopPlaying();

      _isPlaying = false;
      _currentPlayingCommentId = null;
      _playbackPosition = 0.0;
      _playbackDuration = 0.0;
      _playbackSubscription?.cancel();
      notifyListeners();

      if (!result.isSuccess) {
        Fluttertoast.showToast(msg: result.error ?? '재생 중지에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('재생 중지 오류: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// 재생 진행률 모니터링 시작
  void _startPlaybackMonitoring() {
    _playbackSubscription = _commentService.playbackStream?.listen((
      disposition,
    ) {
      _playbackPosition = disposition.position.inSeconds.toDouble();
      _playbackDuration = disposition.duration.inSeconds.toDouble();
      notifyListeners();

      // 재생 완료 시 상태 초기화
      if (_playbackPosition >= _playbackDuration && _playbackDuration > 0) {
        _isPlaying = false;
        _currentPlayingCommentId = null;
        _playbackPosition = 0.0;
        notifyListeners();
      }
    });
  }

  // ==================== 댓글 관리 ====================

  /// 댓글 업로드
  Future<void> uploadComment({
    required String categoryId,
    required String photoId,
    required String userId,
    required String nickName,
    String? description,
  }) async {
    if (_currentRecordingPath == null) {
      Fluttertoast.showToast(msg: '업로드할 녹음 파일이 없습니다.');
      return;
    }

    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // 업로드 진행률 모니터링
      _uploadSubscription = _commentService
          .getUploadProgressStream(_currentRecordingPath!, nickName)
          .listen((progress) {
            _uploadProgress = progress;
            notifyListeners();
          });

      final result = await _commentService.createComment(
        categoryId: categoryId,
        photoId: photoId,
        userId: userId,
        nickName: nickName,
        audioFilePath: _currentRecordingPath!,
        description: description,
      );

      _isUploading = false;
      _uploadProgress = 0.0;
      _currentRecordingPath = null;
      _uploadSubscription?.cancel();
      notifyListeners();

      if (result.isSuccess) {
        final newComment = result.data as CommentDataModel;

        // 댓글 목록에 추가
        _comments.add(newComment);
        notifyListeners();

        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '댓글이 업로드되었습니다.');
      } else {
        // ✅ 실패 시 UI 피드백
        Fluttertoast.showToast(msg: result.error ?? '댓글 업로드에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('댓글 업로드 오류: $e');
      _isUploading = false;
      _uploadProgress = 0.0;
      _uploadSubscription?.cancel();
      notifyListeners();
      Fluttertoast.showToast(msg: '댓글 업로드 중 오류가 발생했습니다.');
    }
  }

  /// 댓글 수정
  Future<void> updateComment({
    required String commentId,
    required String currentUserId,
    String? description,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _commentService.updateComment(
        commentId: commentId,
        currentUserId: currentUserId,
        description: description,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 댓글 목록 새로고침
        await _refreshComment(commentId);

        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '댓글이 수정되었습니다.');
      } else {
        // ✅ 실패 시 UI 피드백
        Fluttertoast.showToast(msg: result.error ?? '댓글 수정에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('댓글 수정 오류: $e');
      _isLoading = false;
      notifyListeners();
      Fluttertoast.showToast(msg: '댓글 수정 중 오류가 발생했습니다.');
    }
  }

  /// 댓글 삭제
  Future<void> deleteComment({
    required String commentId,
    required String currentUserId,
    bool hardDelete = false,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _commentService.deleteComment(
        commentId: commentId,
        currentUserId: currentUserId,
        hardDelete: hardDelete,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 댓글 목록에서 제거
        _comments.removeWhere((comment) => comment.id == commentId);
        notifyListeners();

        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '댓글이 삭제되었습니다.');
      } else {
        // ✅ 실패 시 UI 피드백
        Fluttertoast.showToast(msg: result.error ?? '댓글 삭제에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('댓글 삭제 오류: $e');
      _isLoading = false;
      notifyListeners();
      Fluttertoast.showToast(msg: '댓글 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 댓글 좋아요 토글
  Future<void> toggleLike({
    required String commentId,
    required String userId,
  }) async {
    try {
      final result = await _commentService.toggleLike(
        commentId: commentId,
        userId: userId,
      );

      if (result.isSuccess) {
        // 댓글 목록 새로고침
        await _refreshComment(commentId);

        final action = result.data['action'] as String;
        // ✅ UI 피드백
        if (action == 'added') {
          Fluttertoast.showToast(msg: '좋아요를 추가했습니다.');
        } else {
          Fluttertoast.showToast(msg: '좋아요를 취소했습니다.');
        }
      } else {
        // ✅ 실패 시 UI 피드백
        Fluttertoast.showToast(msg: result.error ?? '좋아요 처리에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('좋아요 토글 오류: $e');
      Fluttertoast.showToast(msg: '좋아요 처리 중 오류가 발생했습니다.');
    }
  }

  /// 댓글 신고
  Future<void> reportComment({
    required String commentId,
    required String reporterId,
    required String reason,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _commentService.reportComment(
        commentId: commentId,
        reporterId: reporterId,
        reason: reason,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백
        Fluttertoast.showToast(msg: '댓글 신고가 접수되었습니다.');
      } else {
        // ✅ 실패 시 UI 피드백
        Fluttertoast.showToast(msg: result.error ?? '댓글 신고에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('댓글 신고 오류: $e');
      _isLoading = false;
      notifyListeners();
      Fluttertoast.showToast(msg: '댓글 신고 중 오류가 발생했습니다.');
    }
  }

  // ==================== 데이터 관리 ====================

  /// 사진별 댓글 목록 로드
  Future<void> loadCommentsByPhoto(String categoryId, String photoId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _comments = await _commentService.getCommentsByPhoto(categoryId, photoId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('댓글 목록 로드 오류: $e');
      _error = '댓글을 불러오는 중 오류가 발생했습니다.';
      _comments = [];
      _isLoading = false;
      notifyListeners();

      Fluttertoast.showToast(msg: '댓글을 불러오는 중 오류가 발생했습니다.');
    }
  }

  /// 사용자별 댓글 목록 로드
  Future<void> loadCommentsByUser(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _comments = await _commentService.getCommentsByUser(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('사용자 댓글 목록 로드 오류: $e');
      _error = '댓글을 불러오는 중 오류가 발생했습니다.';
      _comments = [];
      _isLoading = false;
      notifyListeners();

      Fluttertoast.showToast(msg: '댓글을 불러오는 중 오류가 발생했습니다.');
    }
  }

  /// 사진별 댓글 스트림
  Stream<List<CommentDataModel>> getCommentsByPhotoStream(
    String categoryId,
    String photoId,
  ) {
    return _commentService.getCommentsByPhotoStream(categoryId, photoId);
  }

  /// 사진의 닉네임 조회 (기존 호환성)
  Future<String> getNickNameFromPhoto(String categoryId, String photoId) async {
    return await _commentService.getNickNameFromPhoto(categoryId, photoId);
  }

  // ==================== 유틸리티 ====================

  /// 특정 댓글 데이터 새로고침
  Future<void> _refreshComment(String commentId) async {
    try {
      final updatedComment = await _commentService.getComment(commentId);
      if (updatedComment != null) {
        final index = _comments.indexWhere(
          (comment) => comment.id == commentId,
        );
        if (index != -1) {
          _comments[index] = updatedComment;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('댓글 데이터 새로고침 오류: $e');
    }
  }

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 녹음 파일 초기화
  void clearRecording() {
    _currentRecordingPath = null;
    notifyListeners();
  }

  /// 특정 댓글이 현재 재생 중인지 확인
  bool isCommentPlaying(String commentId) {
    return _isPlaying && _currentPlayingCommentId == commentId;
  }

  /// 업로드 진행률 포맷팅
  String get formattedUploadProgress {
    return '${(_uploadProgress * 100).toStringAsFixed(1)}%';
  }

  /// 댓글 수 반환
  int get commentCount => _comments.length;

  /// 사용자가 특정 댓글을 좋아요했는지 확인
  bool isCommentLikedByUser(String commentId, String userId) {
    final comment = _comments.firstWhere(
      (c) => c.id == commentId,
      orElse:
          () => CommentDataModel(
            id: '',
            categoryId: '',
            photoId: '',
            userId: '',
            nickName: '',
            audioUrl: '',
            durationInSeconds: 0,
            fileSizeInMB: 0,
            status: CommentStatus.active,
            createdAt: DateTime.now(),
          ),
    );
    return comment.isLikedBy(userId);
  }
}
