import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/photo_data_model.dart';
import '../repositories/photo_repository.dart';

/// Photo Service - 사진 관련 비즈니스 로직을 처리
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class PhotoService {
  final PhotoRepository _photoRepository = PhotoRepository();

  // ==================== 사진 업로드 비즈니스 로직 ====================

  /// 사진 업로드 (이미지 + 오디오 + 메타데이터)
  Future<PhotoUploadResult> uploadPhoto({
    required File imageFile,
    File? audioFile,
    required String categoryId,
    required String userId,
    required List<String> userIds,
    String? caption,
    double? latitude,
    double? longitude,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 입력 검증
      final validationResult = _validatePhotoUpload(
        imageFile: imageFile,
        categoryId: categoryId,
        userId: userId,
        userIds: userIds,
      );

      if (!validationResult.isValid) {
        return PhotoUploadResult.failure(validationResult.error!);
      }

      // 1. 이미지 파일 업로드
      final imageUrl = await _photoRepository.uploadImageToStorage(
        imageFile: imageFile,
        categoryId: categoryId,
        userId: userId,
      );

      if (imageUrl == null) {
        return PhotoUploadResult.failure('이미지 업로드에 실패했습니다.');
      }

      // 2. 오디오 파일 업로드 (있는 경우)
      String? audioUrl;
      if (audioFile != null) {
        audioUrl = await _photoRepository.uploadAudioToStorage(
          audioFile: audioFile,
          categoryId: categoryId,
          userId: userId,
        );

        if (audioUrl == null) {
          return PhotoUploadResult.failure('오디오 업로드에 실패했습니다.');
        }
      }

      // 3. 사진 데이터 모델 생성
      final photoData = PhotoDataModel(
        id: '', // Firestore에서 자동 생성
        imageUrl: imageUrl,
        audioUrl: audioUrl ?? '',
        userID: userId,
        userIds: userIds,
        categoryId: categoryId,
        createdAt: DateTime.now(),
        caption: caption,
        latitude: latitude,
        longitude: longitude,
        tags: tags ?? [],
        metadata: metadata,
      );

      // 4. Firestore에 메타데이터 저장
      final photoId = await _photoRepository.savePhotoToFirestore(
        photo: photoData,
        categoryId: categoryId,
      );

      if (photoId == null) {
        return PhotoUploadResult.failure('사진 정보 저장에 실패했습니다.');
      }

      return PhotoUploadResult.success(
        photoId: photoId,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
      );
    } catch (e) {
      debugPrint('사진 업로드 서비스 오류: $e');
      return PhotoUploadResult.failure('사진 업로드 중 오류가 발생했습니다.');
    }
  }

  /// 단순 이미지 업로드 (기존 호환성)
  Future<PhotoUploadResult> uploadSimplePhoto({
    required File imageFile,
    required String categoryId,
    required String userId,
    String? audioUrl,
  }) async {
    return await uploadPhoto(
      imageFile: imageFile,
      categoryId: categoryId,
      userId: userId,
      userIds: [userId],
      metadata: {'uploadType': 'simple'},
    );
  }

  // ==================== 사진 조회 비즈니스 로직 ====================

  /// 카테고리별 사진 목록 조회
  Future<List<PhotoDataModel>> getPhotosByCategory(String categoryId) async {
    try {
      if (categoryId.isEmpty) {
        throw ArgumentError('카테고리 ID가 필요합니다.');
      }

      final photos = await _photoRepository.getPhotosByCategory(categoryId);

      // 비즈니스 로직: 최신순 정렬 및 필터링
      return _applyPhotoBusinessRules(photos);
    } catch (e) {
      debugPrint('카테고리별 사진 조회 서비스 오류: $e');
      return [];
    }
  }

  /// 카테고리별 사진 스트림 (실시간)
  Stream<List<PhotoDataModel>> getPhotosByCategoryStream(String categoryId) {
    if (categoryId.isEmpty) {
      return Stream.value([]);
    }

    return _photoRepository
        .getPhotosByCategoryStream(categoryId)
        .map((photos) => _applyPhotoBusinessRules(photos));
  }

  /// 사용자별 사진 목록 조회
  Future<List<PhotoDataModel>> getPhotosByUser(String userId) async {
    try {
      if (userId.isEmpty) {
        throw ArgumentError('사용자 ID가 필요합니다.');
      }

      final photos = await _photoRepository.getPhotosByUser(userId);
      return _applyPhotoBusinessRules(photos);
    } catch (e) {
      debugPrint('사용자별 사진 조회 서비스 오류: $e');
      return [];
    }
  }

  /// 특정 사진 상세 조회
  Future<PhotoDataModel?> getPhotoDetails({
    required String categoryId,
    required String photoId,
    String? viewerUserId,
  }) async {
    try {
      if (categoryId.isEmpty || photoId.isEmpty) {
        throw ArgumentError('카테고리 ID와 사진 ID가 필요합니다.');
      }

      final photo = await _photoRepository.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );

      if (photo != null && viewerUserId != null) {
        // 비즈니스 로직: 조회수 증가 (본인 사진이 아닌 경우만)
        if (photo.userID != viewerUserId) {
          await _photoRepository.incrementPhotoViewCount(
            categoryId: categoryId,
            photoId: photoId,
          );
        }
      }

      return photo;
    } catch (e) {
      debugPrint('사진 상세 조회 서비스 오류: $e');
      return null;
    }
  }

  /// 사진 검색
  Future<List<PhotoDataModel>> searchPhotos({
    required PhotoSearchFilter filter,
    int? limit,
  }) async {
    try {
      final photos = await _photoRepository.searchPhotos(filter: filter);

      List<PhotoDataModel> filteredPhotos = _applyPhotoBusinessRules(photos);

      // 텍스트 검색 로직 (클라이언트 사이드)
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        final query = filter.searchQuery!.toLowerCase();
        filteredPhotos =
            filteredPhotos.where((photo) {
              return photo.caption?.toLowerCase().contains(query) == true ||
                  photo.tags.any((tag) => tag.toLowerCase().contains(query));
            }).toList();
      }

      // 개수 제한
      if (limit != null && limit > 0) {
        filteredPhotos = filteredPhotos.take(limit).toList();
      }

      return filteredPhotos;
    } catch (e) {
      debugPrint('사진 검색 서비스 오류: $e');
      return [];
    }
  }

  // ==================== 사진 업데이트 비즈니스 로직 ====================

  /// 사진 정보 업데이트
  Future<bool> updatePhoto({
    required String categoryId,
    required String photoId,
    required String userId,
    String? caption,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 권한 검증
      final photo = await _photoRepository.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );

      if (photo == null) {
        throw Exception('사진을 찾을 수 없습니다.');
      }

      if (photo.userID != userId) {
        throw Exception('사진을 수정할 권한이 없습니다.');
      }

      // 업데이트 데이터 준비
      final Map<String, dynamic> updates = {};

      if (caption != null) {
        // 비즈니스 로직: 캡션 길이 제한
        if (caption.length > 500) {
          throw Exception('캡션은 500자를 초과할 수 없습니다.');
        }
        updates['caption'] = caption;
      }

      if (tags != null) {
        // 비즈니스 로직: 태그 개수 제한
        if (tags.length > 10) {
          throw Exception('태그는 10개를 초과할 수 없습니다.');
        }
        updates['tags'] = tags;
      }

      if (metadata != null) {
        updates['metadata'] = metadata;
      }

      if (updates.isEmpty) {
        return true; // 업데이트할 내용이 없음
      }

      return await _photoRepository.updatePhoto(
        categoryId: categoryId,
        photoId: photoId,
        updates: updates,
      );
    } catch (e) {
      debugPrint('사진 업데이트 서비스 오류: $e');
      return false;
    }
  }

  /// 사진 좋아요 토글
  Future<bool> togglePhotoLike({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    try {
      if (categoryId.isEmpty || photoId.isEmpty || userId.isEmpty) {
        throw ArgumentError('필수 매개변수가 누락되었습니다.');
      }

      return await _photoRepository.togglePhotoLike(
        categoryId: categoryId,
        photoId: photoId,
        userId: userId,
      );
    } catch (e) {
      debugPrint('사진 좋아요 토글 서비스 오류: $e');
      return false;
    }
  }

  // ==================== 사진 삭제 비즈니스 로직 ====================

  /// 사진 삭제
  Future<bool> deletePhoto({
    required String categoryId,
    required String photoId,
    required String userId,
    bool permanentDelete = false,
  }) async {
    try {
      // 권한 검증
      final photo = await _photoRepository.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );

      if (photo == null) {
        throw Exception('사진을 찾을 수 없습니다.');
      }

      if (photo.userID != userId) {
        throw Exception('사진을 삭제할 권한이 없습니다.');
      }

      if (permanentDelete) {
        // 완전 삭제
        return await _photoRepository.permanentDeletePhoto(
          categoryId: categoryId,
          photoId: photoId,
          imageUrl: photo.imageUrl,
          audioUrl: photo.audioUrl.isNotEmpty ? photo.audioUrl : null,
        );
      } else {
        // 소프트 삭제
        return await _photoRepository.deletePhoto(
          categoryId: categoryId,
          photoId: photoId,
        );
      }
    } catch (e) {
      debugPrint('사진 삭제 서비스 오류: $e');
      return false;
    }
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 기존 Map 형태로 사진 목록 조회 (호환성)
  Future<List<Map<String, dynamic>>> getCategoryPhotosAsMap(
    String categoryId,
  ) async {
    return await _photoRepository.getCategoryPhotosAsMap(categoryId);
  }

  /// 기존 Map 형태로 사진 스트림 (호환성)
  Stream<List<Map<String, dynamic>>> getCategoryPhotosStreamAsMap(
    String categoryId,
  ) {
    return _photoRepository.getCategoryPhotosStreamAsMap(categoryId);
  }

  // ==================== 통계 및 유틸리티 ====================

  /// 사진 통계 조회
  Future<Map<String, int>> getPhotoStats(String categoryId) async {
    return await _photoRepository.getPhotoStats(categoryId);
  }

  /// 인기 태그 조회
  Future<List<String>> getPopularTags({
    String? categoryId,
    int limit = 10,
  }) async {
    try {
      final PhotoSearchFilter filter = PhotoSearchFilter(
        categoryId: categoryId,
      );

      final photos = await _photoRepository.searchPhotos(filter: filter);

      // 태그 빈도 계산
      final Map<String, int> tagCounts = {};
      for (final photo in photos) {
        for (final tag in photo.tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      // 빈도순 정렬
      final sortedTags =
          tagCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTags.take(limit).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('인기 태그 조회 오류: $e');
      return [];
    }
  }

  // ==================== 비즈니스 규칙 검증 ====================

  /// 사진 업로드 검증
  PhotoValidationResult _validatePhotoUpload({
    required File imageFile,
    required String categoryId,
    required String userId,
    required List<String> userIds,
  }) {
    // 필수 필드 검증
    if (categoryId.isEmpty) {
      return PhotoValidationResult.invalid('카테고리 ID가 필요합니다.');
    }

    if (userId.isEmpty) {
      return PhotoValidationResult.invalid('사용자 ID가 필요합니다.');
    }

    if (userIds.isEmpty || !userIds.contains(userId)) {
      return PhotoValidationResult.invalid('올바른 사용자 목록이 필요합니다.');
    }

    // 파일 크기 검증 (10MB 제한)
    if (imageFile.lengthSync() > 10 * 1024 * 1024) {
      return PhotoValidationResult.invalid('이미지 파일 크기는 10MB를 초과할 수 없습니다.');
    }

    return PhotoValidationResult.valid();
  }

  /// 사진 비즈니스 규칙 적용
  List<PhotoDataModel> _applyPhotoBusinessRules(List<PhotoDataModel> photos) {
    // 활성 상태만 필터링
    final activePhotos =
        photos.where((photo) => photo.status == PhotoStatus.active).toList();

    // 최신순 정렬
    activePhotos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return activePhotos;
  }
}

/// 사진 검증 결과
class PhotoValidationResult {
  final bool isValid;
  final String? error;

  PhotoValidationResult._({required this.isValid, this.error});

  factory PhotoValidationResult.valid() {
    return PhotoValidationResult._(isValid: true);
  }

  factory PhotoValidationResult.invalid(String error) {
    return PhotoValidationResult._(isValid: false, error: error);
  }
}
