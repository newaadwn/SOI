import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// 음성 댓글(녹음/업로드) 기능을 담당하는 모델 클래스
class CommentModel {
  /// FlutterSoundRecorder 인스턴스 (오디오 녹음을 담당)
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  /// Firestore 인스턴스
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// FlutterSoundRecorder 세션을 열고 마이크 권한을 요청
  Future<void> openRecorder() async {
    await Permission.microphone.request(); // 마이크 권한 요청
    await _recorder.openRecorder(); // 오디오 세션 열기
  }

  /// 녹음을 시작하고, 녹음 상태를 업데이트
  Future<void> startRecording() async {
    final String path =
        'audio_${DateTime.now().millisecondsSinceEpoch}.aac'; // 파일 경로 설정
    await _recorder.startRecorder(toFile: path); // 녹음 시작
  }

  /// 녹음을 중지 후, 파일 경로를 반환
  Future<String?> stopRecording() async {
    final String? path = await _recorder.stopRecorder(); // 녹음 중지
    return path;
  }

  /// 녹음한 파일을 Firebase Storage에 업로드 후, 해당 파일의 다운로드 URL 반환
  Future<String?> uploadAudioToFirestorage(
    String audioFilePath,
    String nickName,
  ) async {
    if (audioFilePath.isEmpty) {
      debugPrint('No audio file to upload');
      return null;
    }

    // 파일명에 사용자 닉네임과 현재 시각의 초 단위를 포함
    final fileName = "${nickName}_comment_${DateTime.now().second}";
    final file = File(audioFilePath);

    // 로컬 파일이 존재하는지 확인
    if (!file.existsSync()) {
      debugPrint('File does not exist: $audioFilePath');
      return null;
    }

    try {
      // Firebase Storage에 업로드
      final ref = FirebaseStorage.instance.ref().child(
        'categories_comments_audio/$fileName',
      );
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading audio: $e');
      return null;
    }
  }

  /// 특정 사진 문서 아래 [comments] 컬렉션에 댓글 정보(오디오 URL 등)를 업로드
  Future<bool> uploadCommentToFirestore(
    String categoryId,
    String photoId,
    String nickName,
    String audioUrl,
    String userId,
  ) async {
    try {
      final photoRef = _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId);

      // Firestore에 댓글 정보 저장
      await photoRef.collection('comments').doc(nickName).set({
        'createdAt': Timestamp.now(),
        'userNickname': nickName,
        'audioUrl': audioUrl,
        'userId': userId,
      });

      return true;
    } catch (e) {
      debugPrint('Error uploading comment: $e');
      return false;
    }
  }

  /// Firestore에서 [userNickname] 필드를 가져오는 함수
  /// (여러 문서가 있을 경우, 첫 문서의 'userNickname'만 가져온다)
  Future<String> getNickNameFromFirestore(
    String categoryId,
    String photoId,
  ) async {
    try {
      final categoryDoc = _firestore.collection('categories').doc(categoryId);
      final comments = categoryDoc
          .collection('photos')
          .doc(photoId)
          .collection('comments');
      final documentSnapshot = await comments.get();

      if (documentSnapshot.docs.isNotEmpty) {
        // 첫 문서의 userNickname 필드만 가져온다
        String? fetchedNickName;
        for (var doc in documentSnapshot.docs) {
          fetchedNickName = doc.get('userNickname');
          break;
        }
        debugPrint('Fetched Nickname: $fetchedNickName');
        return fetchedNickName ?? 'Default Nickname';
      } else {
        debugPrint('Document does not exist');
        return 'Default Nickname';
      }
    } catch (e) {
      debugPrint('Error fetching document: $e');
      return 'Default Nickname';
    }
  }

  /// 모든 댓글 가져오기
  Stream<List<Map<String, dynamic>>> fetchComments(
    String categoryId,
    String photoId,
  ) {
    try {
      final commentsStream =
          _firestore
              .collection('categories')
              .doc(categoryId)
              .collection('photos')
              .doc(photoId)
              .collection('comments')
              .orderBy('createdAt', descending: true)
              .snapshots();

      return commentsStream.map(
        (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
      );
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      // 오류 발생 시 빈 스트림 반환
      return Stream.value([]);
    }
  }

  /// 레코더 해제
  Future<void> closeRecorder() async {
    await _recorder.closeRecorder();
  }

  /// 현재 녹음 중인지 여부 반환
  bool get isRecording => _recorder.isRecording;
}
