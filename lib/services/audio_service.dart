import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../repositories/audio_repository.dart';
import '../models/audio_data_model.dart';
import '../models/auth_result.dart';

/// 비즈니스 로직을 처리하는 Service
/// Repository를 사용해서 실제 비즈니스 규칙을 적용
/// AudioConverterService 기능을 통합
class AudioService {
  final AudioRepository _repository = AudioRepository();

  // AudioConverter 기능을 위한 MethodChannel
  /*static const MethodChannel _converterChannel = MethodChannel(
    'com.app.audio_converter',
  );*/

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
      final micPermission = await AudioRepository.requestPermission();
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

  // ==================== 녹음 관리 ====================

  /// 녹음 시작
  Future<AuthResult> startRecording() async {
    try {
      if (await AudioRepository.isRecording()) {
        return AuthResult.failure('이미 녹음이 진행 중입니다.');
      }

      final recordingPath = await AudioRepository.startRecording();
      return AuthResult.success(recordingPath);
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
      return AuthResult.failure('녹음을 시작할 수 없습니다.');
    }
  }

  /// 녹음 중지 및 데이터 생성
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
      if (recordingPath == null) {
        return AuthResult.failure('녹음 파일을 저장할 수 없습니다.');
      }

      // 파일 정보 수집
      final fileSize = await _repository.getFileSize(recordingPath);
      final duration = await _repository.getAudioDuration(recordingPath);

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
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}';
      final audioData = AudioDataModel(
        id: '', // Repository에서 생성됨
        categoryId: categoryId,
        userId: userId,
        fileName: _normalizeFileName(fileName),
        originalPath: recordingPath,
        durationInSeconds: duration,
        fileSizeInMB: fileSize,
        format: AudioFormat.m4a,
        status: AudioStatus.recorded,
        createdAt: DateTime.now(),
        description: description,
      );

      // Firestore에 저장
      final audioId = await _repository.saveAudioData(audioData);
      final savedAudio = audioData.copyWith(id: audioId);

      return AuthResult.success(savedAudio);
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
      return AuthResult.failure('녹음을 완료할 수 없습니다.');
    }
  }

  /// 간단한 녹음 중지 (업로드 없이)
  Future<AuthResult> stopRecordingSimple() async {
    try {
      final filePath = await AudioRepository.stopRecording();

      if (filePath != null) {
        return AuthResult.success(filePath);
      } else {
        return AuthResult.failure('녹음 중지 실패');
      }
    } catch (e) {
      return AuthResult.failure('녹음 중지 중 오류 발생: $e');
    }
  }

  /// 녹음 상태 확인
  Future<bool> get isRecording => AudioRepository.isRecording();

  /// 녹음 진행률 스트림
  Stream<RecordingDisposition>? get recordingStream =>
      _repository.recordingStream;

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

  /// 재생 진행률 스트림
  Stream<PlaybackDisposition>? get playbackStream => _repository.playbackStream;

  // ==================== 오디오 변환 (AudioConverter 통합) ====================

  /// AAC/M4A 파일을 MP3로 변환
  /*Future<AuthResult> convertToMp3(String audioId) async {
    try {
      final audioData = await _repository.getAudioData(audioId);
      if (audioData == null) {
        return AuthResult.failure('오디오 데이터를 찾을 수 없습니다.');
      }

      if (audioData.originalPath.isEmpty ||
          !File(audioData.originalPath).existsSync()) {
        return AuthResult.failure('변환할 파일이 존재하지 않습니다.');
      }

      // 상태를 변환 중으로 업데이트
      await _repository.updateAudioData(audioId, {
        'status': AudioStatus.converting.name,
      });

      // 네이티브에서 변환 수행
      final convertedPath =
          await _converterChannel.invokeMethod('convertAudioToMp3', {
                'inputPath': audioData.originalPath,
              })
              as String;

      // 변환 완료 상태로 업데이트
      await _repository.updateAudioData(audioId, {
        'convertedPath': convertedPath,
        'status': AudioStatus.converted.name,
        'format': AudioFormat.mp3.name,
      });

      return AuthResult.success(convertedPath);
    } on PlatformException catch (e) {
      debugPrint('MP3 변환 오류: ${e.message}');
      await _repository.updateAudioData(audioId, {
        'status': AudioStatus.failed.name,
      });
      return AuthResult.failure('MP3 변환에 실패했습니다: ${e.message}');
    } catch (e) {
      debugPrint('MP3 변환 오류: $e');
      await _repository.updateAudioData(audioId, {
        'status': AudioStatus.failed.name,
      });
      return AuthResult.failure('MP3 변환 중 오류가 발생했습니다.');
    }
  }*/

  /// 오디오 파일을 AAC 포맷으로 변환
  /*Future<AuthResult> convertToAAC(String audioId) async {
    try {
      final audioData = await _repository.getAudioData(audioId);
      if (audioData == null) {
        return AuthResult.failure('오디오 데이터를 찾을 수 없습니다.');
      }

      if (audioData.originalPath.isEmpty ||
          !File(audioData.originalPath).existsSync()) {
        return AuthResult.failure('변환할 파일이 존재하지 않습니다.');
      }

      // 상태를 변환 중으로 업데이트
      await _repository.updateAudioData(audioId, {
        'status': AudioStatus.converting.name,
      });

      // 네이티브에서 변환 수행
      final convertedPath =
          await _converterChannel.invokeMethod('convertAudioToAAC', {
                'inputPath': audioData.originalPath,
              })
              as String;

      // 변환 완료 상태로 업데이트
      await _repository.updateAudioData(audioId, {
        'convertedPath': convertedPath,
        'status': AudioStatus.converted.name,
        'format': AudioFormat.aac.name,
      });

      return AuthResult.success(convertedPath);
    } on PlatformException catch (e) {
      debugPrint('AAC 변환 오류: ${e.message}');
      await _repository.updateAudioData(audioId, {
        'status': AudioStatus.failed.name,
      });
      return AuthResult.failure('AAC 변환에 실패했습니다: ${e.message}');
    } catch (e) {
      debugPrint('AAC 변환 오류: $e');
      await _repository.updateAudioData(audioId, {
        'status': AudioStatus.failed.name,
      });
      return AuthResult.failure('AAC 변환 중 오류가 발생했습니다.');
    }
  }*/

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

      // 로컬 파일 정리 (옵션)
      // await _repository.deleteLocalFile(uploadPath);

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
}
