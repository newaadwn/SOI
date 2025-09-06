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

  // 기존 PhotoModel 호환성을 위한 getter
  String get getPhotoId => id;

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
