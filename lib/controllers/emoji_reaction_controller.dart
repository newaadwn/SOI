import 'package:flutter/foundation.dart';
import '../models/emoji_reaction_model.dart';

/// 이모티콘 반응 상태를 관리하는 컨트롤러
class EmojiReactionController extends ChangeNotifier {
  // 사진별 이모티콘 반응 저장 (photoId -> 선택된 이모티콘)
  final Map<String, EmojiReactionModel?> _photoReactions = {};

  /// 특정 사진의 선택된 이모티콘 반응 가져오기
  EmojiReactionModel? getPhotoReaction(String photoId) {
    return _photoReactions[photoId];
  }

  /// 특정 사진에 이모티콘 반응 설정
  void setPhotoReaction(String photoId, EmojiReactionModel? reaction) {
    if (_photoReactions[photoId] != reaction) {
      _photoReactions[photoId] = reaction;
      notifyListeners();

      // 실제 서비스에서는 여기에 Firebase 저장 로직 추가
      _saveReactionToServer(photoId, reaction);
    }
  }

  /// 특정 사진의 이모티콘 반응 제거
  void removePhotoReaction(String photoId) {
    if (_photoReactions.containsKey(photoId)) {
      _photoReactions.remove(photoId);
      notifyListeners();

      // 실제 서비스에서는 여기에 Firebase 삭제 로직 추가
      _removeReactionFromServer(photoId);
    }
  }

  /// 특정 사진에 이모티콘 반응이 있는지 확인
  bool hasReaction(String photoId) {
    return _photoReactions[photoId] != null;
  }

  /// 모든 반응 데이터 초기화 (로그아웃 시 등)
  void clearAllReactions() {
    _photoReactions.clear();
    notifyListeners();
  }

  /// 서버에 반응 저장 (향후 Firebase 연동)
  Future<void> _saveReactionToServer(
    String photoId,
    EmojiReactionModel? reaction,
  ) async {
    // TODO: Firebase Firestore에 반응 저장
    // 예: photos/{photoId}/reactions/{userId} 컬렉션에 저장
    try {
      if (kDebugMode) {
        print('Saving reaction for photo $photoId: ${reaction?.emoji}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving reaction: $e');
      }
    }
  }

  /// 서버에서 반응 제거 (향후 Firebase 연동)
  Future<void> _removeReactionFromServer(String photoId) async {
    // TODO: Firebase Firestore에서 반응 제거
    try {
      if (kDebugMode) {
        print('Removing reaction for photo $photoId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error removing reaction: $e');
      }
    }
  }

  /// 서버에서 모든 반응 데이터 로드 (앱 시작 시)
  Future<void> loadReactionsFromServer() async {
    // TODO: Firebase Firestore에서 사용자의 모든 반응 로드
    try {
      if (kDebugMode) {
        print('Loading reactions from server...');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading reactions: $e');
      }
    }
  }
}
