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
  final PhotoStatus status;
  final List<double>? waveformData; // 실제 오디오 파형 데이터 추가
  final Duration duration; // 음성 길이 (초 단위) 추가

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
    this.duration = const Duration(seconds: 0), // 기본값 0초
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory PhotoDataModel.fromFirestore(Map<String, dynamic> data, String id) {
    // waveformData 타입 캐스팅 처리
    List<double>? waveformData;
    if (data['waveformData'] != null) {
      final dynamic waveformRaw = data['waveformData'];
      // debugPrint('  - waveformRaw 타입: ${waveformRaw.runtimeType}');

      if (waveformRaw is List) {
        try {
          waveformData = waveformRaw.map((e) => (e as num).toDouble()).toList();
        } catch (e) {
          waveformData = null;
        }
      }
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
      duration: Duration(seconds: (data['duration'] ?? 0) as int), // 음성 길이 추가
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
      duration: Duration(seconds: (data['duration'] ?? 0) as int), // 음성 길이 추가
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
      'duration': duration.inSeconds, // 음성 길이 추가 (초 단위로 저장)
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
      'duration': duration.inSeconds, // 음성 길이 추가 (초 단위로 저장)
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
    Duration? duration, // 음성 길이 추가
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
      duration: duration ?? this.duration, // 음성 길이 추가
    );
  }

  // 기존 PhotoModel 호환성을 위한 getter
  String get getPhotoId => id;

  /// 음성 길이를 MM:SS 형식으로 포맷팅
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 음성이 있는지 확인
  bool get hasAudio => audioUrl.isNotEmpty && duration > Duration.zero;

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
      duration: Duration(
        seconds: (photoMap['duration'] ?? 0) as int,
      ), // 음성 길이 추가
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
