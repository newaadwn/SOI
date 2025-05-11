import 'package:flutter/material.dart';
import '../models/comment_model.dart';

/// 음성 댓글 관련 기능의 Controller 클래스
/// View와 Model 사이의 중개 역할을 합니다.
class CommentController extends ChangeNotifier {
  // 상태 변수들
  bool _isRecording = false;
  String? _audioFilePath;
  bool _isUploading = false;

  // CommentModel 인스턴스
  final CommentModel _commentModel = CommentModel();

  // Getters
  bool get isRecording => _isRecording;
  String? get audioFilePath => _audioFilePath;
  bool get isUploading => _isUploading;

  /// 초기화: 녹음기 활성화 및 권한 요청
  Future<void> initialize() async {
    await _commentModel.openRecorder();
  }

  /// 녹음 시작
  Future<void> startRecording() async {
    if (_isRecording) return;

    try {
      await _commentModel.startRecording();
      _isRecording = true;
      notifyListeners();
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
    }
  }

  /// 녹음 중지
  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      _audioFilePath = await _commentModel.stopRecording();
      _isRecording = false;
      notifyListeners();
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
      _isRecording = false;
      notifyListeners();
    }
  }

  /// 오디오 파일 업로드 후 Firestore에 댓글 정보 저장
  Future<bool> uploadAudio(
    String categoryId,
    String photoId,
    String nickName,
    String userId,
  ) async {
    if (_audioFilePath == null) {
      debugPrint('업로드할 오디오 파일이 없습니다');
      return false;
    }

    _isUploading = true;
    notifyListeners();

    try {
      // 1. 오디오 파일 업로드
      final audioUrl = await _commentModel.uploadAudioToFirestorage(
        _audioFilePath!,
        nickName,
      );

      if (audioUrl == null) {
        debugPrint('오디오 업로드 실패');
        _isUploading = false;
        notifyListeners();
        return false;
      }

      // 2. Firestore에 댓글 정보 저장
      final success = await _commentModel.uploadCommentToFirestore(
        categoryId,
        photoId,
        nickName,
        audioUrl,
        userId,
      );

      _isUploading = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('댓글 업로드 오류: $e');
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  /// 닉네임 가져오기
  Future<String> getNickNameFromFirestore(
    String categoryId,
    String photoId,
  ) async {
    return await _commentModel.getNickNameFromFirestore(categoryId, photoId);
  }

  /// 댓글 목록 가져오기
  Stream<List<Map<String, dynamic>>> fetchComments(
    String categoryId,
    String photoId,
  ) {
    return _commentModel.fetchComments(categoryId, photoId);
  }

  /// 리소스 해제
  @override
  void dispose() {
    _commentModel.closeRecorder();
    super.dispose();
  }
}
