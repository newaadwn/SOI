import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/comment_record_controller.dart';
import '../../../models/comment_record_model.dart';
import '../managers/feed_data_manager.dart';

/// 🎤 음성 댓글 관련 로직을 처리하는 핸들러 클래스
/// 음성 댓글 저장, 삭제, 위치 업데이트, 실시간 구독 등을 담당
class VoiceCommentHandler {
  /// 🎯 특정 사진의 음성 댓글 정보를 실시간 구독
  static void subscribeToVoiceCommentsForPhoto(
    String photoId,
    String currentUserId,
    FeedDataManager dataManager,
  ) {
    try {
      debugPrint('음성 댓글 실시간 구독 시작 - 사진: $photoId, 사용자: $currentUserId');

      // 기존 구독 취소
      dataManager.cancelCommentStream(photoId);

      // 새로운 구독 시작
      final subscription = CommentRecordController()
          .getCommentRecordsStream(photoId)
          .listen(
            (comments) => _handleCommentsUpdate(
              photoId,
              currentUserId,
              comments,
              dataManager,
            ),
            onError:
                (error) => debugPrint('실시간 댓글 구독 오류 - 사진 $photoId: $error'),
          );

      dataManager.addCommentStream(photoId, subscription);
    } catch (e) {
      debugPrint('❌ 실시간 댓글 구독 시작 실패 - 사진 $photoId: $e');
    }
  }

  /// 💾 음성 댓글 녹음 완료 처리
  static Future<void> handleVoiceCommentCompleted(
    BuildContext context,
    String photoId,
    String? audioPath,
    List<double>? waveformData,
    int? duration,
    FeedDataManager dataManager,
  ) async {
    if (audioPath == null || waveformData == null || duration == null) {
      debugPrint('❌ 음성 댓글 데이터가 유효하지 않습니다');
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

      debugPrint(
        '🎤 음성 댓글 저장 시작 - 사진: $photoId, 사용자: $currentUserId, 시간: ${duration}ms',
      );

      final profileImageUrl = await authController
          .getUserProfileImageUrlWithCache(currentUserId);
      final currentProfilePosition = dataManager.profileImagePositions[photoId];

      debugPrint('🔍 음성 댓글 저장 시 현재 프로필 위치: $currentProfilePosition');

      final commentRecord = await commentRecordController.createCommentRecord(
        audioFilePath: audioPath,
        photoId: photoId,
        recorderUser: currentUserId,
        waveformData: waveformData,
        duration: duration,
        profileImageUrl: profileImageUrl,
        profilePosition: currentProfilePosition,
      );

      if (commentRecord != null && context.mounted) {
        debugPrint('✅ 음성 댓글 저장 완료 - ID: ${commentRecord.id}');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('음성 댓글이 저장되었습니다'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        dataManager.setVoiceCommentSaved(photoId, true);
        dataManager.setSavedCommentId(photoId, commentRecord.id);

        debugPrint(
          '🎯 음성 댓글 ID 저장됨 - photoId: $photoId, commentId: ${commentRecord.id}',
        );

        // 댓글 저장 완료 후 대기 중인 프로필 위치가 있다면 업데이트
        final pendingPosition = dataManager.profileImagePositions[photoId];
        if (pendingPosition != null) {
          debugPrint('📍 댓글 저장 완료 후 대기 중인 프로필 위치 업데이트: $pendingPosition');
          Future.delayed(const Duration(milliseconds: 200), () {
            updateProfilePositionInFirestore(
              context,
              photoId,
              pendingPosition,
              dataManager,
            );
          });
        }
      } else if (context.mounted) {
        commentRecordController.showErrorToUser(context);
      }
    } catch (e) {
      debugPrint('❌ 음성 댓글 저장 실패: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('음성 댓글 저장 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 🗑️ 음성 댓글 삭제 처리
  static void handleVoiceCommentDeleted(
    String photoId,
    FeedDataManager dataManager,
  ) {
    dataManager.deleteVoiceComment(photoId);
    debugPrint('음성 댓글 삭제됨 - 사진 ID: $photoId');
  }

  /// 🖼️ 프로필 이미지 드래그 처리
  static void handleProfileImageDragged(
    BuildContext context,
    String photoId,
    Offset globalPosition,
    FeedDataManager dataManager,
  ) {
    debugPrint('🖼️ 프로필 이미지 드래그됨 - 사진: $photoId, 위치: $globalPosition');
    dataManager.updateProfileImagePosition(photoId, globalPosition);
    updateProfilePositionInFirestore(
      context,
      photoId,
      globalPosition,
      dataManager,
    );
  }

  /// 📍 Firestore에 프로필 위치 업데이트
  static Future<void> updateProfilePositionInFirestore(
    BuildContext context,
    String photoId,
    Offset position,
    FeedDataManager dataManager, {
    int retryCount = 0,
    int maxRetries = 3,
  }) async {
    try {
      debugPrint(
        '🔍 프로필 위치 업데이트 시작 - photoId: $photoId, position: $position, retry: $retryCount',
      );

      final isSaved = dataManager.voiceCommentSavedStates[photoId] == true;
      debugPrint('🔍 음성 댓글 저장 상태 확인: isSaved = $isSaved');

      if (!isSaved) {
        if (retryCount < maxRetries) {
          debugPrint(
            '⏳ 음성 댓글이 아직 저장되지 않음 - ${retryCount + 1}초 후 재시도 (${retryCount + 1}/$maxRetries)',
          );
          await Future.delayed(const Duration(seconds: 1));
          return updateProfilePositionInFirestore(
            context,
            photoId,
            position,
            dataManager,
            retryCount: retryCount + 1,
          );
        } else {
          debugPrint('⚠️ 최대 재시도 횟수 초과 - 위치 업데이트를 건너뜁니다');
          return;
        }
      }

      final commentRecordController = CommentRecordController();
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final currentUserId = authController.getUserId;

      if (currentUserId == null) {
        debugPrint('❌ 현재 사용자 ID를 찾을 수 없습니다');
        return;
      }

      debugPrint('🔍 현재 사용자 ID: $currentUserId');

      // 저장된 댓글 ID 확인 및 사용
      final savedCommentId = dataManager.savedCommentIds[photoId];
      debugPrint('🔍 저장된 댓글 ID: $savedCommentId');

      if (savedCommentId != null && savedCommentId.isNotEmpty) {
        debugPrint('🔍 저장된 댓글 ID로 직접 위치 업데이트 시작');
        final success = await commentRecordController.updateProfilePosition(
          commentId: savedCommentId,
          photoId: photoId,
          profilePosition: position,
        );
        debugPrint(
          success ? '✅ 프로필 위치가 Firestore에 저장되었습니다' : '❌ 프로필 위치 저장에 실패했습니다',
        );
        return;
      }

      // 저장된 댓글 ID가 없는 경우 재시도 또는 검색
      if (retryCount < maxRetries) {
        debugPrint(
          '🔄 저장된 댓글 ID가 없음 - ${retryCount + 1}초 후 재시도 (${retryCount + 1}/$maxRetries)',
        );
        await Future.delayed(const Duration(seconds: 1));
        return updateProfilePositionInFirestore(
          context,
          photoId,
          position,
          dataManager,
          retryCount: retryCount + 1,
        );
      }

      // 최종적으로 캐시/서버에서 댓글 찾기
      await _findAndUpdateCommentPosition(
        commentRecordController,
        photoId,
        currentUserId,
        position,
      );
    } catch (e) {
      debugPrint('❌ 프로필 위치 업데이트 중 오류 발생: $e');
    }
  }

  // ==================== Private Methods ====================

  /// 댓글 업데이트 처리
  static void _handleCommentsUpdate(
    String photoId,
    String currentUserId,
    List<CommentRecordModel> comments,
    FeedDataManager dataManager,
  ) {
    debugPrint(
      '[REALTIME] 실시간 댓글 업데이트 수신 - 사진: $photoId, 댓글 수: ${comments.length}',
    );

    // FeedDataManager의 일괄 업데이트 메서드 사용
    dataManager.handleCommentUpdate(photoId, currentUserId, comments);

    final userComment =
        comments
            .where((comment) => comment.recorderUser == currentUserId)
            .firstOrNull;

    if (userComment != null) {
      debugPrint('[REALTIME] 실시간 음성 댓글 업데이트 - ID: ${userComment.id}');
      debugPrint('[REALTIME] 프로필 위치 및 이미지 URL 업데이트 - photoId: $photoId');
    } else {
      debugPrint('🔍 실시간 업데이트: 사진 $photoId에 현재 사용자의 댓글 없음');
    }
  }

  /// 댓글을 찾아서 위치 업데이트
  static Future<void> _findAndUpdateCommentPosition(
    CommentRecordController commentRecordController,
    String photoId,
    String currentUserId,
    Offset position,
  ) async {
    debugPrint('🔍 저장된 댓글 ID가 없어 캐시/서버에서 검색 시작');

    var comments = commentRecordController.getCommentsByPhotoId(photoId);
    debugPrint('🔍 캐시에서 찾은 댓글 수: ${comments.length}');

    if (comments.isEmpty) {
      debugPrint('🔍 캐시가 비어있어 서버에서 음성 댓글 로드 시작 - photoId: $photoId');
      await commentRecordController.loadCommentRecordsByPhotoId(photoId);
      comments = commentRecordController.commentRecords;
      debugPrint('🔍 서버에서 로드된 댓글 수: ${comments.length}');
    }

    final userComment =
        comments
            .where((comment) => comment.recorderUser == currentUserId)
            .firstOrNull;
    debugPrint('🔍 현재 사용자의 댓글 찾기 결과: ${userComment?.id}');

    if (userComment != null) {
      debugPrint('🔍 프로필 위치 업데이트 호출 시작');
      final success = await commentRecordController.updateProfilePosition(
        commentId: userComment.id,
        photoId: photoId,
        profilePosition: position,
      );
      debugPrint(
        success ? '✅ 프로필 위치가 Firestore에 저장되었습니다' : '❌ 프로필 위치 저장에 실패했습니다',
      );
    } else {
      debugPrint('⚠️ 해당 사진에 대한 사용자의 음성 댓글을 찾을 수 없습니다');
    }
  }
}
