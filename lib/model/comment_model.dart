import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final Timestamp createdAt;
  final String userNickname;
  final String userId;
  final String audioUrl; // 음성 녹음 URL 필드 추가

  CommentModel({
    required this.createdAt,
    required this.userNickname,
    required this.userId,
    required this.audioUrl, // 선택적 필드로 추가
  });

  Map<String, dynamic> toMap() {
    return {
      'createdAt': createdAt,
      'userNickname': userNickname,
      'userId': userId,
      'audioUrl': audioUrl, // 맵에 추가
    };
  }

  factory CommentModel.fromDocument(DocumentSnapshot doc) {
    return CommentModel(
      createdAt: doc['createdAt'],
      userNickname: doc['userNickname'],

      userId: doc['userId'],
      audioUrl: doc['audioUrl'], // 문서에서 필드 가져오기
    );
  }
}
