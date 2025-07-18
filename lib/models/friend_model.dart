import 'package:cloud_firestore/cloud_firestore.dart';

/// 친구 상태를 나타내는 enum
enum FriendStatus {
  active, // 활성 상태
  blocked, // 차단됨
}

/// 친구 상태 확장 메서드
extension FriendStatusExtension on FriendStatus {
  /// enum을 문자열로 변환
  String get value {
    switch (this) {
      case FriendStatus.active:
        return 'active';
      case FriendStatus.blocked:
        return 'blocked';
    }
  }

  /// 문자열에서 enum으로 변환
  static FriendStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return FriendStatus.active;
      case 'blocked':
        return FriendStatus.blocked;
      default:
        return FriendStatus.active;
    }
  }

  /// 상태에 따른 표시 텍스트
  String get displayText {
    switch (this) {
      case FriendStatus.active:
        return '활성';
      case FriendStatus.blocked:
        return '차단됨';
    }
  }
}

/// 친구 정보 데이터 모델
class FriendModel {
  /// 친구의 사용자 UID
  final String userId;

  /// 친구의 닉네임
  final String nickname;

  /// 친구의 실명
  final String name;

  /// 친구의 프로필 이미지 URL
  final String? profileImageUrl;

  /// 친구 상태
  final FriendStatus status;

  /// 즐겨찾기 여부
  final bool isFavorite;

  /// 친구 추가된 시간
  final DateTime addedAt;

  /// 마지막 상호작용 시간
  final DateTime? lastInteraction;

  const FriendModel({
    required this.userId,
    required this.nickname,
    required this.name,
    this.profileImageUrl,
    required this.status,
    required this.isFavorite,
    required this.addedAt,
    this.lastInteraction,
  });

  /// Firestore 문서에서 모델 생성
  factory FriendModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw Exception('Document data is null');
    }

    return FriendModel.fromJson(data);
  }

  /// JSON에서 모델 생성
  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      userId: json['userId'] as String,
      nickname: json['nickname'] as String,
      name: json['name'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      status: FriendStatusExtension.fromString(json['status'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
      addedAt: (json['addedAt'] as Timestamp).toDate(),
      lastInteraction:
          json['lastInteraction'] != null
              ? (json['lastInteraction'] as Timestamp).toDate()
              : null,
    );
  }

  /// 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'status': status.value,
      'isFavorite': isFavorite,
      'addedAt': Timestamp.fromDate(addedAt),
      'lastInteraction':
          lastInteraction != null ? Timestamp.fromDate(lastInteraction!) : null,
    };
  }

  /// 모델 복사 (일부 필드 변경)
  FriendModel copyWith({
    String? userId,
    String? nickname,
    String? name,
    String? profileImageUrl,
    FriendStatus? status,
    bool? isFavorite,
    DateTime? addedAt,
    DateTime? lastInteraction,
  }) {
    return FriendModel(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      addedAt: addedAt ?? this.addedAt,
      lastInteraction: lastInteraction ?? this.lastInteraction,
    );
  }

  /// 동등성 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FriendModel &&
        other.userId == userId &&
        other.nickname == nickname &&
        other.name == name &&
        other.profileImageUrl == profileImageUrl &&
        other.status == status &&
        other.isFavorite == isFavorite &&
        other.addedAt == addedAt &&
        other.lastInteraction == lastInteraction;
  }

  /// 해시코드
  @override
  int get hashCode {
    return userId.hashCode ^
        nickname.hashCode ^
        name.hashCode ^
        profileImageUrl.hashCode ^
        status.hashCode ^
        isFavorite.hashCode ^
        addedAt.hashCode ^
        lastInteraction.hashCode;
  }

  /// 디버그용 문자열 표현
  @override
  String toString() {
    return 'FriendModel(userId: $userId, nickname: $nickname, name: $name, profileImageUrl: $profileImageUrl, status: $status, isFavorite: $isFavorite, addedAt: $addedAt, lastInteraction: $lastInteraction)';
  }
}
