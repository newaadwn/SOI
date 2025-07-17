import 'dart:io';
import 'package:flutter/material.dart';
import '../repositories/audio_repository.dart';
import '../models/audio_data_model.dart';
import '../models/auth_result.dart';

/// 비즈니스 로직을 처리하는 Service
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
class AudioService {
  final AudioRepository _repository = AudioRepository();

  // ==================== 권한 관리 ====================

  /// 마이크 권한 상태 확인
  Future<bool> checkMicrophonePermission() async {
    return await AudioRepository.checkMicrophonePermission();
  }

  /// 마이크 권한 요청
  Future<bool> requestMicrophonePermission() async {
    return await AudioRepository.requestMicrophonePermission();
  }

  // ==================== 비즈니스 로직 ====================

  /// 오디오 파일 이름 검증
  String? _validateAudioFileName(String fileName) {
    if (fileName.trim().isEmpty) {
      return '파일 이름을 입력해주세요.';
    }
    if (fileName.trim().length > 50) {
      return '파일 이름은 50글자 이하여야 합니다.';
    }
    return null;
  }

  /// 오디오 파일 크기 검증 (10MB 제한)
  bool _isValidFileSize(double fileSizeInMB) {
    return fileSizeInMB <= 10.0;
  }

  /// 오디오 녹음 시간 검증 (최대 5분)
  bool _isValidDuration(int durationInSeconds) {
    return durationInSeconds <= 300; // 5분
  }

  /// 파일 이름 정규화
  String _normalizeFileName(String fileName) {
    return fileName.trim().replaceAll(RegExp(r'[^\w\s-.]'), '');
  }

  // ==================== 초기화 ====================

  /// 서비스 초기화
  Future<AuthResult> initialize() async {
    try {
      // 1. 권한 확인
      final micPermission = await AudioRepository.requestMicrophonePermission();
      if (!micPermission) {
        return AuthResult.failure('마이크 권한이 필요합니다.');
      }

      final storagePermission = await _repository.requestStoragePermission();
      if (!storagePermission) {
        return AuthResult.failure('저장소 권한이 필요합니다.');
      }

      // 2. 레코더 및 플레이어 초기화
      await _repository.initializeRecorder();
      await _repository.initializePlayer();

      // 3. 임시 파일 정리
      await _repository.cleanupTempFiles();

      return AuthResult.success();
    } catch (e) {
      debugPrint('오디오 서비스 초기화 오류: $e');
      return AuthResult.failure('오디오 서비스 초기화에 실패했습니다.');
    }
  }

  /// 서비스 종료
  Future<void> dispose() async {
    try {
      await _repository.disposeRecorder();
      await _repository.disposePlayer();
    } catch (e) {
      debugPrint('오디오 서비스 종료 오류: $e');
    }
  }

  // ==================== 네이티브 녹음 관리 ====================

  /// 네이티브 녹음 시작
  Future<AuthResult> startRecording() async {
    try {
      if (await AudioRepository.isRecording()) {
        return AuthResult.failure('이미 녹음이 진행 중입니다.');
      }

      final recordingPath = await AudioRepository.startRecording();

      if (recordingPath.isEmpty) {
        return AuthResult.failure('네이티브 녹음을 시작할 수 없습니다.');
      }

      debugPrint('네이티브 녹음 시작됨: $recordingPath');
      return AuthResult.success(recordingPath);
    } catch (e) {
      debugPrint('네이티브 녹음 시작 오류: $e');
      return AuthResult.failure('네이티브 녹음을 시작할 수 없습니다.');
    }
  }

  /// 네이티브 녹음 중지 및 데이터 생성
  Future<AuthResult> stopRecording({
    required String categoryId,
    required String userId,
    String? description,
  }) async {
    try {
      if (!await AudioRepository.isRecording()) {
        return AuthResult.failure('진행 중인 녹음이 없습니다.');
      }

      final recordingPath = await AudioRepository.stopRecording();
      if (recordingPath == null || recordingPath.isEmpty) {
        return AuthResult.failure('네이티브 녹음 파일을 저장할 수 없습니다.');
      }

      debugPrint('네이티브 녹음 완료: $recordingPath');

      // 파일 존재 여부 확인
      final file = File(recordingPath);
      if (!await file.exists()) {
        return AuthResult.failure('녹음된 파일이 존재하지 않습니다.');
      }

      // 파일 정보 수집
      final fileSize = await _repository.getFileSize(recordingPath);
      final duration = await _repository.getAudioDuration(recordingPath);

      debugPrint('📊 녹음 파일 정보: ${fileSize.toStringAsFixed(2)}MB, ${duration}초');

      // 비즈니스 규칙 검증
      if (!_isValidFileSize(fileSize)) {
        await _repository.deleteLocalFile(recordingPath);
        return AuthResult.failure('파일 크기가 너무 큽니다. (최대 10MB)');
      }

      if (!_isValidDuration(duration)) {
        await _repository.deleteLocalFile(recordingPath);
        return AuthResult.failure('녹음 시간이 너무 깁니다. (최대 5분)');
      }

      // AudioDataModel 생성
      final fileName =
          'native_recording_${DateTime.now().millisecondsSinceEpoch}';
      final audioData = AudioDataModel(
        id: '', // Repository에서 생성됨
        categoryId: categoryId,
        userId: userId,
        fileName: _normalizeFileName(fileName),
        originalPath: recordingPath,
        durationInSeconds: duration,
        fileSizeInMB: fileSize,
        format: AudioFormat.m4a, // 네이티브에서 AAC/M4A 생성
        status: AudioStatus.recorded,
        createdAt: DateTime.now(),
        description: description,
      );

      // Firestore에 저장
      final audioId = await _repository.saveAudioData(audioData);
      final savedAudio = audioData.copyWith(id: audioId);

      debugPrint('네이티브 녹음 데이터 저장 완료: $audioId');
      return AuthResult.success(savedAudio);
    } catch (e) {
      debugPrint('네이티브 녹음 중지 오류: $e');
      return AuthResult.failure('네이티브 녹음을 완료할 수 없습니다.');
    }
  }

  /// 간단한 네이티브 녹음 중지 (UI용)
  Future<AuthResult> stopRecordingSimple() async {
    try {
      final filePath = await AudioRepository.stopRecording();

      if (filePath != null && filePath.isNotEmpty) {
        debugPrint('간단 녹음 중지: $filePath');
        return AuthResult.success(filePath);
      } else {
        return AuthResult.failure('네이티브 녹음 중지 실패');
      }
    } catch (e) {
      debugPrint('간단 녹음 중지 오류: $e');
      return AuthResult.failure('네이티브 녹음 중지 중 오류 발생: $e');
    }
  }

  /// 네이티브 녹음 일시정지 (UI용)
  Future<AuthResult> pauseRecording() async {
    try {
      debugPrint('네이티브 녹음 일시정지 요청...');
      // 네이티브 녹음의 일시정지는 플랫폼별로 제한적일 수 있음
      // 현재는 성공으로 반환하여 UI 상태만 관리
      return AuthResult.success();
    } catch (e) {
      debugPrint('네이티브 녹음 일시정지 오류: $e');
      return AuthResult.failure('네이티브 녹음 일시정지 중 오류 발생: $e');
    }
  }

  /// 네이티브 녹음 재개 (UI용)
  Future<AuthResult> resumeRecording() async {
    try {
      debugPrint('네이티브 녹음 재개 요청...');
      // 네이티브 녹음의 재개는 플랫폼별로 제한적일 수 있음
      // 현재는 성공으로 반환하여 UI 상태만 관리
      return AuthResult.success();
    } catch (e) {
      debugPrint('네이티브 녹음 재개 오류: $e');
      return AuthResult.failure('네이티브 녹음 재개 중 오류 발생: $e');
    }
  }

  /// 녹음 상태 확인
  Future<bool> get isRecording => AudioRepository.isRecording();

  // 네이티브 녹음에서는 녹음 진행률 스트림이 제한됨

  // ==================== 재생 관리 ====================

  /// 오디오 재생
  Future<AuthResult> playAudio(AudioDataModel audio) async {
    try {
      if (_repository.isPlaying) {
        await _repository.stopPlaying();
      }

      // 로컬 파일이 있으면 로컬에서 재생, 없으면 URL에서 재생
      if (audio.originalPath.isNotEmpty &&
          File(audio.originalPath).existsSync()) {
        await _repository.playFromFile(audio.originalPath);
      } else if (audio.firebaseUrl != null) {
        await _repository.playFromUrl(audio.firebaseUrl!);
      } else {
        return AuthResult.failure('재생할 수 있는 오디오 파일이 없습니다.');
      }

      return AuthResult.success();
    } catch (e) {
      debugPrint('오디오 재생 오류: $e');
      return AuthResult.failure('오디오를 재생할 수 없습니다.');
    }
  }

  /// 재생 중지
  Future<AuthResult> stopPlaying() async {
    try {
      await _repository.stopPlaying();
      return AuthResult.success();
    } catch (e) {
      debugPrint('재생 중지 오류: $e');
      return AuthResult.failure('재생을 중지할 수 없습니다.');
    }
  }

  /// 재생 일시정지
  Future<AuthResult> pausePlaying() async {
    try {
      await _repository.pausePlaying();
      return AuthResult.success();
    } catch (e) {
      debugPrint('재생 일시정지 오류: $e');
      return AuthResult.failure('재생을 일시정지할 수 없습니다.');
    }
  }

  /// 재생 재개
  Future<AuthResult> resumePlaying() async {
    try {
      await _repository.resumePlaying();
      return AuthResult.success();
    } catch (e) {
      debugPrint('재생 재개 오류: $e');
      return AuthResult.failure('재생을 재개할 수 없습니다.');
    }
  }

  /// 재생 상태 확인
  bool get isPlaying => _repository.isPlaying;

  // 네이티브 재생에서는 재생 진행률 스트림이 제한됨

  // ==================== 업로드 관리 ====================

  /// 오디오 파일 업로드
  Future<AuthResult> uploadAudio(String audioId) async {
    try {
      final audioData = await _repository.getAudioData(audioId);
      if (audioData == null) {
        return AuthResult.failure('오디오 데이터를 찾을 수 없습니다.');
      }

      if (!audioData.canUpload) {
        return AuthResult.failure('업로드할 수 없는 상태입니다.');
      }

      // 업로드할 파일 경로 결정 (변환된 파일이 있으면 변환된 파일, 없으면 원본)
      final uploadPath =
          audioData.convertedPath?.isNotEmpty == true
              ? audioData.convertedPath!
              : audioData.originalPath;

      if (!File(uploadPath).existsSync()) {
        return AuthResult.failure('업로드할 파일이 존재하지 않습니다.');
      }

      // 상태를 업로드 중으로 업데이트
      await _repository.updateAudioData(audioId, {
        'status': AudioStatus.uploading.name,
      });

      // Firebase Storage에 업로드
      final downloadUrl = await _repository.uploadAudioFile(
        audioId,
        uploadPath,
      );

      // 업로드 완료 상태로 업데이트
      await _repository.updateAudioData(audioId, {
        'firebaseUrl': downloadUrl,
        'status': AudioStatus.uploaded.name,
        'uploadedAt': DateTime.now(),
      });

      return AuthResult.success(downloadUrl);
    } catch (e) {
      debugPrint('업로드 오류: $e');
      await _repository.updateAudioData(audioId, {
        'status': AudioStatus.failed.name,
      });
      return AuthResult.failure('업로드 중 오류가 발생했습니다.');
    }
  }

  /// 업로드 진행률 스트림
  Stream<double> getUploadProgressStream(String audioId, String filePath) {
    return _repository
        .getUploadProgressStream(audioId, filePath)
        .map((snapshot) => snapshot.bytesTransferred / snapshot.totalBytes);
  }

  // ==================== 데이터 관리 ====================

  /// 오디오 데이터 조회
  Future<AudioDataModel?> getAudioData(String audioId) async {
    return await _repository.getAudioData(audioId);
  }

  /// 카테고리별 오디오 목록 조회
  Future<List<AudioDataModel>> getAudiosByCategory(String categoryId) async {
    return await _repository.getAudiosByCategory(categoryId);
  }

  /// 사용자별 오디오 목록 조회
  Future<List<AudioDataModel>> getAudiosByUser(String userId) async {
    return await _repository.getAudiosByUser(userId);
  }

  /// 카테고리별 오디오 스트림
  Stream<List<AudioDataModel>> getAudiosByCategoryStream(String categoryId) {
    return _repository.getAudiosByCategoryStream(categoryId);
  }

  /// 오디오 삭제
  Future<AuthResult> deleteAudio(String audioId) async {
    try {
      final audioData = await _repository.getAudioData(audioId);
      if (audioData == null) {
        return AuthResult.failure('삭제할 오디오를 찾을 수 없습니다.');
      }

      // Firebase Storage에서 파일 삭제
      if (audioData.firebaseUrl != null) {
        await _repository.deleteAudioFile(audioData.firebaseUrl!);
      }

      // 로컬 파일들 삭제
      if (audioData.originalPath.isNotEmpty) {
        await _repository.deleteLocalFile(audioData.originalPath);
      }
      if (audioData.convertedPath != null &&
          audioData.convertedPath!.isNotEmpty) {
        await _repository.deleteLocalFile(audioData.convertedPath!);
      }

      // Firestore에서 데이터 삭제
      await _repository.deleteAudioData(audioId);

      return AuthResult.success();
    } catch (e) {
      debugPrint('오디오 삭제 오류: $e');
      return AuthResult.failure('오디오 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 오디오 정보 업데이트
  Future<AuthResult> updateAudioInfo({
    required String audioId,
    String? fileName,
    String? description,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (fileName != null) {
        final validationError = _validateAudioFileName(fileName);
        if (validationError != null) {
          return AuthResult.failure(validationError);
        }
        updateData['fileName'] = _normalizeFileName(fileName);
      }

      if (description != null) {
        updateData['description'] = description;
      }

      if (updateData.isEmpty) {
        return AuthResult.failure('업데이트할 내용이 없습니다.');
      }

      await _repository.updateAudioData(audioId, updateData);
      return AuthResult.success();
    } catch (e) {
      debugPrint('오디오 정보 업데이트 오류: $e');
      return AuthResult.failure('오디오 정보 업데이트 중 오류가 발생했습니다.');
    }
  }

  /// 오디오 파일에서 파형 데이터 추출
  Future<List<double>> extractWaveformData(String audioFilePath) async {
    return await _repository.extractWaveformData(audioFilePath);
  }

  /// 오디오 길이 계산
  Future<double> getAudioDuration(String audioFilePath) async {
    return await _repository.getAudioDurationAccurate(audioFilePath);
  }
}
