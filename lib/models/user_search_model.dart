import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 검색 결과 데이터 모델
class UserSearchModel {
  /// 사용자 UID
  final String uid;

  /// 사용자 닉네임
  final String nickname;

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
    required this.nickname,
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
      nickname: json['nickname'] as String? ?? json['name'] as String? ?? '', // nickname이 없으면 name 사용
      name: json['name'] as String? ?? '',
      profileImageUrl: json['profileImageUrl'] as String? ?? json['profile_image'] as String?, // profile_image 필드도 확인
      phoneNumber: json['phone'] as String?, // 'phoneNumber' → 'phone'으로 변경
      allowPhoneSearch: json['allowPhoneSearch'] as bool? ?? true,
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  /// 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'phone': phoneNumber, // 'phoneNumber' → 'phone'으로 변경
      'allowPhoneSearch': allowPhoneSearch,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// 모델 복사 (일부 필드 변경)
  UserSearchModel copyWith({
    String? uid,
    String? nickname,
    String? name,
    String? profileImageUrl,
    String? phoneNumber,
    bool? allowPhoneSearch,
    DateTime? createdAt,
  }) {
    return UserSearchModel(
      uid: uid ?? this.uid,
      nickname: nickname ?? this.nickname,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      allowPhoneSearch: allowPhoneSearch ?? this.allowPhoneSearch,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 동등성 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserSearchModel &&
        other.uid == uid &&
        other.nickname == nickname &&
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
        nickname.hashCode ^
        name.hashCode ^
        profileImageUrl.hashCode ^
        phoneNumber.hashCode ^
        allowPhoneSearch.hashCode ^
        createdAt.hashCode;
  }

  /// 디버그용 문자열 표현
  @override
  String toString() {
    return 'UserSearchModel(uid: $uid, nickname: $nickname, name: $name, profileImageUrl: $profileImageUrl, phoneNumber: $phoneNumber, allowPhoneSearch: $allowPhoneSearch, createdAt: $createdAt)';
  }
}
