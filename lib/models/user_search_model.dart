import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 검색 결과 데이터 모델
class UserSearchModel {
  /// 사용자 UID
  final String uid;

  /// 사용자 id
  final String id;

  /// 사용자 실명
  final String name;

  /// 사용자 프로필 이미지 URL
  final String? profileImageUrl;

  /// 전화번호 (해시화된 값)
  final String? phoneNumber;

  /// 전화번호 검색 허용 여부
  final bool allowPhoneSearch;

  /// 계정 생성일
  final DateTime createdAt;

  const UserSearchModel({
    required this.uid,
    required this.id,
    required this.name,
    this.profileImageUrl,
    this.phoneNumber,
    required this.allowPhoneSearch,
    required this.createdAt,
  });

  /// Firestore 문서에서 모델 생성
  factory UserSearchModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw Exception('Document data is null');
    }

    return UserSearchModel.fromJson(data, doc.id);
  }

  /// JSON에서 모델 생성
  factory UserSearchModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserSearchModel(
      uid: uid,
      id:
          json['id'] as String? ??
          json['name'] as String? ??
          '', // id이 없으면 name 사용
      name: json['name'] as String? ?? '',
      profileImageUrl:
          json['profileImageUrl'] as String? ??
          json['profile_image'] as String?, // profile_image 필드도 확인
      phoneNumber: json['phone'] as String?, // 'phoneNumber' → 'phone'으로 변경
      allowPhoneSearch: json['allowPhoneSearch'] as bool? ?? true,
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  /// 동등성 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserSearchModel &&
        other.uid == uid &&
        other.id == id &&
        other.name == name &&
        other.profileImageUrl == profileImageUrl &&
        other.phoneNumber == phoneNumber &&
        other.allowPhoneSearch == allowPhoneSearch &&
        other.createdAt == createdAt;
  }

  /// 해시코드
  @override
  int get hashCode {
    return uid.hashCode ^
        id.hashCode ^
        name.hashCode ^
        profileImageUrl.hashCode ^
        phoneNumber.hashCode ^
        allowPhoneSearch.hashCode ^
        createdAt.hashCode;
  }
}
