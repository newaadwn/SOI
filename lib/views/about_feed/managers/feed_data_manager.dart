import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/comment_record_model.dart';

/// 🗂️ 피드 화면의 모든 상태를 관리하는 클래스
/// ChangeNotifier를 사용하여 상태 변화를 구독할 수 있습니다.
class FeedDataManager extends ChangeNotifier {
  // ==================== 기본 데이터 상태 ====================
  List<Map<String, dynamic>> _allPhotos = [];
  bool _isLoading = true;
  bool _isCategoryListenerActive = false;

  // ==================== 프로필 정보 캐싱 ====================
  final Map<String, String> _userProfileImages = {};
  final Map<String, String> _userIds = {};
  final Map<String, bool> _profileLoadingStates = {};

  // ==================== 음성 댓글 상태 관리 ====================
  final Map<String, bool> _voiceCommentActiveStates = {};
  final Map<String, bool> _voiceCommentSavedStates = {};
  final Map<String, String> _savedCommentIds = {};

  // ==================== 프로필 이미지 관리 ====================
  final Map<String, Offset?> _profileImagePositions = {};
  final Map<String, String> _commentProfileImageUrls = {};

  // ==================== 실시간 스트림 관리 ====================
  final Map<String, List<CommentRecordModel>> _photoComments = {};
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

  // ==================== Getters ====================
  List<Map<String, dynamic>> get allPhotos => _allPhotos;
  bool get isLoading => _isLoading;
  bool get isCategoryListenerActive => _isCategoryListenerActive;

  Map<String, String> get userProfileImages => _userProfileImages;
  Map<String, String> get userIds => _userIds;
  Map<String, bool> get profileLoadingStates => _profileLoadingStates;

  Map<String, bool> get voiceCommentActiveStates => _voiceCommentActiveStates;
  Map<String, bool> get voiceCommentSavedStates => _voiceCommentSavedStates;
  Map<String, String> get savedCommentIds => _savedCommentIds;

  Map<String, Offset?> get profileImagePositions => _profileImagePositions;
  Map<String, String> get commentProfileImageUrls => _commentProfileImageUrls;

  Map<String, List<CommentRecordModel>> get photoComments => _photoComments;
  Map<String, StreamSubscription<List<CommentRecordModel>>>
  get commentStreams => _commentStreams;

  // ==================== 기본 상태 업데이트 ====================

  /// 사진 목록 업데이트
  void updateAllPhotos(List<Map<String, dynamic>> photos) {
    _allPhotos = photos;
    notifyListeners();
  }

  /// 로딩 상태 업데이트
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// 카테고리 리스너 활성화 상태 업데이트
  void setCategoryListenerActive(bool active) {
    _isCategoryListenerActive = active;
    notifyListeners();
  }

  // ==================== 프로필 정보 관리 ====================

  /// 사용자 프로필 이미지 업데이트
  void updateUserProfileImage(String userId, String imageUrl) {
    _userProfileImages[userId] = imageUrl;
    notifyListeners();
  }

  /// 사용자 이름 업데이트
  void updateUserName(String userId, String name) {
    _userIds[userId] = name;
    notifyListeners();
  }

  /// 프로필 로딩 상태 업데이트
  void setProfileLoadingState(String userId, bool loading) {
    _profileLoadingStates[userId] = loading;
    notifyListeners();
  }

  // ==================== 음성 댓글 상태 관리 ====================

  /// 음성 댓글 활성화 상태 토글
  void toggleVoiceCommentActive(String photoId) {
    _voiceCommentActiveStates[photoId] =
        !(_voiceCommentActiveStates[photoId] ?? false);
    notifyListeners();
  }

  /// 음성 댓글 저장 상태 업데이트
  void setVoiceCommentSaved(String photoId, bool saved) {
    _voiceCommentSavedStates[photoId] = saved;
    notifyListeners();
  }

  /// 저장된 댓글 ID 업데이트
  void setSavedCommentId(String photoId, String commentId) {
    _savedCommentIds[photoId] = commentId;
    notifyListeners();
  }

  /// 음성 댓글 삭제 처리
  void deleteVoiceComment(String photoId) {
    _voiceCommentActiveStates[photoId] = false;
    _voiceCommentSavedStates[photoId] = false;
    _profileImagePositions[photoId] = null;
    _savedCommentIds.remove(photoId);
    _commentProfileImageUrls.remove(photoId);
    _photoComments[photoId] = [];
    notifyListeners();
  }

  // ==================== 프로필 이미지 위치 관리 ====================

  /// 프로필 이미지 위치 업데이트
  void updateProfileImagePosition(String photoId, Offset? position) {
    _profileImagePositions[photoId] = position;
    notifyListeners();
  }

  /// 댓글 프로필 이미지 URL 업데이트
  void updateCommentProfileImageUrl(String photoId, String imageUrl) {
    _commentProfileImageUrls[photoId] = imageUrl;
    notifyListeners();
  }

  // ==================== 실시간 댓글 관리 ====================

  /// 사진의 댓글 목록 업데이트
  void updatePhotoComments(String photoId, List<CommentRecordModel> comments) {
    _photoComments[photoId] = comments;
    notifyListeners();
  }

  /// 댓글 스트림 구독 추가
  void addCommentStream(
    String photoId,
    StreamSubscription<List<CommentRecordModel>> subscription,
  ) {
    // 기존 구독이 있다면 취소
    _commentStreams[photoId]?.cancel();
    _commentStreams[photoId] = subscription;
  }

  /// 특정 사진의 댓글 스트림 취소
  void cancelCommentStream(String photoId) {
    _commentStreams[photoId]?.cancel();
    _commentStreams.remove(photoId);
  }

  /// 모든 댓글 스트림 취소
  void cancelAllCommentStreams() {
    for (var subscription in _commentStreams.values) {
      subscription.cancel();
    }
    _commentStreams.clear();
  }

  // ==================== 일괄 상태 업데이트 ====================

  /// 댓글 업데이트 시 관련 상태들을 일괄 업데이트
  void handleCommentUpdate(
    String photoId,
    String currentUserId,
    List<CommentRecordModel> comments,
  ) {
    // 댓글 목록 업데이트
    updatePhotoComments(photoId, comments);

    // 현재 사용자의 댓글 찾기
    final userComment =
        comments
            .where((comment) => comment.recorderUser == currentUserId)
            .firstOrNull;

    if (userComment != null) {
      // 사용자 댓글이 있는 경우
      setVoiceCommentSaved(photoId, true);
      setSavedCommentId(photoId, userComment.id);

      if (userComment.profileImageUrl.isNotEmpty) {
        updateCommentProfileImageUrl(photoId, userComment.profileImageUrl);
      }

      if (userComment.profilePosition != null) {
        updateProfileImagePosition(photoId, userComment.profilePosition!);
      }
    } else {
      // 사용자 댓글이 없는 경우
      setVoiceCommentSaved(photoId, false);
      _savedCommentIds.remove(photoId);
      updateProfileImagePosition(photoId, null);
      _commentProfileImageUrls.remove(photoId);
      updatePhotoComments(photoId, []);
    }
  }

  // ==================== 정리 ====================

  @override
  void dispose() {
    cancelAllCommentStreams();
    super.dispose();
  }
}
