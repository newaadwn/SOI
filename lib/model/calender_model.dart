import 'package:cloud_firestore/cloud_firestore.dart';

// CalenderModel 클래스는 Firebase Firestore와의 데이터 변환을 담당
class CalenderModel {
  final String id; // 사진의 고유 ID
  final String imageUrl; // Firebase Storage에서 가져온 이미지 URL
  final DateTime date; // 사진이 찍힌 날짜

  CalenderModel({required this.id, required this.imageUrl, required this.date});

  // PhotoModel 객체를 Firestore에 저장 가능한 형태(Map)로 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'date': date,
    };
  }

  // fromDocument는 Firestore의 DocumentSnapshot을 직접 PhotoModel 객체로 변환하는 메서드입니다.
  // Firestore에서 데이터를 가져올 때 사용되며, null 처리가 되어있어 더 안전합니다.
  // DocumentSnapshot에는 문서 ID 등 추가 메타데이터도 포함되어 있습니다.
  factory CalenderModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalenderModel(
      id: data['id'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
    );
  }
}
