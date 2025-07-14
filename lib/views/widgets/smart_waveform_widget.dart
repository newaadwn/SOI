import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/audio_controller.dart';
import 'dart:math' as math;

/// 오디오 메타데이터를 기반으로 실제같은 파형을 생성하는 위젯
class SmartWaveformWidget extends StatefulWidget {
  final String audioUrl;
  final double width;
  final double height;
  final Color waveColor;
  final Color progressColor;
  final bool isPlaying;
  final VoidCallback? onTap;

  const SmartWaveformWidget({
    super.key,
    required this.audioUrl,
    required this.width,
    required this.height,
    this.waveColor = Colors.grey,
    this.progressColor = Colors.blue,
    this.isPlaying = false,
    this.onTap,
  });

  @override
  State<SmartWaveformWidget> createState() => _SmartWaveformWidgetState();
}

class _SmartWaveformWidgetState extends State<SmartWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  List<double> _waveformData = [];
  Duration? _audioDuration;
  bool _isLoadingDuration = true;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _loadAudioMetadata();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadAudioMetadata() async {
    if (widget.audioUrl.isEmpty) {
      setState(() {
        _isLoadingDuration = false;
      });
      return;
    }

    try {
      final audioController = Provider.of<AudioController>(
        context,
        listen: false,
      );
      final duration = await audioController.getAudioDuration(widget.audioUrl);

      if (mounted) {
        setState(() {
          _audioDuration = duration;
          _isLoadingDuration = false;
        });

        _generateSmartWaveform();
        _animationController.forward();
      }
    } catch (e) {
      debugPrint('Error loading audio metadata: $e');
      if (mounted) {
        setState(() {
          _isLoadingDuration = false;
        });
        _generateFallbackWaveform();
        _animationController.forward();
      }
    }
  }

  void _generateSmartWaveform() {
    if (_audioDuration == null) {
      _generateFallbackWaveform();
      return;
    }

    final durationSeconds = _audioDuration!.inSeconds;
    final seed = widget.audioUrl.hashCode;
    final random = math.Random(seed);

    // 오디오 길이에 따라 파형 밀도 조정
    final points = math.max(20, (widget.width / 4).round());
    final complexity = _getComplexityFromDuration(durationSeconds);

    _waveformData = List.generate(points, (index) {
      final progress = index / points;

      // 실제 오디오 패턴을 모방한 파형 생성
      final baseAmplitude = _getAmplitudePattern(
        progress,
        durationSeconds,
        complexity,
      );
      final randomVariation = (random.nextDouble() - 0.5) * 0.3;
      final smoothing = math.sin(progress * math.pi * 4) * 0.2;

      final amplitude = (baseAmplitude + randomVariation + smoothing).clamp(
        0.1,
        1.0,
      );
      return amplitude;
    });

    debugPrint(
      '🎵 Smart waveform generated: ${_waveformData.length} points for ${durationSeconds}s audio',
    );
  }

  void _generateFallbackWaveform() {
    final seed = widget.audioUrl.hashCode;
    final random = math.Random(seed);
    final points = (widget.width / 4).round();

    _waveformData = List.generate(points, (index) {
      final baseHeight = 0.3 + (random.nextDouble() * 0.7);
      final variation = math.sin(index * 0.1) * 0.2;
      return (baseHeight + variation).clamp(0.1, 1.0);
    });
  }

  double _getComplexityFromDuration(int seconds) {
    // 짧은 오디오는 단순하게, 긴 오디오는 복잡하게
    if (seconds < 5) return 0.3;
    if (seconds < 15) return 0.5;
    if (seconds < 30) return 0.7;
    return 0.9;
  }

  double _getAmplitudePattern(
    double progress,
    int durationSeconds,
    double complexity,
  ) {
    // 실제 음성 패턴을 모방
    // 시작과 끝은 조용하게, 중간은 활발하게
    final fadeIn = progress < 0.1 ? progress * 10 : 1.0;
    final fadeOut = progress > 0.9 ? (1.0 - progress) * 10 : 1.0;
    final fade = math.min(fadeIn, fadeOut);

    // 중간 부분의 활동 패턴
    final midActivity = 0.4 + complexity * 0.5;
    final variation = math.sin(progress * math.pi * 8) * complexity * 0.3;

    return (midActivity + variation) * fade;
  }

  void _updateProgress() {
    // AudioController에서 실제 재생 진행률 가져오기
    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );
    if (_audioDuration != null && audioController.playbackDuration > 0) {
      // 진행률은 Consumer에서 실시간으로 처리됨
      debugPrint(
        'Progress: ${audioController.playbackPosition / audioController.playbackDuration}',
      );
    }
  }

  @override
  void didUpdateWidget(SmartWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) {
      _loadAudioMetadata();
    }
    if (oldWidget.isPlaying != widget.isPlaying && widget.isPlaying) {
      _updateProgress();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingDuration) {
      return Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(widget.waveColor),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Consumer<AudioController>(
          builder: (context, audioController, child) {
            // 실시간 진행률 업데이트
            double progress = 0.0;
            if (_audioDuration != null &&
                audioController.playbackDuration > 0) {
              progress =
                  audioController.playbackPosition /
                  audioController.playbackDuration;
            }

            return CustomPaint(
              painter: SmartWaveformPainter(
                waveformData: _waveformData,
                progress: progress,
                waveColor: widget.waveColor,
                progressColor: widget.progressColor,
                isPlaying: widget.isPlaying,
                animationValue: _animation.value,
                audioDuration: _audioDuration,
              ),
              size: Size(widget.width, widget.height),
            );
          },
        );
      },
    );
  }
}

/// 스마트 파형을 그리는 CustomPainter
class SmartWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color waveColor;
  final Color progressColor;
  final bool isPlaying;
  final double animationValue;
  final Duration? audioDuration;

  SmartWaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.waveColor,
    required this.progressColor,
    required this.isPlaying,
    required this.animationValue,
    this.audioDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint =
        Paint()
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;

    final spacing = size.width / waveformData.length;
    final centerY = size.height / 2;
    final progressX = size.width * progress;

    // 파형 그리기
    for (int i = 0; i < waveformData.length; i++) {
      final x = i * spacing;
      final amplitude = waveformData[i] * animationValue;
      final barHeight = amplitude * size.height * 0.8;

      // 진행률에 따라 색상 변경
      if (x <= progressX) {
        paint.color = progressColor;
      } else {
        paint.color = waveColor.withOpacity(0.6);
      }

      // 파형 바 그리기
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }

    // 재생 중일 때 진행률 표시선
    if (isPlaying && progress > 0) {
      final progressPaint =
          Paint()
            ..color = progressColor.withOpacity(0.8)
            ..strokeWidth = 1.5;

      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        progressPaint,
      );
    }

    // 오디오 길이 표시 (선택사항)
    if (audioDuration != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text:
              '${audioDuration!.inMinutes}:${(audioDuration!.inSeconds % 60).toString().padLeft(2, '0')}',
          style: TextStyle(color: waveColor.withOpacity(0.5), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          size.width - textPainter.width - 4,
          size.height - textPainter.height - 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(SmartWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.waveformData != waveformData;
  }
}
