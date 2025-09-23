import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/comment_record_controller.dart';
import '../../../models/comment_record_model.dart';
import '../../../utils/position_converter.dart';

/// 보류 중인 음성 댓글 정보를 담는 단순 데이터 객체
class PendingVoiceComment {
  final String audioPath;
  final List<double> waveformData;
  final int duration;
  final Offset? relativePosition;

  const PendingVoiceComment({
    required this.audioPath,
    required this.waveformData,
    required this.duration,
    this.relativePosition,
  });

  PendingVoiceComment withPosition(Offset? position) {
    return PendingVoiceComment(
      audioPath: audioPath,
      waveformData: waveformData,
      duration: duration,
      relativePosition: position,
    );
  }
}

class VoiceCommentStateManager {
  // 음성 댓글 상태 관리 (다중 댓글 지원)
  final Map<String, bool> _voiceCommentActiveStates = {};
  final Map<String, bool> _voiceCommentSavedStates = {};
  final Map<String, List<String>> _savedCommentIds = {}; // 사진별 여러 댓글 ID 저장

  // 임시 음성 댓글 데이터 (파형 클릭 시 저장용)
  final Map<String, PendingVoiceComment> _pendingVoiceComments = {};

  // 프로필 이미지 관리 (다중 댓글 지원)
  final Map<String, Offset?> _profileImagePositions = {}; // 임시 위치용 (기존 호환성)
  final Map<String, String> _commentProfileImageUrls = {}; // 임시용 (기존 호환성)
  final Map<String, String> _droppedProfileImageUrls = {}; // 임시용 (기존 호환성)

  // 댓글별 개별 관리 (새로운 구조)
  // 기존에는 댓글 ID 위치를 별도 관리했으나, 주입되는 CommentRecordModel의
  // relativePosition을 그대로 사용하므로 별도 맵을 유지할 필요가 없다.

  // 실시간 스트림 관리
  final Map<String, List<CommentRecordModel>> _photoComments = {};
  final Map<String, StreamSubscription<List<CommentRecordModel>>>
  _commentStreams = {};

  // Getters
  Map<String, bool> get voiceCommentActiveStates => _voiceCommentActiveStates;
  Map<String, bool> get voiceCommentSavedStates => _voiceCommentSavedStates;
  Map<String, List<String>> get savedCommentIds => _savedCommentIds;
  Map<String, Offset?> get profileImagePositions => _profileImagePositions;
  Map<String, String> get commentProfileImageUrls => _commentProfileImageUrls;
  Map<String, String> get droppedProfileImageUrls => _droppedProfileImageUrls;
  Map<String, List<CommentRecordModel>> get photoComments => _photoComments;

  // 콜백 함수들
  VoidCallback? _onStateChanged;

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
  }

  /// 음성 댓글 토글
  void toggleVoiceComment(String photoId) {
    _voiceCommentActiveStates[photoId] =
        !(_voiceCommentActiveStates[photoId] ?? false);
    _notifyStateChanged();
  }

  /// 음성 댓글 녹음 완료 콜백 (임시 저장)
  Future<void> onVoiceCommentCompleted(
    String photoId,
    String? audioPath,
    List<double>? waveformData,
    int? duration,
  ) async {
    if (audioPath == null || waveformData == null || duration == null) {
      return;
    }

    // 임시 저장 (파형 클릭 시 실제 저장)
    _pendingVoiceComments[photoId] = PendingVoiceComment(
      audioPath: audioPath,
      waveformData: waveformData,
      duration: duration,
    );
    _notifyStateChanged();
  }

  /// 실제 음성 댓글 저장 (파형 클릭 시 호출)
  Future<void> saveVoiceComment(String photoId, BuildContext context) async {
    final pendingComment = _pendingVoiceComments[photoId];
    if (pendingComment == null) {
      return;
    }

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final commentRecordController = CommentRecordController();
      final currentUserId = authController.getUserId;

      if (currentUserId == null || currentUserId.isEmpty) {
        throw Exception('로그인된 사용자를 찾을 수 없습니다.');
      }

      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(currentUserId);

      // 현재 드래그된 위치를 사용 (각 댓글마다 고유한 위치)
      final currentProfilePosition =
          _profileImagePositions[photoId] ?? pendingComment.relativePosition;

      if (currentProfilePosition == null) {
        debugPrint('음성 댓글 저장 위치를 찾을 수 없습니다. photoId: $photoId');
        return;
      }

      final commentRecord = await commentRecordController.createCommentRecord(
        audioFilePath: pendingComment.audioPath,
        photoId: photoId,
        recorderUser: currentUserId,
        waveformData: pendingComment.waveformData,
        duration: pendingComment.duration,
        profileImageUrl: profileImageUrl,
        relativePosition: currentProfilePosition,
      );

      if (commentRecord != null) {
        _voiceCommentSavedStates[photoId] = true;

        // 다중 댓글 지원: 기존 댓글 목록에 새 댓글 추가 (중복 방지)
        if (_savedCommentIds[photoId] == null) {
          _savedCommentIds[photoId] = [commentRecord.id];
        } else {
          // 중복 확인 후 추가
          if (!_savedCommentIds[photoId]!.contains(commentRecord.id)) {
            _savedCommentIds[photoId]!.add(commentRecord.id);
          }
        }

        // 임시 데이터 삭제
        _pendingVoiceComments.remove(photoId);

        // 다음 댓글을 위해 위치 초기화 (기존 댓글은 건드리지 않음)
        _profileImagePositions[photoId] = null;

        _notifyStateChanged();
      } else {
        if (context.mounted) {
          commentRecordController.showErrorToUser(context);
        }
      }
    } catch (e) {
      debugPrint("음성 댓글 저장 중 오류 발생: $e");
    }
  }

  /// 음성 댓글 삭제 콜백
  void onVoiceCommentDeleted(String photoId) {
    _voiceCommentActiveStates[photoId] = false;
    _voiceCommentSavedStates[photoId] = false;
    _profileImagePositions[photoId] = null;
    _notifyStateChanged();
  }

  /// 음성 댓글 저장 완료 후 위젯 초기화 (추가 댓글을 위한)
  void onSaveCompleted(String photoId) {
    // 저장 완료 후 다시 버튼 상태로 돌아가서 추가 댓글 녹음 가능
    _voiceCommentActiveStates[photoId] = false;
    // _voiceCommentSavedStates는 건드리지 않음 (실제 댓글이 저장되어 있으므로)
    // 임시 데이터 정리
    _pendingVoiceComments.remove(photoId);
    _notifyStateChanged();
  }

  /// 프로필 이미지 드래그 처리 (절대 위치를 상대 위치로 변환하여 저장)
  void onProfileImageDragged(String photoId, Offset absolutePosition) {
    // 이미지 크기 (ScreenUtil 기준 - PhotoDisplayWidget과 동일하게)
    final imageSize = Size(354.w, 500.h);

    // 절대 위치를 상대 위치로 변환 (0.0 ~ 1.0 범위)
    final relativePosition = PositionConverter.toRelativePosition(
      absolutePosition,
      imageSize,
    );

    // UI에 즉시 반영 (임시 위치)
    _profileImagePositions[photoId] = relativePosition;
    final pendingComment = _pendingVoiceComments[photoId];
    if (pendingComment != null) {
      _pendingVoiceComments[photoId] = pendingComment.withPosition(
        relativePosition,
      );
      _notifyStateChanged();
      return; // 저장 전 위치만 갱신하고 종료
    }

    _notifyStateChanged();

    // 음성 댓글이 이미 저장된 경우에만 즉시 Firestore 업데이트
    if (_voiceCommentSavedStates[photoId] == true) {
      final commentIds = _savedCommentIds[photoId];
      if (commentIds != null && commentIds.isNotEmpty) {
        _updateProfilePositionInFirestore(
          photoId,
          relativePosition,
          commentIds.last,
        );
      }
    }
  }

  /// 특정 사진의 음성 댓글 정보를 실시간 구독하여 프로필 위치 동기화
  void subscribeToVoiceCommentsForPhoto(String photoId, String currentUserId) {
    try {
      _commentStreams[photoId]?.cancel();

      _commentStreams[photoId] = CommentRecordController()
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) =>
                _handleCommentsUpdate(photoId, currentUserId, comments),
          );

      // 실시간 스트림과 별개로 기존 댓글도 직접 로드
      _loadExistingCommentsForPhoto(photoId, currentUserId);
    } catch (e) {
      debugPrint('❌ Feed - 실시간 댓글 구독 시작 실패 - 사진 $photoId: $e');
    }
  }

  /// 특정 사진의 기존 댓글을 직접 로드 (실시간 스트림과 별개)
  Future<void> _loadExistingCommentsForPhoto(
    String photoId,
    String currentUserId,
  ) async {
    try {
      final commentController = CommentRecordController();
      await commentController.loadCommentRecordsByPhotoId(photoId);
      final comments = commentController.getCommentsByPhotoId(photoId);

      if (comments.isNotEmpty) {
        _handleCommentsUpdate(photoId, currentUserId, comments);
      }
    } catch (e) {
      debugPrint('❌ Feed - 기존 댓글 직접 로드 실패: $e');
    }
  }

  /// 댓글 업데이트 처리 (다중 댓글 지원)
  void _handleCommentsUpdate(
    String photoId,
    String currentUserId,
    List<CommentRecordModel> comments,
  ) {
    _photoComments[photoId] = comments;

    // 현재 사용자의 모든 댓글 처리 (다중 댓글 지원)
    final userComments =
        comments
            .where((comment) => comment.recorderUser == currentUserId)
            .toList();

    if (userComments.isNotEmpty) {
      // 사진별 댓글 ID 목록 업데이트 (중복 방지)
      final mergedIds = <String>[
        ...(_savedCommentIds[photoId] ?? const <String>[]),
        ...userComments.map((c) => c.id),
      ];

      _savedCommentIds[photoId] = mergedIds.toSet().toList();

      // 기존 호환성을 위해 마지막 댓글의 정보를 기존 변수에도 저장
      final lastComment = userComments.last;
      if (lastComment.profileImageUrl.isNotEmpty) {
        _commentProfileImageUrls[photoId] = lastComment.profileImageUrl;
      }

      if (lastComment.relativePosition != null) {
        // relativePosition 필드에서 상대 위치 데이터를 읽어옴
        Offset relativePosition;

        if (lastComment.relativePosition is Map<String, dynamic>) {
          // Map 형태의 상대 위치 데이터를 Offset으로 변환
          relativePosition = PositionConverter.mapToRelativePosition(
            lastComment.relativePosition as Map<String, dynamic>,
          );
        } else {
          // 이미 Offset 형태
          relativePosition = lastComment.relativePosition!;
        }

        _profileImagePositions[photoId] = relativePosition;
        _droppedProfileImageUrls[photoId] = lastComment.profileImageUrl;
      }
    } else {
      // 현재 사용자의 댓글이 없는 경우 상태 초기화
      _voiceCommentSavedStates[photoId] = false;
      _savedCommentIds.remove(photoId);
      _profileImagePositions[photoId] = null;
      _commentProfileImageUrls.remove(photoId);
      // 다른 사용자의 댓글은 유지하되 현재 사용자 관련 상태만 초기화
      if (comments.isEmpty) {
        _photoComments[photoId] = [];
      }
    }

    _notifyStateChanged();
  }

  /// Firestore에 프로필 위치 업데이트
  Future<void> _updateProfilePositionInFirestore(
    String photoId,
    Offset position,
    String targetCommentId,
  ) async {
    if (targetCommentId.isEmpty) {
      return;
    }

    try {
      final success = await CommentRecordController()
          .updateRelativeProfilePosition(
            commentId: targetCommentId,
            photoId: photoId,
            relativePosition: position,
          );

      if (success) {
        _profileImagePositions[photoId] = position;
        _notifyStateChanged();
      }
    } catch (e) {
      debugPrint('음성 댓글 위치 업데이트 실패: $e');
    }
  }

  /// 리소스 정리
  void dispose() {
    for (var subscription in _commentStreams.values) {
      subscription.cancel();
    }
    _commentStreams.clear();
  }
}
