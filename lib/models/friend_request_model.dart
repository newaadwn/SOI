import 'package:cloud_firestore/cloud_firestore.dart';

/// 친구 요청 상태를 나타내는 enum
enum FriendRequestStatus {
  pending, // 대기 중
  accepted, // 수락됨
  rejected, // 거절됨
}

/// 친구 요청 상태 확장 메서드
extension FriendRequestStatusExtension on FriendRequestStatus {
  /// enum을 문자열로 변환
  String get value {
    switch (this) {
      case FriendRequestStatus.pending:
        return 'pending';
      case FriendRequestStatus.accepted:
        return 'accepted';
      case FriendRequestStatus.rejected:
        return 'rejected';
    }
  }

  /// 문자열에서 enum으로 변환
  static FriendRequestStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return FriendRequestStatus.pending;
      case 'accepted':
        return FriendRequestStatus.accepted;
      case 'rejected':
        return FriendRequestStatus.rejected;
      default:
        return FriendRequestStatus.pending;
    }
  }

  /// 상태에 따른 표시 텍스트
  String get displayText {
    switch (this) {
      case FriendRequestStatus.pending:
        return '대기 중';
      case FriendRequestStatus.accepted:
        return '수락됨';
      case FriendRequestStatus.rejected:
        return '거절됨';
    }
  }
}

/// 친구 요청 데이터 모델
class FriendRequestModel {
  /// 요청 문서 ID
  final String id;

  /// 요청을 보낸 사용자 UID
  final String senderUid;

  /// 요청을 받은 사용자 UID
  final String receiverUid;

  /// 요청을 보낸 사용자 닉네임
  final String senderNickname;

  /// 요청을 받은 사용자 닉네임
  final String receiverNickname;

  /// 요청 상태
  final FriendRequestStatus status;

  /// 요청 메시지 (선택사항)
  final String? message;

  /// 요청 생성 시간
  final DateTime createdAt;

  /// 마지막 업데이트 시간
  final DateTime? updatedAt;

  const FriendRequestModel({
    required this.id,
    required this.senderUid,
    required this.receiverUid,
    required this.senderNickname,
    required this.receiverNickname,
    required this.status,
    this.message,
    required this.createdAt,
    this.updatedAt,
  });

  /// Firestore 문서에서 모델 생성
  factory FriendRequestModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw Exception('Document data is null');
    }

    return FriendRequestModel.fromJson(data, doc.id);
  }

  /// JSON에서 모델 생성
  factory FriendRequestModel.fromJson(Map<String, dynamic> json, String id) {
    return FriendRequestModel(
      id: id,
      senderUid: json['senderUid'] as String,
      receiverUid: json['receiverUid'] as String,
      senderNickname: json['senderNickname'] as String,
      receiverNickname: json['receiverNickname'] as String,
      status: FriendRequestStatusExtension.fromString(json['status'] as String),
      message: json['message'] as String?,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt:
          json['updatedAt'] != null
              ? (json['updatedAt'] as Timestamp).toDate()
              : null,
    );
  }

  /// 모델을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'senderUid': senderUid,
      'receiverUid': receiverUid,
      'senderNickname': senderNickname,
      'receiverNickname': receiverNickname,
      'status': status.value,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  /// 모델 복사 (일부 필드 변경)
  FriendRequestModel copyWith({
    String? id,
    String? senderUid,
    String? receiverUid,
    String? senderNickname,
    String? receiverNickname,
    FriendRequestStatus? status,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FriendRequestModel(
      id: id ?? this.id,
      senderUid: senderUid ?? this.senderUid,
      receiverUid: receiverUid ?? this.receiverUid,
      senderNickname: senderNickname ?? this.senderNickname,
      receiverNickname: receiverNickname ?? this.receiverNickname,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 동등성 비교
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FriendRequestModel &&
        other.id == id &&
        other.senderUid == senderUid &&
        other.receiverUid == receiverUid &&
        other.senderNickname == senderNickname &&
        other.receiverNickname == receiverNickname &&
        other.status == status &&
        other.message == message &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  /// 해시코드
  @override
  int get hashCode {
    return id.hashCode ^
        senderUid.hashCode ^
        receiverUid.hashCode ^
        senderNickname.hashCode ^
        receiverNickname.hashCode ^
        status.hashCode ^
        message.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  /// 디버그용 문자열 표현
  @override
  String toString() {
    return 'FriendRequestModel(id: $id, senderUid: $senderUid, receiverUid: $receiverUid, senderNickname: $senderNickname, receiverNickname: $receiverNickname, status: $status, message: $message, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
