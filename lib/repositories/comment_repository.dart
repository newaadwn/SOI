import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/comment_data_model.dart';

/// Firebase에서 comment 관련 데이터를 가져오고, 저장하고, 업데이트하고 삭제하는 등의 로직들
class CommentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  // ==================== 권한 관리 ====================

  /// 마이크 권한 요청
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status == PermissionStatus.granted;
  }

  // ==================== 녹음 관리 ====================

  /// 레코더 초기화
  Future<void> initializeRecorder() async {
    await _recorder.openRecorder();
  }

  /// 레코더 종료
  Future<void> disposeRecorder() async {
    await _recorder.closeRecorder();
  }

  /// 녹음 시작
  Future<void> startRecording() async {
    final path = 'comment_audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(toFile: path);
  }

  /// 녹음 중지
  Future<String?> stopRecording() async {
    return await _recorder.stopRecorder();
  }

  /// 녹음 상태 확인
  bool get isRecording => _recorder.isRecording;

  /// 녹음 진행률 스트림
  Stream<RecordingDisposition>? get recordingStream => _recorder.onProgress;

  // ==================== 재생 관리 ====================

  /// 플레이어 초기화
  Future<void> initializePlayer() async {
    await _player.openPlayer();
  }

  /// 플레이어 종료
  Future<void> disposePlayer() async {
    await _player.closePlayer();
  }

  /// 오디오 재생 (URL)
  Future<void> playFromUrl(String url) async {
    await _player.startPlayer(fromURI: url);
  }

  /// 재생 중지
  Future<void> stopPlaying() async {
    await _player.stopPlayer();
  }

  /// 재생 상태 확인
  bool get isPlaying => _player.isPlaying;

  /// 재생 진행률 스트림
  Stream<PlaybackDisposition>? get playbackStream => _player.onProgress;

  // ==================== 파일 관리 ====================

  /// 파일 크기 계산 (MB 단위)
  Future<double> getFileSize(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0.0;

    final bytes = await file.length();
    return bytes / (1024 * 1024); // MB로 변환
  }

  /// 오디오 파일 길이 계산 (초 단위)
  Future<int> getAudioDuration(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    // 임시적으로 파일 크기 기반 추정 (실제로는 더 정확한 방법 필요)
    final sizeInMB = await getFileSize(filePath);
    return (sizeInMB * 60).round(); // 대략적인 추정
  }

  /// 임시 파일 삭제
  Future<void> deleteLocalFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  // ==================== Firestore 관리 ====================

  /// 댓글 데이터 저장
  Future<String> saveComment(CommentDataModel comment) async {
    final docRef = await _firestore
        .collection('comments')
        .add(comment.toFirestore());
    return docRef.id;
  }

  /// 댓글 데이터 업데이트
  Future<void> updateComment(
    String commentId,
    Map<String, dynamic> data,
  ) async {
    await _firestore.collection('comments').doc(commentId).update(data);
  }

  /// 댓글 데이터 삭제 (소프트 삭제)
  Future<void> deleteComment(String commentId) async {
    await _firestore.collection('comments').doc(commentId).update({
      'status': CommentStatus.deleted.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 댓글 데이터 완전 삭제
  Future<void> hardDeleteComment(String commentId) async {
    await _firestore.collection('comments').doc(commentId).delete();
  }

  /// 특정 댓글 데이터 조회
  Future<CommentDataModel?> getComment(String commentId) async {
    final doc = await _firestore.collection('comments').doc(commentId).get();

    if (!doc.exists || doc.data() == null) return null;

    return CommentDataModel.fromFirestore(doc.data()!, doc.id);
  }

  /// 사진별 댓글 목록 조회
  Future<List<CommentDataModel>> getCommentsByPhoto(
    String categoryId,
    String photoId,
  ) async {
    final querySnapshot =
        await _firestore
            .collection('comments')
            .where('categoryId', isEqualTo: categoryId)
            .where('photoId', isEqualTo: photoId)
            .where('status', isEqualTo: CommentStatus.active.name)
            .orderBy('createdAt', descending: false)
            .get();

    return querySnapshot.docs
        .map((doc) => CommentDataModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// 사용자별 댓글 목록 조회
  Future<List<CommentDataModel>> getCommentsByUser(String userId) async {
    final querySnapshot =
        await _firestore
            .collection('comments')
            .where('userId', isEqualTo: userId)
            .where(
              'status',
              whereIn: [CommentStatus.active.name, CommentStatus.hidden.name],
            )
            .orderBy('createdAt', descending: true)
            .get();

    return querySnapshot.docs
        .map((doc) => CommentDataModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  /// 사진별 댓글 스트림
  Stream<List<CommentDataModel>> getCommentsByPhotoStream(
    String categoryId,
    String photoId,
  ) {
    return _firestore
        .collection('comments')
        .where('categoryId', isEqualTo: categoryId)
        .where('photoId', isEqualTo: photoId)
        .where('status', isEqualTo: CommentStatus.active.name)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => CommentDataModel.fromFirestore(doc.data(), doc.id),
                  )
                  .toList(),
        );
  }

  /// 댓글 좋아요 추가
  Future<void> addLike(String commentId, String userId) async {
    await _firestore.collection('comments').doc(commentId).update({
      'likedBy': FieldValue.arrayUnion([userId]),
      'likeCount': FieldValue.increment(1),
    });
  }

  /// 댓글 좋아요 제거
  Future<void> removeLike(String commentId, String userId) async {
    await _firestore.collection('comments').doc(commentId).update({
      'likedBy': FieldValue.arrayRemove([userId]),
      'likeCount': FieldValue.increment(-1),
    });
  }

  /// 댓글 신고
  Future<void> reportComment(
    String commentId,
    String reporterId,
    String reason,
  ) async {
    // 신고 컬렉션에 저장
    await _firestore.collection('reports').add({
      'commentId': commentId,
      'reporterId': reporterId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    // 댓글 상태를 신고됨으로 변경
    await _firestore.collection('comments').doc(commentId).update({
      'status': CommentStatus.reported.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 사진의 닉네임 조회 (기존 호환성)
  Future<String> getNickNameFromPhoto(String categoryId, String photoId) async {
    try {
      final doc =
          await _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('photos')
              .doc(photoId)
              .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!['nickName'] ?? '';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // ==================== Firebase Storage 관리 ====================

  /// 오디오 파일 업로드
  Future<String> uploadAudioFile(String filePath, String nickName) async {
    final file = File(filePath);
    final fileName =
        'comment_${nickName}_${DateTime.now().millisecondsSinceEpoch}.aac';
    final ref = _storage
        .ref()
        .child('comments')
        .child(nickName)
        .child(fileName);

    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask.whenComplete(() => null);

    return await snapshot.ref.getDownloadURL();
  }

  /// 오디오 파일 삭제
  Future<void> deleteAudioFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      print('오디오 파일 삭제 실패: $e');
    }
  }

  /// 업로드 진행률 스트림
  Stream<TaskSnapshot> getUploadProgressStream(
    String filePath,
    String nickName,
  ) {
    final file = File(filePath);
    final fileName =
        'comment_${nickName}_${DateTime.now().millisecondsSinceEpoch}.aac';
    final ref = _storage
        .ref()
        .child('comments')
        .child(nickName)
        .child(fileName);

    return ref.putFile(file).snapshotEvents;
  }
}
