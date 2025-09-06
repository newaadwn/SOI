import 'package:cloud_firestore/cloud_firestore.dart';

/// 알림 유형 열거형
enum NotificationType {
  categoryInvite, // 카테고리 초대
  photoAdded, // 사진 추가
  voiceCommentAdded, // 음성 댓글 추가
}

/// 알림 데이터 모델
class NotificationModel {
  final String id;
  final String recipientUserId; // 알림을 받을 사용자
  final String actorUserId; // 행동을 수행한 사용자
  final NotificationType type; // 알림 유형
  final String title; // 알림 제목

  // 관련 ID들
  final String? categoryId;
  final String? categoryName;
  final String? photoId;
  final String? commentId;

  // 타임스탬프 및 상태
  final DateTime createdAt;
  final bool isRead; // 읽음 여부

  // 카테고리 대표 사진
  final String? categoryThumbnailUrl;

  // 사진 썸네일 URL
  final String? photoThumbnailUrl;

  // 사용자 정보 (성능 최적화용 중복 저장)
  final String? actorName;
  final String? actorProfileImage; // 알림을 보낸 주체의 프로필 이미지 URL

  NotificationModel({
    required this.id,
    required this.recipientUserId,
    required this.actorUserId,
    required this.type,
    required this.title,
    this.categoryId,
    this.categoryName,
    this.photoId,
    this.commentId,
    required this.createdAt,
    this.isRead = false,

    this.categoryThumbnailUrl,
    this.photoThumbnailUrl,

    this.actorName,
    this.actorProfileImage,
  });

  /// Firestore 문서에서 NotificationModel 생성
  factory NotificationModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return NotificationModel(
      id: id,
      recipientUserId: data['recipientUserId'] ?? '',
      actorUserId: data['actorUserId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.categoryInvite,
      ),
      title: data['title'] ?? '',
      categoryId: data['categoryId'],
      categoryName: data['categoryName'],
      photoId: data['photoId'],
      commentId: data['commentId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,

      categoryThumbnailUrl: data['categoryThumbnailUrl'],
      photoThumbnailUrl: data['photoThumbnailUrl'],
      actorName: data['actorName'],
      actorProfileImage: data['actorProfileImage'],
    );
  }

  /// Firestore에 저장할 Map 변환
  Map<String, dynamic> toFirestore() {
    return {
      'recipientUserId': recipientUserId,
      'actorUserId': actorUserId,
      'type': type.name,
      'title': title,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'photoId': photoId,
      'commentId': commentId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'categoryThumbnailUrl': categoryThumbnailUrl,
      'photoThumbnailUrl': photoThumbnailUrl,
      'actorName': actorName,
      'actorProfileImage': actorProfileImage,
    };
  }

  /// 서버 타임스탬프를 사용하여 Firestore에 저장할 Map 변환
  Map<String, dynamic> toFirestoreWithServerTimestamp() {
    final data = toFirestore();
    data['createdAt'] = FieldValue.serverTimestamp();
    return data;
  }

  /// 알림 정보 업데이트를 위한 copyWith
  NotificationModel copyWith({
    String? id,
    String? recipientUserId,
    String? actorUserId,
    NotificationType? type,
    String? title,
    String? categoryId,
    String? categoryName,
    String? photoId,
    String? commentId,
    DateTime? createdAt,
    bool? isRead,
    String? thumbnailUrl,
    String? categoryThumbnailUrl,
    String? photoThumbnailUrl,
    String? actorName,
    String? actorProfileImage,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      actorUserId: actorUserId ?? this.actorUserId,
      type: type ?? this.type,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      photoId: photoId ?? this.photoId,
      commentId: commentId ?? this.commentId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      categoryThumbnailUrl: categoryThumbnailUrl ?? this.categoryThumbnailUrl,
      photoThumbnailUrl: photoThumbnailUrl ?? this.photoThumbnailUrl,
      actorName: actorName ?? this.actorName,
      actorProfileImage: actorProfileImage ?? this.actorProfileImage,
    );
  }

  /// 표시할 썸네일 URL 결정 (우선순위: categoryThumbnailUrl)
  String? get displayThumbnailUrl {
    return categoryThumbnailUrl;
  }

  /// 알림 타입별 아이콘 이름 반환
  String get typeIconName {
    switch (type) {
      case NotificationType.categoryInvite:
        return 'person_add';
      case NotificationType.photoAdded:
        return 'photo_camera';
      case NotificationType.voiceCommentAdded:
        return 'mic';
    }
  }

  /// 알림 타입별 색상 반환
  String get typeColorHex {
    switch (type) {
      case NotificationType.categoryInvite:
        return '#4CAF50'; // Green
      case NotificationType.photoAdded:
        return '#2196F3'; // Blue
      case NotificationType.voiceCommentAdded:
        return '#FF9800'; // Orange
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'NotificationModel{id: $id, type: $type, title: $title, isRead: $isRead}';
  }
}

/// 기존 호환성을 위한 정적 메서드들 (deprecated, fromFirestore 사용 권장)
extension NotificationModelLegacy on NotificationModel {
  /// 기존 fromMap 메서드를 위한 정적 헬퍼
  static NotificationModel fromMap(Map<String, dynamic> map) {
    return NotificationModel.fromFirestore(map, map['id'] ?? '');
  }

  /// 기존 toMap 메서드 호환성
  Map<String, dynamic> toMap() {
    return toFirestore();
  }
}
