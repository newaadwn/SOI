import 'package:flutter/material.dart';
import '../models/comment_record_model.dart';
import '../services/comment_record_service.dart';

class CommentRecordController extends ChangeNotifier {
  final CommentRecordService _service = CommentRecordService();

  // 상태 관리
  bool _isLoading = false;
  String? _error;
  List<CommentRecordModel> _commentRecords = [];

  // 특정 사진의 댓글들 캐시
  final Map<String, List<CommentRecordModel>> _commentCache = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<CommentRecordModel> get commentRecords =>
      List.unmodifiable(_commentRecords);

  /// 음성 댓글 생성
  Future<CommentRecordModel?> createCommentRecord({
    required String audioFilePath,
    required String photoId,
    required String recorderUser,
    required List<double> waveformData,
    required int duration,
    required String profileImageUrl, // 프로필 이미지 URL 추가
    Offset? profilePosition, // 프로필 이미지 위치 추가 (선택적) - 하위호환성용
    Offset? relativePosition, // 프로필 이미지 상대 위치 (새로운 방식)
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // // debugPrint('🎤 음성 댓글 생성 시작 - 사진: $photoId, 녹음자: $recorderUser');

      // 파형 데이터 정규화
      final normalizedWaveform = _service.normalizeWaveformData(waveformData);

      final commentRecord = await _service.createCommentRecord(
        audioFilePath: audioFilePath,
        photoId: photoId,
        recorderUser: recorderUser,
        waveformData: normalizedWaveform,
        duration: duration,
        profileImageUrl: profileImageUrl, // 프로필 이미지 URL 전달
        profilePosition: profilePosition, // 프로필 이미지 위치 전달 (하위호환성)
        relativePosition: relativePosition, // 상대 위치 전달 (새로운 방식)
      );

      // 캐시 업데이트
      _updateCache(photoId, commentRecord);

      // // debugPrint('✅ 음성 댓글 생성 완료 - ID: ${commentRecord.id}');

      notifyListeners();
      return commentRecord;
    } catch (e) {
      // // debugPrint('❌ 음성 댓글 생성 실패: $e');
      _setError('음성 댓글을 저장할 수 없습니다: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// 음성 댓글의 프로필 이미지 위치 업데이트 (상대 좌표)
  Future<bool> updateRelativeProfilePosition({
    required String commentId,
    required String photoId,
    required Offset relativePosition,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // debugPrint('📍 상대 프로필 위치 업데이트 시작 - 댓글: $commentId, 상대위치: $relativePosition');

      await _service.updateRelativeProfilePosition(
        commentId: commentId,
        relativePosition: relativePosition,
      );

      // 캐시 업데이트
      if (_commentCache.containsKey(photoId)) {
        final commentIndex = _commentCache[photoId]!.indexWhere(
          (comment) => comment.id == commentId,
        );
        if (commentIndex != -1) {
          final updatedComment = _commentCache[photoId]![commentIndex].copyWith(
            relativePosition: relativePosition,
          );
          _commentCache[photoId]![commentIndex] = updatedComment;
        }
      }

      // debugPrint('✅ 상대 프로필 위치 업데이트 완료');
      return true;
    } catch (e) {
      _setError('프로필 위치 업데이트 실패: $e');
      // debugPrint('❌ 상대 프로필 위치 업데이트 실패: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 음성 댓글의 프로필 이미지 위치 업데이트 (기존 절대 좌표 - 하위호환성)
  Future<bool> updateProfilePosition({
    required String commentId,
    required String photoId,
    required Offset profilePosition,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // // debugPrint('📍 프로필 위치 업데이트 시작 - 댓글: $commentId, 위치: $profilePosition');

      await _service.updateProfilePosition(
        commentId: commentId,
        profilePosition: profilePosition,
      );

      // 캐시 업데이트
      if (_commentCache.containsKey(photoId)) {
        final commentIndex = _commentCache[photoId]!.indexWhere(
          (comment) => comment.id == commentId,
        );
        if (commentIndex != -1) {
          final updatedComment = _commentCache[photoId]![commentIndex].copyWith(
            profilePosition: profilePosition,
          );
          _commentCache[photoId]![commentIndex] = updatedComment;
        }
      }

      // // debugPrint('✅ 프로필 위치 업데이트 완료');
      notifyListeners();
      return true;
    } catch (e) {
      // // debugPrint('❌ 프로필 위치 업데이트 실패: $e');
      _setError('프로필 위치를 업데이트할 수 없습니다: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 특정 사용자의 모든 음성 댓글의 프로필 이미지 URL 업데이트
  Future<bool> updateUserProfileImageUrl({
    required String userId,
    required String newProfileImageUrl,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // // debugPrint(' 사용자 음성 댓글 프로필 이미지 URL 업데이트 시작 - userId: $userId');

      await _service.updateUserProfileImageUrl(
        userId: userId,
        newProfileImageUrl: newProfileImageUrl,
      );

      // 캐시된 데이터의 프로필 이미지 URL도 업데이트
      _updateCachedProfileImageUrls(userId, newProfileImageUrl);

      // // debugPrint('✅ 사용자 음성 댓글 프로필 이미지 URL 업데이트 완료');
      notifyListeners();
      return true;
    } catch (e) {
      // // debugPrint('❌ 사용자 음성 댓글 프로필 이미지 URL 업데이트 실패: $e');
      _setError('프로필 이미지 URL을 업데이트할 수 없습니다: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 캐시된 댓글들의 프로필 이미지 URL 업데이트
  void _updateCachedProfileImageUrls(String userId, String newProfileImageUrl) {
    for (String photoId in _commentCache.keys) {
      final comments = _commentCache[photoId]!;
      for (int i = 0; i < comments.length; i++) {
        if (comments[i].recorderUser == userId) {
          _commentCache[photoId]![i] = comments[i].copyWith(
            profileImageUrl: newProfileImageUrl,
          );
        }
      }
    }
  }

  /// 특정 사진의 음성 댓글들 로드
  Future<void> loadCommentRecordsByPhotoId(String photoId) async {
    try {
      _setLoading(true);
      _clearError();

      // 캐시에서 먼저 확인
      if (_commentCache.containsKey(photoId)) {
        _commentRecords = _commentCache[photoId]!;
        notifyListeners();
      }

      // 서버에서 최신 데이터 로드
      final comments = await _service.getCommentRecordsByPhotoId(photoId);

      _commentRecords = comments;
      _commentCache[photoId] = comments;

      // // debugPrint('📥 음성 댓글 로드 완료 - 사진: $photoId, 댓글 수: ${comments.length}');
    } catch (e) {
      // // debugPrint('❌ 음성 댓글 로드 실패: $e');
      _setError('음성 댓글을 불러올 수 없습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 음성 댓글 삭제
  Future<bool> deleteCommentRecord(String commentId, String photoId) async {
    try {
      _setLoading(true);
      _clearError();

      await _service.deleteCommentRecord(commentId);

      // 로컬 상태에서 제거
      _commentRecords.removeWhere((comment) => comment.id == commentId);

      // 캐시 업데이트
      if (_commentCache.containsKey(photoId)) {
        _commentCache[photoId]!.removeWhere(
          (comment) => comment.id == commentId,
        );
      }

      // // debugPrint('🗑️ 음성 댓글 삭제 완료 - ID: $commentId');

      notifyListeners();
      return true;
    } catch (e) {
      // // debugPrint('❌ 음성 댓글 삭제 실패: $e');
      _setError('음성 댓글을 삭제할 수 없습니다: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 특정 사진의 댓글 수 반환
  int getCommentCountByPhotoId(String photoId) {
    return _commentCache[photoId]?.length ?? 0;
  }

  /// 특정 사진의 댓글들 반환 (캐시에서)
  List<CommentRecordModel> getCommentsByPhotoId(String photoId) {
    return _commentCache[photoId] ?? [];
  }

  /// 실시간 음성 댓글 스트림 시작
  Stream<List<CommentRecordModel>> getCommentRecordsStream(String photoId) {
    return _service.getCommentRecordsStream(photoId);
  }

  /// 사용자별 음성 댓글들 로드
  Future<void> loadCommentRecordsByUser(String userId) async {
    try {
      _setLoading(true);
      _clearError();

      final comments = await _service.getCommentRecordsByUser(userId);
      _commentRecords = comments;

      // // debugPrint('👤 사용자 음성 댓글 로드 완료 - 사용자: $userId, 댓글 수: ${comments.length}');
    } catch (e) {
      // // debugPrint('❌ 사용자 음성 댓글 로드 실패: $e');
      _setError('사용자 음성 댓글을 불러올 수 없습니다: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// 에러 상태를 사용자에게 보여주고 자동으로 클리어
  void showErrorToUser(BuildContext context) {
    if (_error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error!),
          backgroundColor: const Color(0xFF5A5A5A),
          duration: const Duration(seconds: 3),
        ),
      );
      _clearError();
    }
  }

  /// 캐시 클리어
  void clearCache() {
    _commentCache.clear();
    _commentRecords.clear();
    notifyListeners();
  }

  /// 특정 사진의 캐시만 클리어
  void clearCacheForPhoto(String photoId) {
    _commentCache.remove(photoId);
    notifyListeners();
  }

  // Private methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void _updateCache(String photoId, CommentRecordModel newComment) {
    if (_commentCache.containsKey(photoId)) {
      _commentCache[photoId]!.add(newComment);
      // 시간순 정렬
      _commentCache[photoId]!.sort(
        (a, b) => a.createdAt.compareTo(b.createdAt),
      );
    } else {
      _commentCache[photoId] = [newComment];
    }
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
