import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/painting.dart'; // Offset를 위한 import

class CommentRecordModel {
  final String id;
  final String audioUrl;
  final String photoId;
  final String recorderUser; // 음성 댓글을 다는 사용자
  final DateTime createdAt;
  final List<double> waveformData;
  final int duration; // milliseconds
  final String profileImageUrl; // 프로필 이미지 URL
  final Offset? profilePosition; // 프로필 이미지 위치 (상대 좌표)
  final bool isDeleted;

  CommentRecordModel({
    required this.id,
    required this.audioUrl,
    required this.photoId,
    required this.recorderUser,
    required this.createdAt,
    required this.waveformData,
    required this.duration,
    required this.profileImageUrl,
    this.profilePosition, // 선택적 필드
    this.isDeleted = false,
  });

  /// Firestore 문서에서 CommentRecordModel 객체 생성
  factory CommentRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // profilePosition 파싱
    Offset? profilePosition;
    if (data['profilePosition'] != null) {
      final posData = data['profilePosition'] as Map<String, dynamic>;
      profilePosition = Offset(
        (posData['dx'] as num?)?.toDouble() ?? 0.0,
        (posData['dy'] as num?)?.toDouble() ?? 0.0,
      );
    }

    return CommentRecordModel(
      id: doc.id,
      audioUrl: data['audioUrl'] ?? '',
      photoId: data['photoId'] ?? '',
      recorderUser: data['recorderUser'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      waveformData: List<double>.from(data['waveformData'] ?? []),
      duration: data['duration'] ?? 0,
      isDeleted: data['isDeleted'] ?? false,
      profileImageUrl: data['profileImageUrl'] ?? '',
      profilePosition: profilePosition,
    );
  }

  /// CommentRecordModel 객체를 Firestore 문서로 변환
  Map<String, dynamic> toFirestore() {
    final result = {
      'audioUrl': audioUrl,
      'photoId': photoId,
      'recorderUser': recorderUser,
      'createdAt': Timestamp.fromDate(createdAt),
      'waveformData': waveformData,
      'duration': duration,
      'isDeleted': isDeleted,
      'profileImageUrl': profileImageUrl,
    };

    // profilePosition이 있는 경우만 추가
    if (profilePosition != null) {
      result['profilePosition'] = {
        'dx': profilePosition!.dx,
        'dy': profilePosition!.dy,
      };
    }

    return result;
  }

  /// CommentRecordModel 복사본 생성 (일부 필드 수정용)
  CommentRecordModel copyWith({
    String? id,
    String? audioUrl,
    String? photoId,
    String? recorderUser,
    DateTime? createdAt,
    List<double>? waveformData,
    int? duration,
    bool? isDeleted,
    String? profileImageUrl,
    Offset? profilePosition,
  }) {
    return CommentRecordModel(
      id: id ?? this.id,
      audioUrl: audioUrl ?? this.audioUrl,
      photoId: photoId ?? this.photoId,
      recorderUser: recorderUser ?? this.recorderUser,
      createdAt: createdAt ?? this.createdAt,
      waveformData: waveformData ?? this.waveformData,
      duration: duration ?? this.duration,
      isDeleted: isDeleted ?? this.isDeleted,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profilePosition: profilePosition ?? this.profilePosition,
    );
  }

  @override
  String toString() {
    return 'CommentRecordModel(id: $id, photoId: $photoId, recorderUser: $recorderUser, duration: ${duration}ms, profileImageUrl: $profileImageUrl)';
  }
}
