import 'dart:io';
import 'package:flutter/material.dart';
import '../models/photo_data_model.dart';
import '../repositories/photo_repository.dart';
import 'audio_service.dart';
import 'category_service.dart';
import 'notification_service.dart';

/// Photo Service - 사진 관련 비즈니스 로직을 처리
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class PhotoService {
  // Singleton pattern
  static final PhotoService _instance = PhotoService._internal();
  factory PhotoService() => _instance;
  PhotoService._internal();

  final PhotoRepository _photoRepository = PhotoRepository();
  final AudioService _audioService = AudioService();

  // Lazy initialization으로 순환 의존성 방지
  CategoryService? _categoryService;
  CategoryService get categoryService {
    _categoryService ??= CategoryService();
    return _categoryService!;
  }

  NotificationService? _notificationService;
  NotificationService get notificationService {
    _notificationService ??= NotificationService();
    return _notificationService!;
  }

  // ==================== 사진 업로드 비즈니스 로직 ====================

  /// 사진 업로드 (이미지 + 오디오)
  Future<PhotoUploadResult> uploadPhoto({
    required File imageFile,
    File? audioFile,
    required String categoryId,
    required String userId,
    required List<String> userIds,
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
      );

      // 4. Firestore에 메타데이터 저장
      final photoId = await _photoRepository.savePhotoToFirestore(
        photo: photoData,
        categoryId: categoryId,
      );

      if (photoId == null) {
        return PhotoUploadResult.failure('사진 정보 저장에 실패했습니다.');
      }

      // 5. 카테고리의 최신 사진 정보 업데이트
      await categoryService.updateLastPhotoInfo(
        categoryId: categoryId,
        uploadedBy: userId,
      );

      // 6. 카테고리 대표 사진 자동 업데이트 로직
      // 직접 설정하지 않은 경우에는 항상 최신 사진이 대표사진이 되도록 함
      final categories = await categoryService.getUserCategories(userId);
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('카테고리를 찾을 수 없습니다: $categoryId'),
      );

      bool shouldUpdateCoverPhoto = false;

      // 대표사진이 없는 경우 (첫 번째 사진)
      if (category.categoryPhotoUrl?.isEmpty ?? true) {
        shouldUpdateCoverPhoto = true;
      } else {
        // 이미 대표사진이 있는 경우, 직접 설정한 것인지 확인
        // 직접 설정하지 않은 경우에는 항상 최신 사진으로 업데이트
        shouldUpdateCoverPhoto = await _isAutomaticallySetCoverPhoto(
          categoryId,
          category.categoryPhotoUrl!,
        );
      }

      if (shouldUpdateCoverPhoto) {
        await categoryService.updateCoverPhotoFromCategory(
          categoryId: categoryId,
          photoUrl: imageUrl,
        );

        // 7. 카테고리 대표사진이 업데이트된 경우 관련 알림들의 썸네일 업데이트
        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: imageUrl,
          );
        } catch (e) {
          debugPrint('⚠️ 알림 썸네일 업데이트 실패: $e');
        }
      }

      // 8. 사진 추가 알림 생성
      try {
        // Firestore 저장 완료를 위한 짧은 지연
        await Future.delayed(Duration(milliseconds: 100));

        await notificationService.createPhotoAddedNotification(
          categoryId: categoryId,
          photoId: photoId,
          actorUserId: userId,
          photoUrl: imageUrl, // 이미지 URL 직접 전달
        );
      } catch (e) {
        // 알림 생성 실패는 전체 업로드를 실패시키지 않음
        debugPrint('⚠️ 알림 생성 실패 (업로드는 성공): $e');
      }

      return PhotoUploadResult.success(
        photoId: photoId,
        imageUrl: imageUrl,
        audioUrl: audioUrl,
      );
    } catch (e) {
      // // debugPrint('사진 업로드 서비스 오류: $e');
      return PhotoUploadResult.failure('사진 업로드 중 오류가 발생했습니다.');
    }
  }

  /// 사진과 오디오를 파형 데이터와 함께 저장
  Future<String> savePhotoWithAudio({
    required String imageFilePath,
    required String audioFilePath,
    required String userID,
    required List<String> userIds,
    required String categoryId,
    List<double>? waveformData,
    Duration? duration,
  }) async {
    try {
      // 1. 이미지 업로드

      final imageFile = File(imageFilePath);
      final imageUrl = await _photoRepository.uploadImageToStorage(
        imageFile: imageFile,
        categoryId: categoryId,
        userId: userID,
      );

      if (imageUrl == null) {
        throw Exception('이미지 업로드에 실패했습니다.');
      }

      // 2. 오디오 업로드

      final audioFile = File(audioFilePath);
      final audioUrl = await _photoRepository.uploadAudioToStorage(
        audioFile: audioFile,
        categoryId: categoryId,
        userId: userID,
      );

      if (audioUrl == null) {
        throw Exception('오디오 업로드에 실패했습니다.');
      }

      // 3. 파형 데이터 처리 (제공된 데이터 우선 사용)
      List<double> finalWaveformData;

      if (waveformData != null && waveformData.isNotEmpty) {
        finalWaveformData = waveformData;
      } else {
        finalWaveformData = await _audioService.extractWaveformData(
          audioFilePath,
        );
      }

      final photoId = await _photoRepository.savePhotoWithWaveform(
        imageUrl: imageUrl,
        audioUrl: audioUrl,
        userID: userID,
        userIds: userIds,
        categoryId: categoryId,
        waveformData: finalWaveformData, // 파형 데이터 전달
        duration: duration, // 음성 길이 전달
      );

      // 카테고리의 최신 사진 정보 업데이트
      await categoryService.updateLastPhotoInfo(
        categoryId: categoryId,
        uploadedBy: userID,
      );

      // 카테고리 대표 사진 자동 업데이트 로직
      // 직접 설정하지 않은 경우에는 항상 최신 사진이 대표사진이 되도록 함
      final categories = await categoryService.getUserCategories(userID);
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('카테고리를 찾을 수 없습니다: $categoryId'),
      );

      bool shouldUpdateCoverPhoto = false;

      // 대표사진이 없는 경우 (첫 번째 사진)
      if (category.categoryPhotoUrl?.isEmpty ?? true) {
        shouldUpdateCoverPhoto = true;
      } else {
        // 이미 대표사진이 있는 경우, 직접 설정한 것인지 확인
        // 직접 설정하지 않은 경우에는 항상 최신 사진으로 업데이트
        shouldUpdateCoverPhoto = await _isAutomaticallySetCoverPhoto(
          categoryId,
          category.categoryPhotoUrl!,
        );
      }

      if (shouldUpdateCoverPhoto) {
        await categoryService.updateCoverPhotoFromCategory(
          categoryId: categoryId,
          photoUrl: imageUrl,
        );

        // 카테고리 대표사진이 업데이트된 경우 관련 알림들의 썸네일 업데이트
        try {
          await notificationService.updateCategoryThumbnailInNotifications(
            categoryId: categoryId,
            newThumbnailUrl: imageUrl,
          );
        } catch (e) {
          debugPrint('⚠️ 알림 썸네일 업데이트 실패: $e');
        }
      }

      // 사진 추가 알림 생성
      try {
        // Firestore 저장 완료를 위한 짧은 지연
        await Future.delayed(Duration(milliseconds: 100));

        await notificationService.createPhotoAddedNotification(
          categoryId: categoryId,
          photoId: photoId,
          actorUserId: userID,
          photoUrl: imageUrl, // 이미지 URL 직접 전달
        );
      } catch (e) {
        // 알림 생성 실패는 전체 업로드를 실패시키지 않음
        debugPrint('⚠️ 알림 생성 실패 (업로드는 성공): $e');
      }

      return photoId;
    } catch (e) {
      debugPrint('사진 저장 실패: $e');
      rethrow;
    }
  }

  // ==================== 사진 조회 비즈니스 로직 ====================

  /// 모든 카테고리에서 사진을 페이지네이션으로 조회 (무한 스크롤용)
  Future<({List<PhotoDataModel> photos, String? lastPhotoId, bool hasMore})>
  getPhotosFromAllCategoriesPaginated({
    required List<String> categoryIds,
    int limit = 20,
    String? startAfterPhotoId,
  }) async {
    try {
      // 입력 검증
      if (categoryIds.isEmpty) {
        throw ArgumentError('카테고리 ID 목록이 필요합니다.');
      }

      if (limit <= 0 || limit > 100) {
        throw ArgumentError('제한값은 1과 100 사이여야 합니다.');
      }

      final result = await _photoRepository.getPhotosFromAllCategoriesPaginated(
        categoryIds: categoryIds,
        limit: limit,
        startAfterPhotoId: startAfterPhotoId,
      );

      // 비즈니스 로직: 사진 필터링 및 검증
      final filteredPhotos = _applyPhotoBusinessRules(result.photos);

      return (
        photos: filteredPhotos,
        lastPhotoId: result.lastPhotoId,
        hasMore: result.hasMore,
      );
    } catch (e) {
      return (photos: <PhotoDataModel>[], lastPhotoId: null, hasMore: false);
    }
  }

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

  /// 특정 사진을 ID로 조회
  Future<PhotoDataModel?> getPhotoById({
    required String categoryId,
    required String photoId,
  }) async {
    try {
      if (categoryId.isEmpty || photoId.isEmpty) {
        throw ArgumentError('카테고리 ID와 사진 ID가 필요합니다.');
      }

      return await _photoRepository.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );
    } catch (e) {
      debugPrint('PhotoService: getPhotoById 오류 - $e');
      return null;
    }
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

      return photo;
    } catch (e) {
      return null;
    }
  }

  // ==================== 사진 업데이트 비즈니스 로직 ====================

  /// 사진 정보 업데이트
  Future<bool> updatePhoto({
    required String categoryId,
    required String photoId,
    required String userId,
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

      // PhotoDataModel의 기본 속성들은 대부분 수정 불가능한 속성들이므로
      // 현재는 간단한 검증만 수행하고 성공으로 반환
      return true;
    } catch (e) {
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

      // 삭제하기 전에 현재 카테고리 정보 확인
      final categories = await categoryService.getUserCategories(userId);
      final category = categories.firstWhere(
        (cat) => cat.id == categoryId,
        orElse: () => throw Exception('카테고리를 찾을 수 없습니다: $categoryId'),
      );

      // 삭제될 사진이 현재 대표사진인지 확인
      final isCurrentCoverPhoto = category.categoryPhotoUrl == photo.imageUrl;

      bool deleteResult;
      if (permanentDelete) {
        // 완전 삭제
        deleteResult = await _photoRepository.permanentDeletePhoto(
          categoryId: categoryId,
          photoId: photoId,
          imageUrl: photo.imageUrl,
          audioUrl: photo.audioUrl.isNotEmpty ? photo.audioUrl : null,
        );
      } else {
        // 소프트 삭제
        deleteResult = await _photoRepository.deletePhoto(
          categoryId: categoryId,
          photoId: photoId,
        );
      }

      // 삭제 성공하고, 삭제된 사진이 대표사진이었다면 새로운 대표사진으로 업데이트
      if (deleteResult && isCurrentCoverPhoto) {
        try {
          await categoryService.updateCoverPhotoToLatestAfterDeletion(
            categoryId,
          );
        } catch (e) {
          debugPrint('⚠️ 삭제 후 대표사진 업데이트 실패: $e');
          // 사진 삭제는 성공했으므로 계속 진행
        }
      }

      return deleteResult;
    } catch (e) {
      return false;
    }
  }

  // ==================== 통계 및 유틸리티 ====================

  /// 사진 통계 조회
  Future<Map<String, int>> getPhotoStats(String categoryId) async {
    return await _photoRepository.getPhotoStats(categoryId);
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

  // ==================== 파형 데이터 유틸리티 ====================

  /// 특정 사진에 파형 데이터 추가
  Future<bool> addWaveformDataToPhoto({
    required String categoryId,
    required String photoId,
    required String audioFilePath,
  }) async {
    try {
      // // debugPrint('🌊 특정 사진에 파형 데이터 추가 시작');

      // 오디오 파일에서 파형 데이터 추출
      final waveformData = await _audioService.extractWaveformData(
        audioFilePath,
      );
      final audioDuration = await _audioService.getAudioDuration(audioFilePath);

      return await _photoRepository.addWaveformDataToPhoto(
        categoryId: categoryId,
        photoId: photoId,
        waveformData: waveformData,
        audioDuration: audioDuration,
      );
    } catch (e) {
      return false;
    }
  }

  /// 현재 카테고리 대표사진이 자동으로 설정된 것인지 확인
  /// (카테고리의 기존 사진 중 하나라면 자동 설정된 것으로 간주)
  Future<bool> _isAutomaticallySetCoverPhoto(
    String categoryId,
    String currentCoverPhotoUrl,
  ) async {
    try {
      // 카테고리의 모든 사진을 조회
      final photos = await _photoRepository.getPhotosByCategory(categoryId);

      // 현재 대표사진이 카테고리의 사진 중 하나인지 확인
      final isFromCategoryPhoto = photos.any(
        (photo) => photo.imageUrl == currentCoverPhotoUrl,
      );

      // 카테고리의 사진 중 하나라면 자동 설정된 것으로 간주
      return isFromCategoryPhoto;
    } catch (e) {
      debugPrint('❌ 대표사진 자동 설정 여부 확인 실패: $e');
      // 오류 발생 시 안전하게 false 반환 (업데이트하지 않음)
      return false;
    }
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
