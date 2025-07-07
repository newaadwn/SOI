import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/audio_service.dart';
import '../models/audio_data_model.dart';

/// 오디오 관련 UI와 비즈니스 로직 사이의 중개 역할을 합니다.
class AudioController extends ChangeNotifier {
  // 상태 변수들
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _currentRecordingPath;
  String? _currentPlayingAudioId;
  int _recordingDuration = 0;
  double _recordingLevel = 0.0;
  double _playbackPosition = 0.0;
  double _playbackDuration = 0.0;
  double _uploadProgress = 0.0;
  String? _error;

  List<AudioDataModel> _audioList = [];
  Timer? _recordingTimer;
  StreamSubscription<RecordingDisposition>? _recordingSubscription;
  StreamSubscription<PlaybackDisposition>? _playbackSubscription;
  StreamSubscription<double>? _uploadSubscription;

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final AudioService _audioService = AudioService();

  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get currentRecordingPath => _currentRecordingPath;
  String? get currentPlayingAudioId => _currentPlayingAudioId;
  int get recordingDuration => _recordingDuration;
  double get recordingLevel => _recordingLevel;
  double get playbackPosition => _playbackPosition;
  double get playbackDuration => _playbackDuration;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  List<AudioDataModel> get audioList => _audioList;

  // ==================== 초기화 ====================

  /// Controller 초기화
  Future<void> initialize() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _audioService.initialize();

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // ✅ 성공 시 UI 피드백
        debugPrint('오디오 기능이 준비되었습니다.');

        // 녹음 진행률 모니터링 시작
        _startRecordingMonitoring();
      } else {
        // ✅ 실패 시 UI 피드백
        _error = result.error;
        debugPrint(result.error ?? '오디오 초기화에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('오디오 컨트롤러 초기화 오류: $e');
      _isLoading = false;
      _error = '오디오 초기화 중 오류가 발생했습니다.';
      notifyListeners();
      debugPrint('오디오 초기화 중 오류가 발생했습니다.');
    }
  }

  /// Controller 종료
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recordingSubscription?.cancel();
    _playbackSubscription?.cancel();
    _uploadSubscription?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  // ==================== 녹음 관리 ====================

  /// 녹음 시작
  Future<void> startRecording() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final result = await _audioService.startRecording();

      if (result.isSuccess) {
        _isRecording = true;
        _currentRecordingPath = result.data as String?;
        _recordingDuration = 0;

        // 녹음 시간 타이머 시작
        _startRecordingTimer();

        _isLoading = false;
        notifyListeners();

        // ✅ 성공 시 UI 피드백
        debugPrint('녹음이 시작되었습니다.');
      } else {
        _isLoading = false;
        notifyListeners();

        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '녹음을 시작할 수 없습니다.');
      }
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('녹음 시작 중 오류가 발생했습니다.');
    }
  }

  /// 녹음 중지
  Future<void> stopRecording({
    required String categoryId,
    required String userId,
    String? description,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 타이머 및 구독 정리
      _stopRecordingTimer();

      final result = await _audioService.stopRecording(
        categoryId: categoryId,
        userId: userId,
        description: description,
      );

      _isRecording = false;
      _currentRecordingPath = null;
      _recordingDuration = 0;
      _recordingLevel = 0.0;
      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        final audioData = result.data as AudioDataModel;

        // 오디오 목록에 추가
        _audioList.insert(0, audioData);
        notifyListeners();

        // ✅ 성공 시 UI 피드백
        debugPrint('녹음이 완료되었습니다.');
      } else {
        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '녹음 완료에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
      _isRecording = false;
      _isLoading = false;
      notifyListeners();
      debugPrint('녹음 중지 중 오류가 발생했습니다.');
    }
  }

  /// 간단한 녹음 중지 (업로드 없이)
  Future<void> stopRecordingSimple() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 타이머 및 구독 정리
      _stopRecordingTimer();

      // 간단히 녹음만 중지
      final result = await _audioService.stopRecordingSimple();

      _isLoading = false;
      _isRecording = false;

      if (result.isSuccess) {
        _currentRecordingPath = result.data ?? '';
      } else {
        _error = result.error;
      }

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isRecording = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 녹음 시간 타이머 시작
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordingDuration++;
      notifyListeners();
    });
  }

  /// 녹음 시간 타이머 중지
  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  /// 녹음 진행률 모니터링 시작
  void _startRecordingMonitoring() {
    _recordingSubscription = _audioService.recordingStream?.listen((
      disposition,
    ) {
      _recordingLevel = disposition.decibels ?? 0.0;
      notifyListeners();
    });
  }

  /// 녹음 시간을 MM:SS 형식으로 포맷팅
  String get formattedRecordingDuration {
    final minutes = _recordingDuration ~/ 60;
    final seconds = _recordingDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ==================== 재생 관리 ====================

  /// 오디오 재생
  Future<void> playAudio(AudioDataModel audio) async {
    try {
      // 이미 재생 중인 오디오가 있으면 중지
      if (_isPlaying) {
        await stopPlaying();
      }

      _isLoading = true;
      notifyListeners();

      final result = await _audioService.playAudio(audio);

      if (result.isSuccess) {
        _isPlaying = true;
        _currentPlayingAudioId = audio.id;

        // 재생 진행률 모니터링 시작
        _startPlaybackMonitoring();

        _isLoading = false;
        notifyListeners();

        // ✅ 성공 시 UI 피드백
        debugPrint('재생을 시작합니다.');
      } else {
        _isLoading = false;
        notifyListeners();

        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '재생할 수 없습니다.');
      }
    } catch (e) {
      debugPrint('오디오 재생 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('재생 중 오류가 발생했습니다.');
    }
  }

  /// URL로 직접 오디오 재생 (기존 호환성)
  Future<void> playAudioFromUrl(String audioUrl) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 기존 재생 중지
      await stopPlaying();

      // 새로운 오디오 재생 (간단한 AudioPlayer 사용)
      final player = AudioPlayer();
      await player.play(UrlSource(audioUrl));

      _isLoading = false;
      _isPlaying = true;
      notifyListeners();

      // ✅ 성공 시 UI 피드백 (토스트는 생략 - UX 고려)
    } catch (e) {
      debugPrint('URL 오디오 재생 컨트롤러 오류: $e');
      _isLoading = false;
      _error = 'URL 오디오 재생 중 오류가 발생했습니다.';
      notifyListeners();
      debugPrint('URL 오디오 재생 중 오류가 발생했습니다.');
    }
  }

  /// 재생 중지
  Future<void> stopPlaying() async {
    try {
      final result = await _audioService.stopPlaying();

      _isPlaying = false;
      _currentPlayingAudioId = null;
      _playbackPosition = 0.0;
      _playbackDuration = 0.0;
      _playbackSubscription?.cancel();
      notifyListeners();

      if (!result.isSuccess) {
        debugPrint(result.error ?? '재생 중지에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('재생 중지 오류: $e');
      _isPlaying = false;
      notifyListeners();
    }
  }

  /// 재생 일시정지
  Future<void> pausePlaying() async {
    try {
      final result = await _audioService.pausePlaying();

      if (result.isSuccess) {
        _isPlaying = false;
        notifyListeners();
      } else {
        debugPrint(result.error ?? '일시정지에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('재생 일시정지 오류: $e');
    }
  }

  /// 재생 재개
  Future<void> resumePlaying() async {
    try {
      final result = await _audioService.resumePlaying();

      if (result.isSuccess) {
        _isPlaying = true;
        notifyListeners();
      } else {
        debugPrint(result.error ?? '재생 재개에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('재생 재개 오류: $e');
    }
  }

  /// 재생 진행률 모니터링 시작
  void _startPlaybackMonitoring() {
    _playbackSubscription = _audioService.playbackStream?.listen((disposition) {
      _playbackPosition = disposition.position.inSeconds.toDouble();
      _playbackDuration = disposition.duration.inSeconds.toDouble();
      notifyListeners();

      // 재생 완료 시 상태 초기화
      if (_playbackPosition >= _playbackDuration && _playbackDuration > 0) {
        _isPlaying = false;
        _currentPlayingAudioId = null;
        _playbackPosition = 0.0;
        notifyListeners();
      }
    });
  }

  // ==================== 오디오 변환 ====================

  /// MP3로 변환
  Future<void> convertToMp3(String audioId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _audioService.convertToMp3(audioId);

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 오디오 목록 업데이트
        await _refreshAudioData(audioId);

        // ✅ 성공 시 UI 피드백
        debugPrint('MP3 변환이 완료되었습니다.');
      } else {
        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? 'MP3 변환에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('MP3 변환 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('MP3 변환 중 오류가 발생했습니다.');
    }
  }

  /// AAC로 변환
  Future<void> convertToAAC(String audioId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _audioService.convertToAAC(audioId);

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 오디오 목록 업데이트
        await _refreshAudioData(audioId);

        // ✅ 성공 시 UI 피드백
        debugPrint('AAC 변환이 완료되었습니다.');
      } else {
        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? 'AAC 변환에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('AAC 변환 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('AAC 변환 중 오류가 발생했습니다.');
    }
  }

  // ==================== 업로드 관리 ====================

  /// 오디오 업로드
  Future<void> uploadAudio(String audioId) async {
    try {
      _isLoading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      // 업로드 진행률 모니터링
      final audioData = await _audioService.getAudioData(audioId);
      if (audioData != null) {
        final filePath =
            audioData.convertedPath?.isNotEmpty == true
                ? audioData.convertedPath!
                : audioData.originalPath;

        _uploadSubscription = _audioService
            .getUploadProgressStream(audioId, filePath)
            .listen((progress) {
              _uploadProgress = progress;
              notifyListeners();
            });
      }

      final result = await _audioService.uploadAudio(audioId);

      _isLoading = false;
      _uploadProgress = 0.0;
      _uploadSubscription?.cancel();
      notifyListeners();

      if (result.isSuccess) {
        // 오디오 목록 업데이트
        await _refreshAudioData(audioId);

        // ✅ 성공 시 UI 피드백
        debugPrint('업로드가 완료되었습니다.');
      } else {
        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '업로드에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('업로드 오류: $e');
      _isLoading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      debugPrint('업로드 중 오류가 발생했습니다.');
    }
  }

  /// 오디오 업로드를 위한 처리 (기존 호환성)
  Future<String> processAudioForUpload() async {
    try {
      if (_currentRecordingPath != null && _currentRecordingPath!.isNotEmpty) {
        // 현재 녹음된 파일이 있는 경우
        final audioFile = File(_currentRecordingPath!);
        if (await audioFile.exists()) {
          // 파일이 존재하면 업로드 처리
          await uploadAudio(_currentRecordingPath!);

          // 업로드된 오디오 URL 반환 (실제 구현에서는 업로드 결과를 받아야 함)
          // 임시로 현재 녹음 경로 반환
          return _currentRecordingPath!;
        }
      }

      // 녹음된 파일이 없는 경우 빈 문자열 반환
      return '';
    } catch (e) {
      debugPrint('오디오 업로드 처리 오류: $e');
      return '';
    }
  }

  // ==================== 데이터 관리 ====================

  /// 카테고리별 오디오 목록 로드
  Future<void> loadAudiosByCategory(String categoryId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _audioList = await _audioService.getAudiosByCategory(categoryId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('오디오 목록 로드 오류: $e');
      _error = '오디오 목록을 불러오는 중 오류가 발생했습니다.';
      _audioList = [];
      _isLoading = false;
      notifyListeners();

      debugPrint('오디오 목록을 불러오는 중 오류가 발생했습니다.');
    }
  }

  /// 사용자별 오디오 목록 로드
  Future<void> loadAudiosByUser(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _audioList = await _audioService.getAudiosByUser(userId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('사용자 오디오 목록 로드 오류: $e');
      _error = '오디오 목록을 불러오는 중 오류가 발생했습니다.';
      _audioList = [];
      _isLoading = false;
      notifyListeners();

      debugPrint('오디오 목록을 불러오는 중 오류가 발생했습니다.');
    }
  }

  /// 카테고리별 오디오 스트림
  Stream<List<AudioDataModel>> getAudiosByCategoryStream(String categoryId) {
    return _audioService.getAudiosByCategoryStream(categoryId);
  }

  /// 오디오 삭제
  Future<void> deleteAudio(String audioId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _audioService.deleteAudio(audioId);

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 오디오 목록에서 제거
        _audioList.removeWhere((audio) => audio.id == audioId);
        notifyListeners();

        // ✅ 성공 시 UI 피드백
        debugPrint('오디오가 삭제되었습니다.');
      } else {
        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '오디오 삭제에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('오디오 삭제 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('오디오 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 오디오 정보 업데이트
  Future<void> updateAudioInfo({
    required String audioId,
    String? fileName,
    String? description,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await _audioService.updateAudioInfo(
        audioId: audioId,
        fileName: fileName,
        description: description,
      );

      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        // 오디오 목록 업데이트
        await _refreshAudioData(audioId);

        // ✅ 성공 시 UI 피드백
        debugPrint('오디오 정보가 업데이트되었습니다.');
      } else {
        // ✅ 실패 시 UI 피드백
        debugPrint(result.error ?? '정보 업데이트에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('오디오 정보 업데이트 오류: $e');
      _isLoading = false;
      notifyListeners();
      debugPrint('정보 업데이트 중 오류가 발생했습니다.');
    }
  }

  // ==================== 유틸리티 ====================

  /// 특정 오디오 데이터 새로고침
  Future<void> _refreshAudioData(String audioId) async {
    try {
      final updatedAudio = await _audioService.getAudioData(audioId);
      if (updatedAudio != null) {
        final index = _audioList.indexWhere((audio) => audio.id == audioId);
        if (index != -1) {
          _audioList[index] = updatedAudio;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('오디오 데이터 새로고침 오류: $e');
    }
  }

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 특정 오디오가 현재 재생 중인지 확인
  bool isAudioPlaying(String audioId) {
    return _isPlaying && _currentPlayingAudioId == audioId;
  }

  /// 업로드 진행률 포맷팅
  String get formattedUploadProgress {
    return '${(_uploadProgress * 100).toStringAsFixed(1)}%';
  }
}
