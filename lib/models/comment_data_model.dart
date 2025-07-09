import 'package:cloud_firestore/cloud_firestore.dart';

// 댓글 데이터 모델 (순수 데이터 클래스)

// 댓글 상태
enum CommentStatus {
  active, // 활성
  hidden, // 숨김
  deleted, // 삭제됨
  reported, // 신고됨
}

class CommentDataModel {
  final String id;
  final String categoryId;
  final String photoId;
  final String userId;
  final String nickName;
  final String audioUrl;
  final CommentStatus status;
  final DateTime createdAt;

  CommentDataModel({
    required this.id,
    required this.categoryId,
    required this.photoId,
    required this.userId,
    required this.nickName,
    required this.audioUrl,
    required this.status,
    required this.createdAt,
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory CommentDataModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CommentDataModel(
      id: id,
      categoryId: data['categoryId'] ?? '',
      photoId: data['photoId'] ?? '',
      userId: data['userId'] ?? '',
      nickName: data['nickName'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      status: CommentStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CommentStatus.active,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'categoryId': categoryId,
      'photoId': photoId,
      'userId': userId,
      'nickName': nickName,
      'audioUrl': audioUrl,

      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // 복사본 생성 (일부 필드 업데이트용)
  CommentDataModel copyWith({
    String? id,
    String? categoryId,
    String? photoId,
    String? userId,
    String? nickName,
    String? audioUrl,
    int? durationInSeconds,
    double? fileSizeInMB,
    CommentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    int? likeCount,
    List<String>? likedBy,
  }) {
    return CommentDataModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      photoId: photoId ?? this.photoId,
      userId: userId ?? this.userId,
      nickName: nickName ?? this.nickName,
      audioUrl: audioUrl ?? this.audioUrl,

      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'CommentDataModel(id: $id, nickName: $nickName, status: $status';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentDataModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // 생성 시간을 상대적 시간으로 반환
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  // 댓글 수정 가능한지 확인 (본인 댓글이고 활성 상태)
  bool canEdit(String currentUserId) {
    return userId == currentUserId && status == CommentStatus.active;
  }

  // 댓글 삭제 가능한지 확인 (본인 댓글)
  bool canDelete(String currentUserId) {
    return userId == currentUserId;
  }
}
