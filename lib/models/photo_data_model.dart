import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 사진 데이터 모델 (순수 데이터 클래스)
class PhotoDataModel {
  final String id;
  final String imageUrl;
  final String audioUrl;
  final String userID;
  final List<String> userIds;
  final String categoryId;
  final DateTime createdAt;
  final PhotoStatus status;
  final List<double>? waveformData; // 실제 오디오 파형 데이터 추가

  PhotoDataModel({
    required this.id,
    required this.imageUrl,
    required this.audioUrl,
    required this.userID,
    required this.userIds,
    required this.categoryId,
    required this.createdAt,
    this.status = PhotoStatus.active,
    this.waveformData, // 파형 데이터 추가
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory PhotoDataModel.fromFirestore(Map<String, dynamic> data, String id) {
    // 디버그: Firestore 원본 데이터 확인
    debugPrint('🔍 Firestore 데이터 파싱 시작 - ID: $id');
    debugPrint('  - waveformData 필드 존재: ${data.containsKey('waveformData')}');
    debugPrint('  - waveformData 값: ${data['waveformData']}');
    debugPrint('  - waveformData 타입: ${data['waveformData'].runtimeType}');

    // waveformData 타입 캐스팅 처리
    List<double>? waveformData;
    if (data['waveformData'] != null) {
      final dynamic waveformRaw = data['waveformData'];
      debugPrint('  - waveformRaw 타입: ${waveformRaw.runtimeType}');

      if (waveformRaw is List) {
        try {
          waveformData = waveformRaw.map((e) => (e as num).toDouble()).toList();
          debugPrint('  - 파형 데이터 파싱 성공: ${waveformData.length} samples');
          debugPrint('  - 첫 몇 개 샘플: ${waveformData.take(5).toList()}');
        } catch (e) {
          debugPrint('  - ❌ 파형 데이터 파싱 실패: $e');
          waveformData = null;
        }
      } else {
        debugPrint('  - ⚠️ waveformData가 List 타입이 아님');
      }
    } else {
      debugPrint('  - ⚠️ waveformData 필드가 null');
    }

    return PhotoDataModel(
      id: id,
      imageUrl: data['imageUrl'] ?? '',
      audioUrl: data['audioUrl'] ?? '',
      userID: data['userID'] ?? '',
      userIds: (data['userIds'] as List?)?.cast<String>() ?? [],
      categoryId: data['categoryId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: PhotoStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PhotoStatus.active,
      ),
      waveformData: waveformData, // 파형 데이터 추가
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
    final Map<String, dynamic> data = {
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'userID': userID,
      'userIds': userIds,
      'categoryId': categoryId,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
    };

    // waveformData가 있을 때만 추가
    if (waveformData != null) {
      data['waveformData'] = waveformData;
    }

    return data;
  }

  // 기존 PhotoModel 호환을 위한 toMap
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'userID': userID,
      'userIds': userIds,
      'categoryId': categoryId,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
    };

    // waveformData가 있을 때만 추가
    if (waveformData != null) {
      data['waveformData'] = waveformData;
    }

    return data;
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
    PhotoStatus? status,
    List<double>? waveformData, // 파형 데이터 추가
  }) {
    return PhotoDataModel(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      userID: userID ?? this.userID,
      userIds: userIds ?? this.userIds,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      waveformData: waveformData ?? this.waveformData, // 파형 데이터 추가
    );
  }

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
      status: PhotoStatus.values.firstWhere(
        (e) => e.name == photoMap['status'],
        orElse: () => PhotoStatus.active,
      ),
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
  final DateTime? startDate;
  final DateTime? endDate;
  final PhotoStatus? status;
  final bool? hasAudio;

  PhotoSearchFilter({
    this.categoryId,
    this.userId,
    this.startDate,
    this.endDate,
    this.status,
    this.hasAudio,
  });
}
