import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 카테고리 데이터 모델 (순수 데이터 클래스)
class CategoryDataModel {
  final String id;
  final String name;
  final List<String> mates;
  final DateTime createdAt;
  final String? categoryPhotoUrl;
  final Map<String, String>? customNames;

  // 사용자별 고정 상태 (userId -> isPinned)
  final Map<String, bool>? userPinnedStatus;

  // 최신 사진 정보 (new 아이콘 표시용)
  final String? lastPhotoUploadedBy; // 마지막으로 사진을 올린 사용자 ID
  final DateTime? lastPhotoUploadedAt; // 마지막 사진 업로드 시간
  final Map<String, DateTime>? userLastViewedAt; // 사용자별 마지막 확인 시간

  CategoryDataModel({
    required this.id,
    required this.name,
    required this.mates,
    required this.createdAt,
    this.categoryPhotoUrl,
    this.customNames,
    this.userPinnedStatus,
    this.lastPhotoUploadedBy,
    this.lastPhotoUploadedAt,
    this.userLastViewedAt,
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory CategoryDataModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    debugPrint(
      '📦 CategoryDataModel.fromFirestore - 카테고리: ${data['name']} ($id)',
    );
    debugPrint('  - lastPhotoUploadedBy: ${data['lastPhotoUploadedBy']}');
    debugPrint('  - lastPhotoUploadedAt: ${data['lastPhotoUploadedAt']}');
    debugPrint('  - userLastViewedAt: ${data['userLastViewedAt']}');

    return CategoryDataModel(
      id: id,
      name: data['name'] ?? '',
      mates: (data['mates'] as List).cast<String>(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      categoryPhotoUrl: data['categoryPhotoUrl'],
      customNames:
          data['customNames'] != null
              ? Map<String, String>.from(data['customNames'])
              : null,
      userPinnedStatus:
          data['userPinnedStatus'] != null
              ? Map<String, bool>.from(data['userPinnedStatus'])
              : null,
      lastPhotoUploadedBy: data['lastPhotoUploadedBy'],
      lastPhotoUploadedAt:
          data['lastPhotoUploadedAt'] != null
              ? (data['lastPhotoUploadedAt'] as Timestamp).toDate()
              : null,
      userLastViewedAt:
          data['userLastViewedAt'] != null
              ? Map<String, DateTime>.from(
                (data['userLastViewedAt'] as Map).map(
                  (key, value) =>
                      MapEntry(key.toString(), (value as Timestamp).toDate()),
                ),
              )
              : null,
    );
  }

  // Firestore에 저장할 수 있는 형태로 변환할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'mates': mates,
      'createdAt': Timestamp.fromDate(createdAt),
      'categoryPhotoUrl': categoryPhotoUrl,
      'customNames': customNames,
      'userPinnedStatus': userPinnedStatus,
      'lastPhotoUploadedBy': lastPhotoUploadedBy,
      'lastPhotoUploadedAt':
          lastPhotoUploadedAt != null
              ? Timestamp.fromDate(lastPhotoUploadedAt!)
              : null,
      'userLastViewedAt': userLastViewedAt?.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
    };
  }

  // 복사본 생성 (일부 필드 업데이트용)
  CategoryDataModel copyWith({
    String? id,
    String? name,
    List<String>? mates,
    DateTime? createdAt,
    String? categoryPhotoUrl,
    Map<String, String>? customNames,
    Map<String, bool>? userPinnedStatus,
    String? lastPhotoUploadedBy,
    DateTime? lastPhotoUploadedAt,
    Map<String, DateTime>? userLastViewedAt,
  }) {
    return CategoryDataModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mates: mates ?? this.mates,
      createdAt: createdAt ?? this.createdAt,
      categoryPhotoUrl: categoryPhotoUrl ?? this.categoryPhotoUrl,
      customNames: customNames ?? this.customNames,
      userPinnedStatus: userPinnedStatus ?? this.userPinnedStatus,
      lastPhotoUploadedBy: lastPhotoUploadedBy ?? this.lastPhotoUploadedBy,
      lastPhotoUploadedAt: lastPhotoUploadedAt ?? this.lastPhotoUploadedAt,
      userLastViewedAt: userLastViewedAt ?? this.userLastViewedAt,
    );
  }

  /// 특정 사용자를 위한 표시 이름 가져오기
  String getDisplayName(String userId) {
    return customNames?[userId] ?? name;
  }

  /// 특정 사용자의 고정 상태 확인
  bool isPinnedForUser(String userId) {
    return userPinnedStatus?[userId] ?? false;
  }

  /// 특정 사용자에게 새로운 사진이 있는지 확인
  bool hasNewPhotoForUser(String currentUserId) {
    debugPrint('🔍 새 사진 확인 - 카테고리: $name, 사용자: $currentUserId');

    // 마지막 사진 업로드 정보가 없으면 새로운 사진 없음
    if (lastPhotoUploadedBy == null || lastPhotoUploadedAt == null) {
      return false;
    }

    // 현재 사용자가 업로드한 사진이면 new 아이콘 표시하지 않음
    if (lastPhotoUploadedBy == currentUserId) {
      return false;
    }

    // 사용자가 마지막으로 확인한 시간 이후에 업로드된 사진인지 확인
    final userLastViewed = userLastViewedAt?[currentUserId];

    if (userLastViewed == null) {
      // 한 번도 확인하지 않았으면 새로운 사진으로 간주

      return true;
    }

    // 마지막 확인 시간 이후에 업로드된 사진인지 확인
    final isNewPhoto = lastPhotoUploadedAt!.isAfter(userLastViewed);

    return isNewPhoto;
  }

  @override
  String toString() {
    return 'CategoryDataModel(id: $id, name: $name, mates: $mates';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryDataModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
