import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoModel {
  final String imageUrl;
  final Timestamp createdAt;
  final String userNickname;
  final List<String> userIds;
  final String userId;
  final String audioUrl; // 음성 녹음 URL 필드 추가
  final String id;
  //final String captionString;

  PhotoModel({
    required this.imageUrl,
    required this.createdAt,
    required this.userNickname,
    required this.userIds,
    required this.userId,
    required this.audioUrl, // 선택적 필드로 추가
    required this.id,
    //required this.captionString,
  });

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'userNickname': userNickname,
      'userIds': userIds,
      'userId': userId,
      'audioUrl': audioUrl, // 맵에 추가
      //'captionString': captionString,
    };
  }

  factory PhotoModel.fromDocument(DocumentSnapshot doc) {
    return PhotoModel(
      imageUrl: doc['imageUrl'],
      createdAt: doc['createdAt'],
      userNickname: doc['userNickname'],
      userIds: List<String>.from(doc['userIds']),
      userId: doc['userId'],
      audioUrl: doc['audioUrl'], // 문서에서 필드 가져오기
      id: doc.id,
      //captionString: doc['captionString'],
    );
  }

  String get getPhotoId => id;
}
