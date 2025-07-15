import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/photo_service.dart';
import '../models/photo_data_model.dart';

/// Photo Controller - UI와 비즈니스 로직을 연결하는 Controller
/// Service를 사용해서 UI 상태를 관리하고 사용자 피드백을 제공
class PhotoController extends ChangeNotifier {
  // 상태 변수들
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _error;

  List<PhotoDataModel> _photos = [];
  List<PhotoDataModel> _userPhotos = [];
  List<PhotoDataModel> _searchResults = [];
  PhotoDataModel? _selectedPhoto;
  Map<String, int> _photoStats = {};
  List<String> _popularTags = [];

  StreamSubscription<List<PhotoDataModel>>? _photosSubscription;

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final PhotoService _photoService = PhotoService();

  // Getters
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  List<PhotoDataModel> get photos => _photos;
  List<PhotoDataModel> get userPhotos => _userPhotos;
  List<PhotoDataModel> get searchResults => _searchResults;
  PhotoDataModel? get selectedPhoto => _selectedPhoto;
  Map<String, int> get photoStats => _photoStats;
  List<String> get popularTags => _popularTags;

  // ==================== 사진 업로드 ====================

  /// 사진 업로드 (이미지 + 오디오)
  Future<bool> uploadPhoto({
    required File imageFile,
    File? audioFile,
    required String categoryId,
    required String userId,
    required List<String> userIds,
  }) async {
    try {
      debugPrint('PhotoController: 업로드 시작');
      debugPrint('  - imageFile: ${imageFile.path}');
      debugPrint('  - audioFile: ${audioFile?.path ?? 'null'}');
      debugPrint('  - categoryId: $categoryId');
      debugPrint('  - userId: $userId');
      debugPrint('  - userIds: $userIds');

      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
      notifyListeners();

      // 파일 존재 여부 확인
      if (!await imageFile.exists()) {
        debugPrint('PhotoController: 이미지 파일이 존재하지 않습니다: ${imageFile.path}');
        throw Exception('이미지 파일이 존재하지 않습니다.');
      }

      if (audioFile != null && !await audioFile.exists()) {
        debugPrint('PhotoController: 오디오 파일이 존재하지 않습니다: ${audioFile.path}');
        // 오디오 파일은 선택사항이므로 null로 설정
        audioFile = null;
      }

      // 업로드 진행률 시뮬레이션
      _simulateUploadProgress();

      debugPrint('PhotoController: PhotoService.uploadPhoto 호출');
      final result = await _photoService.uploadPhoto(
        imageFile: imageFile,
        audioFile: audioFile,
        categoryId: categoryId,
        userId: userId,
        userIds: userIds,
      );

      _isUploading = false;
      _uploadProgress = 1.0;
      notifyListeners();

      debugPrint('PhotoController: 업로드 결과 - 성공: ${result.isSuccess}');
      if (!result.isSuccess) {
        debugPrint('PhotoController: 업로드 실패 이유: ${result.error}');
      }

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백
        debugPrint('사진이 성공적으로 업로드되었습니다.');

        // 사진 목록 새로고침
        await loadPhotosByCategory(categoryId);

        return true;
      } else {
        // ❌ 실패 시 UI 피드백
        _error = result.error;
        debugPrint(result.error ?? '사진 업로드에 실패했습니다.');
        return false;
      }
    } catch (e) {
      debugPrint('사진 업로드 컨트롤러 오류: $e');
      _isUploading = false;
      _uploadProgress = 0.0;
      _error = '사진 업로드 중 오류가 발생했습니다.';
      notifyListeners();

      // ❌ 에러 시 UI 피드백
      debugPrint('사진 업로드 중 오류가 발생했습니다.');
      return false;
    }
  }

  /// 단순 사진 업로드 (기존 호환성)
  Future<bool> uploadSimplePhoto({
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
    );
  }

  /// 사진 업로드 (파형 데이터 포함)
  Future<bool> uploadPhotoWithAudio({
    required String imageFilePath,
    required String audioFilePath,
    required String userID,
    required List<String> userIds,
    required String categoryId,
    List<double>? waveformData, // 파형 데이터 파라미터 추가
  }) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
      notifyListeners();

      // Service를 통해 업로드 (파형 데이터 전달)
      final photoId = await _photoService.savePhotoWithAudio(
        imageFilePath: imageFilePath,
        audioFilePath: audioFilePath,
        userID: userID,
        userIds: userIds,
        categoryId: categoryId,
        waveformData: waveformData, // 파형 데이터 전달
      );

      _isUploading = false;
      _uploadProgress = 1.0;
      notifyListeners();

      debugPrint('사진이 성공적으로 업로드되었습니다. ID: $photoId');
      return true;
    } catch (e) {
      debugPrint('사진 업로드 실패: $e');
      _isUploading = false;
      _error = '사진 업로드 중 오류가 발생했습니다.';
      notifyListeners();
      return false;
    }
  }

  // ==================== 사진 조회 ====================

  /// 카테고리별 사진 목록 로드
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
        debugPrint('사진이 없습니다.');
      }
    } catch (e) {
      debugPrint('카테고리별 사진 로드 오류: $e');
      _isLoading = false;
      _error = '사진을 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
      debugPrint('사진을 불러오는 중 오류가 발생했습니다. 다시 시도해주세요.');
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
            debugPrint('사진 스트림 오류: $error');
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
        debugPrint('사용자의 사진이 없습니다.');
      }
    } catch (e) {
      debugPrint('사용자별 사진 로드 오류: $e');
      _isLoading = false;
      _error = '사용자 사진을 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
      debugPrint('사용자 사진을 불러오는 중 오류가 발생했습니다. 다시 시도해주세요.');
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
        debugPrint('사진을 찾을 수 없습니다.');
      }
    } catch (e) {
      debugPrint('사진 상세 조회 오류: $e');
      _isLoading = false;
      _error = '사진 상세 정보를 불러오는 중 오류가 발생했습니다.';
      notifyListeners();
      debugPrint('사진 상세 정보를 불러오는 중 오류가 발생했습니다. 다시 시도해주세요.');
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
        debugPrint('사진 정보가 업데이트되었습니다.');

        // 사진 목록 새로고침
        await loadPhotosByCategory(categoryId);

        return true;
      } else {
        // ❌ 실패 시 UI 피드백
        debugPrint('사진 정보 업데이트에 실패했습니다. 다시 시도해주세요.');
        return false;
      }
    } catch (e) {
      debugPrint('사진 업데이트 컨트롤러 오류: $e');
      _isLoading = false;
      _error = '사진 업데이트 중 오류가 발생했습니다.';
      notifyListeners();
      debugPrint('사진 업데이트 중 오류가 발생했습니다. 다시 시도해주세요.');
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
      final success = await _photoService.togglePhotoLike(
        categoryId: categoryId,
        photoId: photoId,
        userId: userId,
      );

      if (success) {
        // ✅ 성공 시 UI 피드백 (토스트는 표시하지 않음 - UX 고려)

        // 현재 선택된 사진 업데이트
        if (_selectedPhoto?.id == photoId) {
          await loadPhotoDetails(
            categoryId: categoryId,
            photoId: photoId,
            viewerUserId: userId,
          );
        }

        // 사진 목록에서 해당 사진 업데이트
        final photoIndex = _photos.indexWhere((p) => p.id == photoId);
        if (photoIndex != -1) {
          await loadPhotosByCategory(categoryId);
        }

        return true;
      } else {
        debugPrint('좋아요 처리에 실패했습니다. 다시 시도해주세요.');
        return false;
      }
    } catch (e) {
      debugPrint('사진 좋아요 토글 오류: $e');
      debugPrint('좋아요 처리 중 오류가 발생했습니다. 다시 시도해주세요.');
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
        // ✅ 성공 시 UI 피드백
        final message = permanentDelete ? '사진이 완전히 삭제되었습니다.' : '사진이 삭제되었습니다.';
        debugPrint(message);

        // 사진 목록에서 제거
        _photos.removeWhere((photo) => photo.id == photoId);
        _userPhotos.removeWhere((photo) => photo.id == photoId);
        _searchResults.removeWhere((photo) => photo.id == photoId);

        // 선택된 사진이 삭제된 경우 초기화
        if (_selectedPhoto?.id == photoId) {
          _selectedPhoto = null;
        }

        notifyListeners();
        return true;
      } else {
        // ❌ 실패 시 UI 피드백
        debugPrint('사진 삭제에 실패했습니다. 다시 시도해주세요.');
        return false;
      }
    } catch (e) {
      debugPrint('사진 삭제 컨트롤러 오류: $e');
      _isLoading = false;
      _error = '사진 삭제 중 오류가 발생했습니다.';
      notifyListeners();
      debugPrint('사진 삭제 중 오류가 발생했습니다. 다시 시도해주세요.');
      return false;
    }
  }

  // ==================== 기존 호환성 메서드 ====================

  /// 기존 Map 형태로 사진 목록 조회 (호환성)
  Future<List<Map<String, dynamic>>> getCategoryPhotosAsMap(
    String categoryId,
  ) async {
    return await _photoService.getCategoryPhotosAsMap(categoryId);
  }

  /// 기존 Map 형태로 사진 스트림 (호환성)
  Stream<List<Map<String, dynamic>>> getCategoryPhotosStreamAsMap(
    String categoryId,
  ) {
    return _photoService.getCategoryPhotosStreamAsMap(categoryId);
  }

  // ==================== 통계 및 유틸리티 ====================

  /// 사진 통계 로드
  Future<void> loadPhotoStats(String categoryId) async {
    try {
      final stats = await _photoService.getPhotoStats(categoryId);
      _photoStats = stats;
      notifyListeners();
    } catch (e) {
      debugPrint('사진 통계 로드 오류: $e');
    }
  }

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 검색 결과 초기화
  void clearSearchResults() {
    _searchResults.clear();
    notifyListeners();
  }

  /// 선택된 사진 초기화
  void clearSelectedPhoto() {
    _selectedPhoto = null;
    notifyListeners();
  }

  // ==================== 내부 유틸리티 메서드 ====================

  /// 업로드 진행률 시뮬레이션
  void _simulateUploadProgress() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isUploading) {
        timer.cancel();
        return;
      }

      _uploadProgress += 0.05;
      if (_uploadProgress >= 0.9) {
        timer.cancel();
      }
      notifyListeners();
    });
  }

  // ==================== 파형 데이터 업데이트 유틸리티 ====================

  /// 기존 사진들에 파형 데이터 추가 (개발/유틸리티용)
  Future<bool> updateWaveformDataForExistingPhotos(String categoryId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('PhotoController: 기존 사진들의 파형 데이터 업데이트 시작');
      await _photoService.updateWaveformDataForExistingPhotos(categoryId);

      _isLoading = false;
      notifyListeners();

      debugPrint('PhotoController: 파형 데이터 업데이트 완료');
      return true;
    } catch (e) {
      _isLoading = false;
      _error = '파형 데이터 업데이트 실패: $e';
      notifyListeners();
      debugPrint('PhotoController: 파형 데이터 업데이트 실패 - $e');
      return false;
    }
  }

  // ==================== 파형 데이터 유틸리티 ====================

  /// UI에서 파형 표시를 위한 데이터 압축
  List<double> compressWaveformForUI(
    List<double> waveformData, {
    int targetLength = 100,
  }) {
    try {
      return _photoService.compressWaveformForDisplay(
        waveformData,
        targetLength: targetLength,
      );
    } catch (e) {
      debugPrint('PhotoController: 파형 압축 오류 - $e');
      return waveformData;
    }
  }

  // ==================== 리소스 해제 ====================

  @override
  void dispose() {
    _photosSubscription?.cancel();
    super.dispose();
  }

  /// 카테고리별 사진 스트림 직접 반환 (StreamBuilder 용)
  Stream<List<PhotoDataModel>> getPhotosByCategoryStream(String categoryId) {
    debugPrint('📺 PhotoController: 사진 스트림 요청 - CategoryId: $categoryId');
    return _photoService.getPhotosByCategoryStream(categoryId);
  }
}
