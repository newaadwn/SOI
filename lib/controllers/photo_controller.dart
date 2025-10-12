import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/photo_service.dart';
import '../models/photo_data_model.dart';

/// Photo Controller - UI와 비즈니스 로직을 연결하는 Controller
/// Service를 사용해서 UI 상태를 관리하고 사용자 피드백을 제공
class PhotoController extends ChangeNotifier {
  // 기본 상태 변수들
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _error;

  List<PhotoDataModel> _photos = [];
  List<PhotoDataModel> _userPhotos = [];
  PhotoDataModel? _selectedPhoto;
  Map<String, int> _photoStats = {};

  // 무한 스크롤 페이지네이션 상태
  bool _hasMore = true;
  bool _isLoadingMore = false;
  String? _lastPhotoId;
  static const int _initialLoadSize = 10; // 사용자 경험 개선을 위해 10개로 증가
  static const int _pageSize = 10;

  StreamSubscription<List<PhotoDataModel>>? _photosSubscription;

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final PhotoService _photoService = PhotoService();

  // Getters - 기본
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  List<PhotoDataModel> get photos => _photos;
  List<PhotoDataModel> get userPhotos => _userPhotos;
  PhotoDataModel? get selectedPhoto => _selectedPhoto;
  Map<String, int> get photoStats => _photoStats;

  // Getters - 페이지네이션
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get lastPhotoId => _lastPhotoId;

  // ==================== 사진 업로드 ====================

  /// 사진 업로드
  Future<bool> uploadPhoto({
    required File imageFile,
    File? audioFile,
    required String categoryId,
    required String userId,
    required List<String> userIds,
    String? caption,
  }) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
      notifyListeners();

      // 파일 존재 여부 확인
      if (!await imageFile.exists()) {
        // debugPrint('PhotoController: 이미지 파일이 존재하지 않습니다: ${imageFile.path}');
        throw Exception('이미지 파일이 존재하지 않습니다.');
      }

      if (audioFile != null && !await audioFile.exists()) {
        // debugPrint('PhotoController: 오디오 파일이 존재하지 않습니다: ${audioFile.path}');
        // 오디오 파일은 선택사항이므로 null로 설정
        audioFile = null;
      }

      // debugPrint('PhotoController: PhotoService.uploadPhoto 호출');
      final result = await _photoService.uploadPhoto(
        imageFile: imageFile,
        audioFile: audioFile,
        categoryId: categoryId,
        userId: userId,
        userIds: userIds,
        caption: caption,
      );

      _isUploading = false;
      _uploadProgress = 1.0;
      notifyListeners();

      if (result.isSuccess) {
        // 사진 목록 새로고침
        await loadPhotosByCategory(categoryId);

        return true;
      } else {
        // ❌ 실패 시 UI 피드백
        _error = result.error;

        return false;
      }
    } catch (e) {
      _isUploading = false;
      _uploadProgress = 0.0;
      _error = '사진 업로드 중 오류가 발생했습니다.';
      notifyListeners();

      return false;
    }
  }

  /// 사진 업로드 (파형 데이터 포함)
  Future<bool> uploadPhotoWithAudio({
    required String imageFilePath,
    required String audioFilePath,
    required String userID,
    required List<String> userIds,
    required String categoryId,
    List<double>? waveformData, // 파형 데이터 파라미터 추가
    Duration? duration, // 음성 길이 파라미터 추가
  }) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
      notifyListeners();

      // Service를 통해 업로드 (파형 데이터 전달) - 완료를 기다림
      final photoId = await _photoService.savePhotoWithAudio(
        imageFilePath: imageFilePath,
        audioFilePath: audioFilePath,
        userID: userID,
        userIds: userIds,
        categoryId: categoryId,
        waveformData: waveformData, // 파형 데이터 전달
        duration: duration, // 음성 길이 전달
      );

      _isUploading = false;
      _uploadProgress = 1.0;
      notifyListeners();

      // debugPrint('사진이 성공적으로 업로드되었습니다. ID: $photoId');
      return photoId.isNotEmpty;
    } catch (e) {
      // debugPrint('사진 업로드 실패: $e');
      _isUploading = false;
      _error = '사진 업로드 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  /// 모든 카테고리에서 사진 초기 로드 (무한 스크롤용)
  Future<void> loadPhotosFromAllCategoriesInitial(
    List<String> categoryIds,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      _hasMore = true;
      _lastPhotoId = null;
      _photos.clear(); // 초기 로드이므로 기존 데이터 클리어
      notifyListeners();

      // debugPrint('📱 초기 사진 로드 시작 - 카테고리: ${categoryIds.length}개');

      final result = await _photoService.getPhotosFromAllCategoriesPaginated(
        categoryIds: categoryIds,
        limit: _initialLoadSize,
      );

      _photos = result.photos;
      _lastPhotoId = result.lastPhotoId;
      _hasMore = result.hasMore;
      _isLoading = false;
      notifyListeners();

      // debugPrint('✅ 초기 사진 로드 완료: ${_photos.length}개, 더 있음: $_hasMore');
    } catch (e) {
      // debugPrint('❌ 초기 사진 로드 오류: $e');
      _isLoading = false;
      _error = '사진을 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// 다음 페이지 사진 로드 (무한 스크롤용)
  Future<void> loadMorePhotos(List<String> categoryIds) async {
    if (_isLoadingMore || !_hasMore) {
      // debugPrint('⚠️ 이미 로딩 중이거나 더 이상 로드할 사진이 없습니다.');
      return;
    }

    try {
      _isLoadingMore = true;
      _error = null;
      notifyListeners();

      // debugPrint('📱 추가 사진 로드 시작 - 마지막 ID: $_lastPhotoId');

      final result = await _photoService.getPhotosFromAllCategoriesPaginated(
        categoryIds: categoryIds,
        limit: _pageSize,
        startAfterPhotoId: _lastPhotoId,
      );

      // 기존 사진 목록에 새로운 사진들 추가
      _photos.addAll(result.photos);
      _lastPhotoId = result.lastPhotoId;
      _hasMore = result.hasMore;
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      // debugPrint('❌ 추가 사진 로드 오류: $e');
      _isLoadingMore = false;
      _error = '추가 사진을 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// 카테고리별 사진 목록 로드 (기존 호환성 유지)
  Future<void> loadPhotosByCategory(String categoryId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final photos = await _photoService.getPhotosByCategory(categoryId);

      _photos = photos;
      _isLoading = false;
      notifyListeners();

      if (photos.isEmpty) {
        // debugPrint('사진이 없습니다.');
      }
    } catch (e) {
      // debugPrint('카테고리별 사진 로드 오류: $e');
      _isLoading = false;
      _error = '사진을 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
      // debugPrint('사진을 불러오는 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  /// 카테고리별 사진 스트림 시작 (실시간)
  void startPhotosStream(String categoryId) {
    _photosSubscription?.cancel();
    _photosSubscription = _photoService
        .getPhotosByCategoryStream(categoryId)
        .listen(
          (photos) {
            _photos = photos;
            notifyListeners();
          },
          onError: (error) {
            // debugPrint('사진 스트림 오류: $error');
            _error = '실시간 사진 업데이트 중 오류가 발생했습니다.';
            notifyListeners();
          },
        );
  }

  /// 사진 스트림 중지
  void stopPhotosStream() {
    _photosSubscription?.cancel();
    _photosSubscription = null;
  }

  /// 사용자별 사진 목록 로드
  Future<void> loadPhotosByUser(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final photos = await _photoService.getPhotosByUser(userId);

      _userPhotos = photos;
      _isLoading = false;
      notifyListeners();

      if (photos.isEmpty) {
        // debugPrint('사용자의 사진이 없습니다.');
      }
    } catch (e) {
      // debugPrint('사용자별 사진 로드 오류: $e');
      _isLoading = false;
      _error = '사용자 사진을 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
      // debugPrint('사용자 사진을 불러오는 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  /// 사진 상세 조회
  Future<void> loadPhotoDetails({
    required String categoryId,
    required String photoId,
    String? viewerUserId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final photo = await _photoService.getPhotoDetails(
        categoryId: categoryId,
        photoId: photoId,
        viewerUserId: viewerUserId,
      );

      _selectedPhoto = photo;
      _isLoading = false;
      notifyListeners();

      if (photo == null) {
        // debugPrint('사진을 찾을 수 없습니다.');
      }
    } catch (e) {
      // debugPrint('사진 상세 조회 오류: $e');
      _isLoading = false;
      _error = '사진 상세 정보를 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
      // debugPrint('사진 상세 정보를 불러오는 중 오류가 발생했습니다. 다시 시도해주세요.');
    }
  }

  // ==================== 사진 업데이트 ====================

  /// 사진 정보 업데이트
  Future<bool> updatePhoto({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _photoService.updatePhoto(
        categoryId: categoryId,
        photoId: photoId,
        userId: userId,
      );

      _isLoading = false;
      notifyListeners();

      if (success) {
        // ✅ 성공 시 UI 피드백
        // debugPrint('사진 정보가 업데이트되었습니다.');

        // 사진 목록 새로고침
        await loadPhotosByCategory(categoryId);

        return true;
      } else {
        // ❌ 실패 시 UI 피드백
        // debugPrint('사진 정보 업데이트에 실패했습니다. 다시 시도해주세요.');
        return false;
      }
    } catch (e) {
      // debugPrint('사진 업데이트 컨트롤러 오류: $e');
      _isLoading = false;
      _error = '사진 업데이트 중 오류가 발생했습니다.';
      notifyListeners();
      // debugPrint('사진 업데이트 중 오류가 발생했습니다. 다시 시도해주세요.');
      return false;
    }
  }

  // ==================== 사진 삭제 ====================

  /// 사진 삭제
  Future<bool> deletePhoto({
    required String categoryId,
    required String photoId,
    required String userId,
    bool permanentDelete = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _photoService.deletePhoto(
        categoryId: categoryId,
        photoId: photoId,
        userId: userId,
        permanentDelete: permanentDelete,
      );

      _isLoading = false;
      notifyListeners();

      if (success) {
        // 사진 목록에서 제거
        _photos.removeWhere((photo) => photo.id == photoId);
        _userPhotos.removeWhere((photo) => photo.id == photoId);

        // 선택된 사진이 삭제된 경우 초기화
        if (_selectedPhoto?.id == photoId) {
          _selectedPhoto = null;
        }

        notifyListeners();
        return true;
      } else {
        // ❌ 실패 시 UI 피드백
        // debugPrint('사진 삭제에 실패했습니다. 다시 시도해주세요.');
        return false;
      }
    } catch (e) {
      // debugPrint('사진 삭제 컨트롤러 오류: $e');
      _isLoading = false;
      _error = '사진 삭제 중 오류가 발생했습니다.';
      notifyListeners();
      // debugPrint('사진 삭제 중 오류가 발생했습니다. 다시 시도해주세요.');
      return false;
    }
  }

  // ==================== 삭제된 사진 관리 ====================

  List<PhotoDataModel> _deletedPhotos = [];

  /// 삭제된 사진 목록 getter
  List<PhotoDataModel> get deletedPhotos => _deletedPhotos;

  /// 사용자의 삭제된 사진 목록 로드
  Future<void> loadDeletedPhotosByUser(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final deletedPhotos = await _photoService.getDeletedPhotosByUser(userId);

      _deletedPhotos = deletedPhotos;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('PhotoController: 삭제된 사진 로드 오류 - $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 사진 복원
  Future<bool> restorePhoto({
    required String categoryId,
    required String photoId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await _photoService.restorePhoto(
        categoryId: categoryId,
        photoId: photoId,
        userId: userId,
      );

      _isLoading = false;
      notifyListeners();

      if (success) {
        // 삭제된 사진 목록에서 제거
        _deletedPhotos.removeWhere((photo) => photo.id == photoId);
        notifyListeners();

        return true;
      } else {
        _error = '사진 복원에 실패했습니다.';
        return false;
      }
    } catch (e) {
      debugPrint('PhotoController: 사진 복원 오류 - $e');
      _isLoading = false;
      _error = '사진 복원 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  // ==================== 기존 호환성 메서드 ====================

  // ==================== 통계 및 유틸리티 ====================

  /// 사진 통계 로드
  Future<void> loadPhotoStats(String categoryId) async {
    try {
      final stats = await _photoService.getPhotoStats(categoryId);
      _photoStats = stats;
      notifyListeners();
    } catch (e) {
      // debugPrint('사진 통계 로드 오류: $e');
    }
  }

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 선택된 사진 초기화
  void clearSelectedPhoto() {
    _selectedPhoto = null;
    notifyListeners();
  }

  // ==================== 리소스 해제 ====================

  @override
  void dispose() {
    _photosSubscription?.cancel();
    super.dispose();
  }

  /// 카테고리별 사진 스트림 직접 반환 (StreamBuilder 용)
  Stream<List<PhotoDataModel>> getPhotosByCategoryStream(String categoryId) {
    // debugPrint('📺 PhotoController: 사진 스트림 요청 - CategoryId: $categoryId');
    return _photoService.getPhotosByCategoryStream(categoryId);
  }

  /// 특정 사진을 직접 조회 (알림에서 사용)
  Future<PhotoDataModel?> getPhotoById({
    required String categoryId,
    required String photoId,
  }) async {
    try {
      debugPrint(
        '📷 PhotoController: 특정 사진 조회 - CategoryId: $categoryId, PhotoId: $photoId',
      );
      return await _photoService.getPhotoById(
        categoryId: categoryId,
        photoId: photoId,
      );
    } catch (e) {
      debugPrint('❌ PhotoController: 사진 조회 실패 - $e');
      return null;
    }
  }

  /// 카테고리의 모든 사진을 직접 조회 (스트림이 아닌 일회성)
  Future<List<PhotoDataModel>> getPhotosByCategoryDirect(
    String categoryId,
  ) async {
    try {
      debugPrint('📷 PhotoController: 카테고리 사진 직접 조회 - CategoryId: $categoryId');
      return await _photoService.getPhotosByCategory(categoryId);
    } catch (e) {
      debugPrint('❌ PhotoController: 카테고리 사진 조회 실패 - $e');
      return [];
    }
  }
}
