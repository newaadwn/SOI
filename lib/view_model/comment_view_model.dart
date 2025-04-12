import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_swift_camera/view_model/auth_view_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

/// 음성 댓글(녹음/업로드) 기능을 담당하는 ViewModel.
class CommentAudioViewModel extends ChangeNotifier {
  /// FlutterSoundRecorder 인스턴스 (오디오 녹음을 담당).
  FlutterSoundRecorder? _recorder;

  /// 현재 녹음 진행 여부.
  bool _isRecording = false;

  /// 임시로 저장된 녹음 파일의 경로.
  String? _audioFilePath;

  /// Firestore 인스턴스.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 생성자: [_recorder] 초기화 및 오디오 세션 열기.
  CommentAudioViewModel() {
    _recorder = FlutterSoundRecorder();
    _openRecorder();
  }

  // ---------------------------------------------------------------------------
  // 녹음 제어 관련 메서드
  // ---------------------------------------------------------------------------

  /// FlutterSoundRecorder 세션을 열고 마이크 권한을 요청.
  Future<void> _openRecorder() async {
    await Permission.microphone.request(); // 마이크 권한 요청
    await _recorder!.openRecorder(); // 오디오 세션 열기
  }

  /// 녹음을 시작하고, 녹음 상태를 업데이트.
  Future<void> startRecording() async {
    final String path =
        'audio_${DateTime.now().millisecondsSinceEpoch}.aac'; // 파일 경로 설정
    await _recorder!.startRecorder(toFile: path); // 녹음 시작
    _isRecording = true; // 녹음 상태 변경
    notifyListeners();
  }

  /// 녹음을 중지 후, 파일 경로를 [_audioFilePath]에 저장.
  Future<void> stopRecording() async {
    final String? path = await _recorder!.stopRecorder(); // 녹음 중지
    _isRecording = false; // 녹음 상태 변경

    if (path != null) {
      _audioFilePath = path; // 저장된 파일 경로
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Firebase 업로드 및 Firestore 업데이트 관련 메서드
  // ---------------------------------------------------------------------------

  /// 녹음한 파일을 Firebase Storage에 업로드 후, 해당 파일의 다운로드 URL 반환.
  Future<String> uploadAudioToFirestorage(
    String categoryId,
    String nickName,
  ) async {
    if (_audioFilePath == null) {
      throw Exception('No audio file to upload');
    }

    // 파일명에 사용자 닉네임과 현재 시각의 초 단위를 포함.
    final fileName = "${nickName}_comment_${DateTime.now().second}";
    final file = File(_audioFilePath!);

    // 로컬 파일이 존재하는지 확인.
    if (!file.existsSync()) {
      print('File does not exist: $_audioFilePath');
      return '파일이 없습니다.';
    }

    // Firebase Storage에 업로드.
    final ref = FirebaseStorage.instance.ref().child(
      'categories_comments_audio/$fileName',
    );
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// 특정 사진 문서 아래 [comments] 컬렉션에 댓글 정보(오디오 URL 등)를 업로드.
  Future<void> uploadAudio(
    String categoryId,
    String photoId,
    String nickName,
    String audioUrl,
    BuildContext context,
  ) async {
    try {
      final photoRef = _firestore
          .collection('categories')
          .doc(categoryId)
          .collection('photos')
          .doc(photoId);

      // Firestore에 댓글 정보 저장.
      await photoRef.collection('comments').doc(nickName).set({
        'createdAt': Timestamp.now(),
        'userNickname': nickName,
        'audioUrl': audioUrl,
        'userId': Provider.of<AuthViewModel>(context, listen: false).getUserId,
      });

      notifyListeners();
    } catch (e) {
      print('Error uploading comment: $e');
      rethrow;
    }
  }

  /// Firestore에서 [nick_name] 필드를 가져오는 예시 함수.
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
        // 첫 문서의 userNickname 필드만 가져온다.
        String? fetchedNickName;
        for (var doc in documentSnapshot.docs) {
          fetchedNickName = doc.get('userNickname');
          break;
        }
        print('Fetched Nickname: $fetchedNickName');
        return fetchedNickName ?? 'Default Nickname';
      } else {
        print('Document does not exist');
        return 'Default Nickname';
      }
    } catch (e) {
      print('Error fetching document: $e');
      rethrow;
    }
  }

  /// Fetch all comments for a specific photo as a stream
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
      print('Error fetching comments: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Getter & Override
  // ---------------------------------------------------------------------------

  /// 현재 녹음 중인지 여부 반환
  bool get isRecording => _isRecording;

  /// 임시로 저장된 녹음 파일 경로 반환
  String? get audioFilePath => _audioFilePath;

  /// 사용이 끝나면 오디오 리소스를 정리.
  @override
  void dispose() {
    _recorder?.closeRecorder(); // 오디오 세션 닫기 (null-safe)
    _recorder = null; // FlutterSoundRecorder 인스턴스 해제
    super.dispose();
  }
}
