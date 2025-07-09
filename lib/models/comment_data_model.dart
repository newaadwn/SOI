import 'package:cloud_firestore/cloud_firestore.dart';

/// 댓글 데이터 모델 (순수 데이터 클래스)
class CommentDataModel {
  final String id;
  final String categoryId;
  final String photoId;
  final String userId;
  final String nickName;
  final String audioUrl;
  final int durationInSeconds;
  final double fileSizeInMB;
  final CommentStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? description;
  final int likeCount;
  final List<String> likedBy;

  CommentDataModel({
    required this.id,
    required this.categoryId,
    required this.photoId,
    required this.userId,
    required this.nickName,
    required this.audioUrl,
    required this.durationInSeconds,
    required this.fileSizeInMB,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.description,
    this.likeCount = 0,
    this.likedBy = const [],
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
      durationInSeconds: data['durationInSeconds'] ?? 0,
      fileSizeInMB: (data['fileSizeInMB'] ?? 0.0).toDouble(),
      status: CommentStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CommentStatus.active,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      description: data['description'],
      likeCount: data['likeCount'] ?? 0,
      likedBy: (data['likedBy'] as List?)?.cast<String>() ?? [],
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
      'durationInSeconds': durationInSeconds,
      'fileSizeInMB': fileSizeInMB,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'description': description,
      'likeCount': likeCount,
      'likedBy': likedBy,
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
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      fileSizeInMB: fileSizeInMB ?? this.fileSizeInMB,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
    );
  }

  @override
  String toString() {
    return 'CommentDataModel(id: $id, nickName: $nickName, status: $status, duration: ${durationInSeconds}s)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommentDataModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// 파일 크기를 읽기 쉬운 형태로 반환
  String get readableFileSize {
    if (fileSizeInMB < 1) {
      return '${(fileSizeInMB * 1024).toStringAsFixed(1)} KB';
    }
    return '${fileSizeInMB.toStringAsFixed(1)} MB';
  }

  /// 댓글 시간을 MM:SS 형태로 반환
  String get formattedDuration {
    final minutes = durationInSeconds ~/ 60;
    final seconds = durationInSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 생성 시간을 상대적 시간으로 반환
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

  /// 사용자가 이 댓글을 좋아요했는지 확인
  bool isLikedBy(String userId) {
    return likedBy.contains(userId);
  }

  /// 댓글 수정 가능한지 확인 (본인 댓글이고 활성 상태)
  bool canEdit(String currentUserId) {
    return userId == currentUserId && status == CommentStatus.active;
  }

  /// 댓글 삭제 가능한지 확인 (본인 댓글)
  bool canDelete(String currentUserId) {
    return userId == currentUserId;
  }
}

/// 댓글 상태
enum CommentStatus {
  active, // 활성
  hidden, // 숨김
  deleted, // 삭제됨
  reported, // 신고됨
}
