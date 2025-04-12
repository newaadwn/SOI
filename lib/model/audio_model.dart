import 'package:cloud_firestore/cloud_firestore.dart';

class AudioModel {
  final String id; // 음성 파일의 고유 ID
  final String audioUrl; // Firebase Storage에 저장된 음성 파일의 URL
  final FieldValue createdAt; // 음성 파일이 생성된 시간
  final String userNickname; // 음성 파일을 업로드한 사용자의 닉네임
  final List<String> userIds; // 음성 파일과 관련된 사용자 ID 목록
  final String userId; // 음성 파일을 업로드한 사용자의 ID

  AudioModel({
    required this.id,
    required this.audioUrl,
    required this.createdAt,
    required this.userNickname,
    required this.userIds,
    required this.userId,
  });

  // Firestore에 저장할 수 있도록 객체를 맵으로 변환하는 메서드
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'audioUrl': audioUrl,
      'createdAt': createdAt,
      'userNickname': userNickname,
      'userIds': userIds,
      'userId': userId,
    };
  }

  // Firestore 문서에서 객체를 생성하는 팩토리 메서드
  factory AudioModel.fromDocument(DocumentSnapshot doc) {
    return AudioModel(
      id: doc['id'],
      audioUrl: doc['audioUrl'],
      createdAt: doc['createdAt'],
      userNickname: doc['userNickname'],
      userIds: List<String>.from(doc['userIds']),
      userId: doc['userId'],
    );
  }
}
