import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:audio_waveforms/audio_waveforms.dart';
import '../services/audio_service.dart';
import '../models/audio_data_model.dart';

/// 오디오 관련 UI와 비즈니스 로직 사이의 중개 역할을 합니다.
class AudioController extends ChangeNotifier {
  // 상태 변수들
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isRecording = false;
  String? _currentRecordingPath;
  String? _currentPlayingAudioId;
  String? _currentPlayingAudioUrl; // 현재 재생 중인 오디오 URL 추가
  String? _currentRecordingUserId; // 현재 녹음 중인 사용자 ID 추가
  int _recordingDuration = 0;
  double _recordingLevel = 0.0;
  double _playbackPosition = 0.0;
  double _playbackDuration = 0.0;
  double _uploadProgress = 0.0;
  String? _error;

  List<AudioDataModel> _audioList = [];
  Timer? _recordingTimer;
  StreamSubscription<double>? _uploadSubscription;

  // 실시간 오디오 추적을 위한 AudioPlayer 관리
  ap.AudioPlayer? _realtimeAudioPlayer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<ap.PlayerState>? _stateSubscription;

  // Service 인스턴스 - 모든 비즈니스 로직은 Service에서 처리
  final AudioService _audioService = AudioService();

  // ==================== 파형 관련 (audio_waveforms) ====================

  PlayerController? _playerController;
  final bool _isPlayerInitialized = false;

  /// PlayerController getter
  PlayerController? get playerController => _playerController;

  /// 플레이어 초기화 상태 getter
  bool get isPlayerInitialized => _isPlayerInitialized;

  // ==================== 권한 관리 ====================

  /// 마이크 권한 상태 확인
  Future<bool> checkMicrophonePermission() async {
    return await _audioService.checkMicrophonePermission();
  }

  /// 마이크 권한 요청
  Future<bool> requestMicrophonePermission() async {
    return await _audioService.requestMicrophonePermission();
  }

  // ==================== Getters ====================

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get currentRecordingPath => _currentRecordingPath;
  String? get currentPlayingAudioId => _currentPlayingAudioId;
  String? get currentPlayingAudioUrl => _currentPlayingAudioUrl; // getter 추가
  String? get currentRecordingUserId =>
      _currentRecordingUserId; // 현재 녹음 중인 사용자 ID getter
  int get recordingDuration => _recordingDuration;
  double get recordingLevel => _recordingLevel;
  double get playbackPosition => _playbackPosition;
  double get playbackDuration => _playbackDuration;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  List<AudioDataModel> get audioList => _audioList;

  /// 실시간 재생 위치 (Duration 타입)
  Duration get currentPosition =>
      Duration(milliseconds: (_playbackPosition * 1000).round());

  /// 실시간 재생 길이 (Duration 타입)
  Duration get currentDuration =>
      Duration(milliseconds: (_playbackDuration * 1000).round());

  /// 녹음 시간을 포맷팅하여 반환합니다 (예: "01:23")
  String get formattedRecordingDuration {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

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
        // debugPrint('오디오 기능이 준비되었습니다.');
      } else {
        _error = result.error;
        // debugPrint(result.error ?? '오디오 초기화에 실패했습니다.');
      }
    } catch (e) {
      // debugPrint('오디오 컨트롤러 초기화 오류: $e');
      _isLoading = false;
      _error = '오디오 초기화 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// Controller 종료
  @override
  void dispose() {
    debugPrint('🔊 AudioController dispose 시작');

    // 1. 타이머 및 스트림 정리
    _recordingTimer?.cancel();
    _uploadSubscription?.cancel();

    // 2. 모든 재생 중지 (동기적으로 처리)
    try {
      if (_realtimeAudioPlayer != null) {
        _realtimeAudioPlayer!.stop();
      }
    } catch (e) {
      debugPrint('❌ AudioController dispose: 실시간 플레이어 정지 오류: $e');
    }

    // 3. 리스너 정리
    _disposeRealtimeListeners();

    // 4. 플레이어 정리 (순차적으로)
    try {
      _playerController?.dispose();
    } catch (e) {
      debugPrint('❌ AudioController dispose: 파형 플레이어 정리 오류: $e');
    }

    try {
      _realtimeAudioPlayer?.dispose();
    } catch (e) {
      debugPrint('❌ AudioController dispose: 실시간 플레이어 정리 오류: $e');
    }

    debugPrint('🔊 AudioController dispose 완료');
    super.dispose();
  }

  // ==================== 파형 플레이어 관리 ====================  /// 파형 표시용 플레이어 초기화

  /// 파형 플레이어로 재생 시작
  Future<void> startPlayerWaveform() async {
    try {
      if (_playerController != null && _isPlayerInitialized) {
        await _playerController!.startPlayer();
        _isPlaying = true;
        notifyListeners();
        // debugPrint('파형 플레이어 재생 시작');
      }
    } catch (e) {
      // debugPrint('파형 플레이어 재생 오류: $e');
      _error = '음성 재생 중 오류가 발생했습니다.';
      notifyListeners();
    }
  }

  /// 파형 플레이어 일시정지
  Future<void> pausePlayerWaveform() async {
    try {
      if (_playerController != null) {
        await _playerController!.pausePlayer();
        _isPlaying = false;
        notifyListeners();
        // debugPrint('파형 플레이어 일시정지');
      }
    } catch (e) {
      // debugPrint('파형 플레이어 일시정지 오류: $e');
    }
  }

  /// 파형 플레이어 중지
  Future<void> stopPlayerWaveform() async {
    try {
      if (_playerController != null) {
        await _playerController!.stopPlayer();
        _isPlaying = false;
        notifyListeners();
        // debugPrint('파형 플레이어 중지');
      }
    } catch (e) {
      // debugPrint('파형 플레이어 중지 오류: $e');
    }
  }

  /// 파형 플레이어 위치 이동
  Future<void> seekToPositionWaveform(Duration position) async {
    try {
      if (_playerController != null) {
        await _playerController!.seekTo(position.inMilliseconds);
        // debugPrint('파형 플레이어 위치 이동: ${position.inSeconds}초');
      }
    } catch (e) {
      // debugPrint('파형 플레이어 위치 이동 오류: $e');
    }
  }

  // ==================== 네이티브 녹음 관리 ====================

  /// 네이티브 녹음 시작
  Future<void> startRecording([String? userId]) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. 먼저 마이크 권한 확인/요청
      // debugPrint('마이크 권한 확인 중...');
      final hasPermission = await requestMicrophonePermission();

      if (!hasPermission) {
        _isLoading = false;
        _error = '마이크 권한이 필요합니다.';
        notifyListeners();
        // debugPrint('마이크 권한이 없어 녹음을 시작할 수 없습니다.');
        throw Exception('마이크 권한이 필요합니다.');
      }

      // 2. 권한이 있을 때만 네이티브 녹음 시작
      // debugPrint('네이티브 녹음 시작 요청...');
      final result = await _audioService.startRecording();

      if (result.isSuccess) {
        _isRecording = true;
        _currentRecordingPath = result.data;
        _currentRecordingUserId = userId; // 녹음 중인 사용자 ID 설정
        _recordingDuration = 0;

        // 녹음 시간 타이머 시작
        _startRecordingTimer();

        _isLoading = false;
        notifyListeners();

        // debugPrint('네이티브 녹음이 시작되었습니다: ${_currentRecordingPath}');
      } else {
        _isLoading = false;
        notifyListeners();

        // debugPrint('네이티브 녹음 시작 실패: ${result.error}');
      }
    } catch (e) {
      // debugPrint('네이티브 녹음 시작 오류: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 네이티브 녹음 중지 (완전한 처리)
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

      // debugPrint('네이티브 녹음 중지 요청...');
      final result = await _audioService.stopRecording(
        categoryId: categoryId,
        userId: userId,
        description: description,
      );

      _isRecording = false;
      _currentRecordingPath = null;
      _currentRecordingUserId = null; // 녹음 중인 사용자 ID 초기화
      _recordingDuration = 0;
      _recordingLevel = 0.0;
      _isLoading = false;
      notifyListeners();

      if (result.isSuccess) {
        final audioData = result.data as AudioDataModel;

        // 오디오 목록에 추가
        _audioList.insert(0, audioData);
        notifyListeners();

        // debugPrint('네이티브 녹음이 완료되었습니다: ${audioData.id}');
      } else {
        // debugPrint('네이티브 녹음 완료 실패: ${result.error}');
      }
    } catch (e) {
      // debugPrint('네이티브 녹음 중지 오류: $e');
      _isRecording = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 간단한 네이티브 녹음 중지 (UI용)
  Future<void> stopRecordingSimple() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 타이머 및 구독 정리
      _stopRecordingTimer();

      // debugPrint('네이티브 간단 녹음 중지...');
      final result = await _audioService.stopRecordingSimple();

      _isLoading = false;
      _isRecording = false;

      if (result.isSuccess) {
        _currentRecordingPath = result.data ?? '';
        // debugPrint('네이티브 간단 녹음 중지 완료: $_currentRecordingPath');
      } else {
        _error = result.error;
        // debugPrint('네이티브 간단 녹음 중지 실패: ${result.error}');
      }

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isRecording = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 녹음 일시정지
  Future<void> pauseRecording() async {
    try {
      // 타이머만 일시정지
      _stopRecordingTimer();
      // debugPrint('녹음 일시정지됨');
      notifyListeners();
    } catch (e) {
      // debugPrint('녹음 일시정지 오류: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 녹음 재개
  Future<void> resumeRecording() async {
    try {
      // 타이머 재시작
      _startRecordingTimer();
      // debugPrint('녹음 재개됨');
      notifyListeners();
    } catch (e) {
      // debugPrint('녹음 재개 오류: $e');
      _error = e.toString();
      notifyListeners();
    }
  }

  /// 녹음 취소
  Future<void> cancelRecording() async {
    try {
      _stopRecordingTimer();
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingDuration = 0;
      // debugPrint('녹음 취소됨');
      notifyListeners();
    } catch (e) {
      // debugPrint('녹음 취소 오류: $e');
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

  // ==================== 재생 관리 ====================

  /// URL로 직접 오디오 재생 (기존 호환성)
  Future<void> playAudioFromUrl(String audioUrl) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 새로운 오디오 재생 (간단한 AudioPlayer 사용)
      final player = ap.AudioPlayer();
      await player.play(ap.UrlSource(audioUrl));

      _isLoading = false;
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      // debugPrint('URL 오디오 재생 컨트롤러 오류: $e');
      _isLoading = false;
      _error = 'URL 오디오 재생 중 오류가 발생했습니다.';
      notifyListeners();
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

        // debugPrint('업로드가 완료되었습니다.');
      } else {
        // debugPrint(result.error ?? '업로드에 실패했습니다.');
      }
    } catch (e) {
      // debugPrint('업로드 오류: $e');
      _isLoading = false;
      _uploadProgress = 0.0;
      notifyListeners();
    }
  }

  /// 오디오 업로드를 위한 처리 (기존 호환성)
  Future<String> processAudioForUpload() async {
    try {
      if (_currentRecordingPath != null && _currentRecordingPath!.isNotEmpty) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          return _currentRecordingPath!;
        }
      }

      // 녹음된 파일이 없는 경우 빈 문자열 반환
      return '';
    } catch (e) {
      // debugPrint('오디오 처리 오류: $e');
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
      // debugPrint('오디오 목록 로드 오류: $e');
      _error = '오디오 목록을 불러오는 중 오류가 발생했습니다.';
      _audioList = [];
      _isLoading = false;
      notifyListeners();
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
      // debugPrint('사용자 오디오 목록 로드 오류: $e');
      _error = '오디오 목록을 불러오는 중 오류가 발생했습니다.';
      _audioList = [];
      _isLoading = false;
      notifyListeners();
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
        // debugPrint('오디오가 삭제되었습니다.');
      } else {
        // debugPrint(result.error ?? '오디오 삭제에 실패했습니다.');
      }
    } catch (e) {
      // debugPrint('오디오 삭제 오류: $e');
      _isLoading = false;
      notifyListeners();
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

        // debugPrint('오디오 정보가 업데이트되었습니다.');
      } else {
        // debugPrint(result.error ?? '정보 업데이트에 실패했습니다.');
      }
    } catch (e) {
      // debugPrint('오디오 정보 업데이트 오류: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== 메타데이터 추출 ====================

  /// 오디오 URL에서 duration 추출
  Future<Duration?> getAudioDuration(String audioUrl) async {
    try {
      final player = ap.AudioPlayer();

      // 오디오 소스 설정
      await player.setSourceUrl(audioUrl);

      // duration이 설정될 때까지 대기
      Duration? duration;
      final completer = Completer<Duration?>();

      StreamSubscription? subscription;
      subscription = player.onDurationChanged.listen((newDuration) {
        if (newDuration != Duration.zero) {
          duration = newDuration;
          subscription?.cancel();
          completer.complete(duration);
        }
      });

      // 타임아웃 설정 (5초)
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          subscription?.cancel();
          completer.complete(null);
        }
      });

      final result = await completer.future;
      await player.dispose();

      return result;
    } catch (e) {
      // debugPrint('Error getting audio duration: $e');
      return null;
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
      // debugPrint('오디오 데이터 새로고침 오류: $e');
    }
  }

  /// 에러 상태 초기화
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// 현재 녹음 경로 초기화
  void clearCurrentRecording() {
    _currentRecordingPath = null;
    _currentRecordingUserId = null;
    _recordingDuration = 0;
    _recordingLevel = 0.0;
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

  // ==================== 실시간 오디오 추적 ====================

  /// 실시간 AudioPlayer 초기화
  void _initializeRealtimePlayer() {
    if (_realtimeAudioPlayer != null) return;

    _realtimeAudioPlayer = ap.AudioPlayer();
    _setupRealtimeListeners();
    // debugPrint('실시간 AudioPlayer 초기화 완료');
  }

  /// 실시간 리스너 설정
  void _setupRealtimeListeners() {
    if (_realtimeAudioPlayer == null) return;

    // 재생 위치 변화 감지
    _positionSubscription = _realtimeAudioPlayer!.onPositionChanged.listen((
      Duration position,
    ) {
      _playbackPosition = position.inMilliseconds / 1000.0; // 초 단위로 변환
      notifyListeners();
    });

    // 재생 시간 변화 감지
    _durationSubscription = _realtimeAudioPlayer!.onDurationChanged.listen((
      Duration duration,
    ) {
      _playbackDuration = duration.inMilliseconds / 1000.0; // 초 단위로 변환
      notifyListeners();
    });

    // 재생 상태 변화 감지
    _stateSubscription = _realtimeAudioPlayer!.onPlayerStateChanged.listen((
      ap.PlayerState state,
    ) {
      _isPlaying = state == ap.PlayerState.playing;
      if (state == ap.PlayerState.completed) {
        _playbackPosition = 0.0;
        _currentPlayingAudioUrl = null;
      }
      notifyListeners();
    });

    // debugPrint('🎧 실시간 리스너 설정 완료');
  }

  /// 실시간 오디오 재생 (중복 방지)
  Future<void> playRealtimeAudio(String audioUrl) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 이미 같은 오디오가 재생 중이면 일시정지/재생 토글
      if (_currentPlayingAudioUrl == audioUrl && _isPlaying) {
        if (_realtimeAudioPlayer != null) {
          await _realtimeAudioPlayer!.pause();
        }
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 기존과 URL 이 다를 때만 완전 정리
      if (_realtimeAudioPlayer != null && _currentPlayingAudioUrl != audioUrl) {
        await _realtimeAudioPlayer!.stop();
        await _realtimeAudioPlayer!.dispose();
        _disposeRealtimeListeners();
        _realtimeAudioPlayer = null;
        _currentPlayingAudioUrl = null;
      }

      // 새 플레이어 생성

      _initializeRealtimePlayer();

      // 새 오디오 재생
      debugPrint('🎵 새 오디오 재생 시작: $audioUrl');
      await _realtimeAudioPlayer!.play(ap.UrlSource(audioUrl));
      _currentPlayingAudioUrl = audioUrl;

      _isLoading = false;
      notifyListeners();
      debugPrint('🎵 재생 시작 완료');
    } catch (e) {
      debugPrint('❌ 재생 오류: $e');
      _isLoading = false;
      _error = '음성 파일을 재생할 수 없습니다.';
      notifyListeners();
    }
  }

  /// 실시간 오디오 일시정지
  Future<void> pauseRealtimeAudio() async {
    if (_realtimeAudioPlayer != null && _isPlaying) {
      await _realtimeAudioPlayer!.pause();
      // debugPrint('실시간 오디오 일시정지');
    }
  }

  /// 실시간 오디오 정지
  Future<void> stopRealtimeAudio() async {
    if (_realtimeAudioPlayer != null) {
      await _realtimeAudioPlayer!.stop();
      _playbackPosition = 0.0;
      _currentPlayingAudioUrl = null;
      // debugPrint('🛑 실시간 오디오 정지');
      notifyListeners();
    }
  }

  /// 오디오 토글 (재생/일시정지) - UI용 간편 메서드
  Future<void> toggleAudio(String audioUrl, {String? commentId}) async {
    // commentId 는 향후 서로 다른 재생소스를 구분하기 위한 확장 포인트
    if (_currentPlayingAudioUrl == audioUrl) {
      if (_isPlaying) {
        await pauseRealtimeAudio();
      } else {
        await playRealtimeAudio(audioUrl);
      }
      return;
    }
    await playRealtimeAudio(audioUrl);
  }

  /// 오디오 정지 - UI용 간편 메서드
  Future<void> stopAudio() async {
    await stopRealtimeAudio();
  }

  /// 실시간 리스너 정리
  void _disposeRealtimeListeners() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _positionSubscription = null;
    _durationSubscription = null;
    _stateSubscription = null;
  }
}
