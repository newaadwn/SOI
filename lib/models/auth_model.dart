import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 데이터 모델 (순수 데이터 클래스)
class AuthModel {
  final String uid;
  final String id;
  final String name;
  final String phone;
  final String birthDate;
  final String profileImage;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isDeactivated; // 계정 비활성화 상태

  AuthModel({
    required this.uid,
    required this.id,
    required this.name,
    required this.phone,
    required this.birthDate,
    this.profileImage = '',
    required this.createdAt,
    required this.lastLogin,
    this.isDeactivated = false, // 기본값 false
  });

  /// Firestore 문서에서 UserModel 생성
  factory AuthModel.fromFirestore(Map<String, dynamic> data) {
    return AuthModel(
      uid: data['uid'] ?? '',
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      birthDate: data['birth_date'] ?? '',
      profileImage: data['profile_image'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLogin: (data['lastLogin'] as Timestamp).toDate(),
      isDeactivated: data['isDeactivated'] ?? false, // 비활성화 상태 추가
    );
  }

  /// 서버 타임스탬프를 사용하여 Firestore에 저장할 Map 변환
  Map<String, dynamic> toFirestoreWithServerTimestamp({bool isUpdate = false}) {
    final data = {
      'uid': uid,
      'id': id,
      'name': name,
      'phone': phone,
      'birth_date': birthDate,
      'profile_image': profileImage,
      'lastLogin': FieldValue.serverTimestamp(),
      'isDeactivated': isDeactivated, // 비활성화 상태 추가
    };

    if (!isUpdate) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    return data;
  }
}
