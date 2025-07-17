import 'dart:async';
import 'package:flutter/material.dart';
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
  StreamSubscription<Map<String, dynamic>>? _uploadSubscription;

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
        debugPrint('댓글 기능이 준비되었습니다.');
      } else {
        _error = result.error;
        debugPrint(result.error ?? '댓글 초기화에 실패했습니다.');
        debugPrint(result.error ?? '댓글 초기화에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('댓글 컨트롤러 초기화 오류: $e');
      _isLoading = false;
      _error = '댓글 초기화 중 오류가 발생했습니다.';
      notifyListeners();
      debugPrint('댓글 초기화 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  /// Controller 종료
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _uploadSubscription?.cancel();
    _commentService.dispose();
    super.dispose();
  }

  // ==================== 녹음 관리 (네이티브) ====================

  /// 네이티브 녹음 시작
  Future<void> startRecording() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('댓글 네이티브 녹음 시작 요청...');
      final result = await _commentService.startRecording();

      if (result.isSuccess) {
        _isRecording = true;
        _recordingDuration = 0;

        // 녹음 시간 타이머 시작
        _startRecordingTimer();

        _isLoading = false;
        notifyListeners();

        debugPrint('댓글 네이티브 녹음이 시작되었습니다.');
      } else {
        _isLoading = false;
        notifyListeners();

        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '녹음을 시작할 수 없습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('댓글 녹음 시작 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('녹음 시작 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  /// 네이티브 녹음 중지
  Future<void> stopRecording() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 타이머 정리
      _stopRecordingTimer();

      debugPrint('댓글 네이티브 녹음 중지 요청...');
      final result = await _commentService.stopRecordingSimple();

      _isRecording = false;
      _recordingDuration = 0;
      _recordingLevel = 0.0;
      _isLoading = false;

      if (result.isSuccess) {
        _currentRecordingPath = result.data as String?;

        notifyListeners();

        debugPrint('댓글 네이티브 녹음이 완료되었습니다: ${_currentRecordingPath}');
      } else {
        _currentRecordingPath = null;
        notifyListeners();

        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '녹음 완료에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('댓글 녹음 중지 오류: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      _isLoading = false;
      notifyListeners();
      debugPrint('녹음 중지 중 오류가 발생했습니다. 다시 시도해주세요.');
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
        debugPrint('최대 녹음 시간(2분)에 도달했습니다.');
      }
    });
  }

  /// 녹음 시간 타이머 중지
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
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

        _isLoading = false;
        notifyListeners();

        debugPrint('댓글 재생을 시작합니다.');
      } else {
        _isLoading = false;
        notifyListeners();

        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '댓글을 재생할 수 없습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('댓글 재생 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('댓글 재생 중 오류가 발생했습니다. 다시 시도해주세요.');
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
      notifyListeners();

      if (!result.isSuccess) {
        debugPrint(result.error ?? '재생 중지에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('재생 중지 오류: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  // ==================== 댓글 업로드 ====================

  /// 댓글 업로드
  Future<void> uploadComment({
    required String categoryId,
    required String photoId,
    required String userId,
    required String nickName,
    String? description,
  }) async {
    if (_currentRecordingPath == null) {
      debugPrint('업로드할 녹음 파일이 없습니다. 다시 녹음해주세요.');
      return;
    }

    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // 업로드 진행률 모니터링
      _uploadSubscription = _commentService
          .getUploadProgressStream(_currentRecordingPath!, nickName)
          .listen((progressData) {
            // Map에서 progress 값 추출
            _uploadProgress = (progressData['progress'] as double?) ?? 0.0;
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
        _comments.insert(0, newComment);
        notifyListeners();

        debugPrint('댓글이 성공적으로 업로드되었습니다.');
        debugPrint('댓글 업로드가 완료되었습니다.');
      } else {
        debugPrint(result.error ?? '댓글 업로드에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('댓글 업로드 오류: $e');
      _isUploading = false;
      _uploadProgress = 0.0;
      _currentRecordingPath = null;
      _uploadSubscription?.cancel();
      notifyListeners();
      debugPrint('댓글 업로드 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  // ==================== 데이터 관리 ====================

  /// 특정 사진의 댓글 목록 로드
  Future<void> loadComments(String categoryId, String photoId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _comments = await _commentService.getCommentsByPhoto(categoryId, photoId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('댓글 목록 로드 오류: $e');
      _error = '댓글 목록을 불러오는 중 오류가 발생했습니다.';
      _comments = [];
      _isLoading = false;
      notifyListeners();
      debugPrint('댓글 목록을 불러오는 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  /// 댓글 삭제
  Future<void> deleteComment(String commentId, String currentUserId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _commentService.deleteComment(
        commentId: commentId,
        currentUserId: currentUserId,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        _comments.removeWhere((comment) => comment.id == commentId);
        notifyListeners();

        debugPrint('댓글이 삭제되었습니다.');
      } else {
        debugPrint(result.error ?? '댓글 삭제에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      debugPrint('댓글 삭제 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('댓글 삭제 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  // ==================== 유틸리티 ====================

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
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
}
