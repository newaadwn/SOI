import 'package:cloud_firestore/cloud_firestore.dart';

/// 사진 데이터 모델 (순수 데이터 클래스)
class PhotoDataModel {
  final String id;
  final String imageUrl;
  final String audioUrl;
  final String userID;
  final List<String> userIds;
  final String categoryId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final PhotoStatus status;
  final String? caption;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? metadata;
  final int likeCount;
  final List<String> likedBy;
  final int viewCount;
  final List<String> tags;

  PhotoDataModel({
    required this.id,
    required this.imageUrl,
    required this.audioUrl,
    required this.userID,
    required this.userIds,
    required this.categoryId,
    required this.createdAt,
    this.updatedAt,
    this.status = PhotoStatus.active,
    this.caption,
    this.latitude,
    this.longitude,
    this.metadata,
    this.likeCount = 0,
    this.likedBy = const [],
    this.viewCount = 0,
    this.tags = const [],
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory PhotoDataModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PhotoDataModel(
      id: id,
      imageUrl: data['imageUrl'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      userID: data['userID'] ?? '',
      userIds: (data['userIds'] as List?)?.cast<String>() ?? [],
      categoryId: data['categoryId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      status: PhotoStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PhotoStatus.active,
      ),
      caption: data['caption'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      metadata:
          data['metadata'] != null
              ? Map<String, dynamic>.from(data['metadata'])
              : null,
      likeCount: data['likeCount'] ?? 0,
      likedBy: (data['likedBy'] as List?)?.cast<String>() ?? [],
      viewCount: data['viewCount'] ?? 0,
      tags: (data['tags'] as List?)?.cast<String>() ?? [],
    );
  }

  // 기존 PhotoModel과의 호환성을 위한 factory
  factory PhotoDataModel.fromPhotoModel(Map<String, dynamic> data, String id) {
    return PhotoDataModel(
      id: id,
      imageUrl: data['imageUrl'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      userID: data['userID'] ?? '',
      userIds: (data['userIds'] as List?)?.cast<String>() ?? [],
      categoryId: data['categoryId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'userID': userID,
      'userIds': userIds,
      'categoryId': categoryId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'status': status.name,
      'caption': caption,
      'latitude': latitude,
      'longitude': longitude,
      'metadata': metadata,
      'likeCount': likeCount,
      'likedBy': likedBy,
      'viewCount': viewCount,
      'tags': tags,
    };
  }

  // 기존 PhotoModel 호환을 위한 toMap
  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'userID': userID,
      'userIds': userIds,
      'categoryId': categoryId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // 복사본 생성 (일부 필드 업데이트용)
  PhotoDataModel copyWith({
    String? id,
    String? imageUrl,
    String? audioUrl,
    String? userID,
    List<String>? userIds,
    String? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    PhotoStatus? status,
    String? caption,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? metadata,
    int? likeCount,
    List<String>? likedBy,
    int? viewCount,
    List<String>? tags,
  }) {
    return PhotoDataModel(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      userID: userID ?? this.userID,
      userIds: userIds ?? this.userIds,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      caption: caption ?? this.caption,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      metadata: metadata ?? this.metadata,
      likeCount: likeCount ?? this.likeCount,
      likedBy: likedBy ?? this.likedBy,
      viewCount: viewCount ?? this.viewCount,
      tags: tags ?? this.tags,
    );
  }

  // 검색용 키워드 생성
  List<String> get searchKeywords {
    List<String> keywords = [];
    if (caption != null) {
      keywords.addAll(caption!.toLowerCase().split(' '));
    }
    keywords.addAll(tags.map((tag) => tag.toLowerCase()));
    return keywords.where((keyword) => keyword.isNotEmpty).toList();
  }

  // 위치 정보 존재 여부
  bool get hasLocation => latitude != null && longitude != null;

  // 기존 PhotoModel 호환성을 위한 getter
  String get getPhotoId => id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoDataModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'PhotoDataModel{id: $id, imageUrl: $imageUrl, categoryId: $categoryId, status: $status}';
  }

  // Helper method for creating a PhotoDataModel from raw Firestore data
  static PhotoDataModel fromMapData(Map<String, dynamic> photoMap) {
    // Handle Timestamp conversion safely
    DateTime createdAt = DateTime.now();
    if (photoMap['createdAt'] is Timestamp) {
      createdAt = (photoMap['createdAt'] as Timestamp).toDate();
    } else if (photoMap['createdAt'] is DateTime) {
      createdAt = photoMap['createdAt'] as DateTime;
    }

    return PhotoDataModel(
      id: photoMap['id'] ?? '',
      imageUrl: photoMap['imageUrl'] ?? '',
      audioUrl: photoMap['audioUrl'] ?? '',
      userID: photoMap['userID'] ?? '',
      userIds: (photoMap['userIds'] as List?)?.cast<String>() ?? [],
      categoryId: photoMap['categoryId'] ?? '',
      createdAt: createdAt,
    );
  }
}

/// 사진 상태 열거형
enum PhotoStatus {
  active, // 활성 상태
  archived, // 아카이브됨
  deleted, // 삭제됨
  reported, // 신고됨
  processing, // 처리 중
}

/// 사진 업로드 결과
class PhotoUploadResult {
  final bool isSuccess;
  final String? photoId;
  final String? imageUrl;
  final String? audioUrl;
  final String? error;

  PhotoUploadResult({
    required this.isSuccess,
    this.photoId,
    this.imageUrl,
    this.audioUrl,
    this.error,
  });

  factory PhotoUploadResult.success({
    required String photoId,
    required String imageUrl,
    String? audioUrl,
  }) {
    return PhotoUploadResult(
      isSuccess: true,
      photoId: photoId,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
    );
  }

  factory PhotoUploadResult.failure(String error) {
    return PhotoUploadResult(isSuccess: false, error: error);
  }
}

/// 사진 검색 필터
class PhotoSearchFilter {
  final String? categoryId;
  final String? userId;
  final List<String>? tags;
  final DateTime? startDate;
  final DateTime? endDate;
  final PhotoStatus? status;
  final bool? hasLocation;
  final String? searchQuery;

  PhotoSearchFilter({
    this.categoryId,
    this.userId,
    this.tags,
    this.startDate,
    this.endDate,
    this.status,
    this.hasLocation,
    this.searchQuery,
  });
}
