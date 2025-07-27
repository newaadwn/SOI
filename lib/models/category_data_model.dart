import 'package:cloud_firestore/cloud_firestore.dart';

/// 카테고리 데이터 모델 (순수 데이터 클래스)
class CategoryDataModel {
  final String id;
  final String name;
  final List<String> mates;
  final DateTime createdAt;
  final String? categoryPhotoUrl;
  final int photoCount;

  CategoryDataModel({
    required this.id,
    required this.name,
    required this.mates,
    required this.createdAt,
    this.categoryPhotoUrl,
    this.photoCount = 0,
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory CategoryDataModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return CategoryDataModel(
      id: id,
      name: data['name'] ?? '',
      mates: (data['mates'] as List).cast<String>(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      categoryPhotoUrl: data['categoryPhotoUrl'],
      photoCount: data['photoCount'] ?? 0,
    );
  }

  // Firestore에 저장할 수 있는 형태로 변환할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'mates': mates,
      'createdAt': Timestamp.fromDate(createdAt),
      'categoryPhotoUrl': categoryPhotoUrl,
      'photoCount': photoCount,
    };
  }

  // 복사본 생성 (일부 필드 업데이트용)
  CategoryDataModel copyWith({
    String? id,
    String? name,
    List<String>? mates,
    DateTime? createdAt,
    String? categoryPhotoUrl,
    int? photoCount,
  }) {
    return CategoryDataModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mates: mates ?? this.mates,
      createdAt: createdAt ?? this.createdAt,
      categoryPhotoUrl: categoryPhotoUrl ?? this.categoryPhotoUrl,
      photoCount: photoCount ?? this.photoCount,
    );
  }

  @override
  String toString() {
    return 'CategoryDataModel(id: $id, name: $name, mates: $mates, photoCount: $photoCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryDataModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
