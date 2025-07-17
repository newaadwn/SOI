import 'package:flutter/material.dart';

import 'wave_form_painter.dart';

/// 커스텀 파형 위젯
class CustomWaveformWidget extends StatelessWidget {
  final List<double> waveformData;
  final Color color;
  final Color activeColor;
  final double progress;

  const CustomWaveformWidget({
    super.key,
    required this.waveformData,
    required this.activeColor,
    this.progress = 0.0,
    required this.color, // 0.0 ~ 1.0
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WaveformPainter(
        waveformData: waveformData,
        color: color,
        activeColor: activeColor,
        progress: progress,
      ),
      size: Size.infinite,
    );
  }
}
