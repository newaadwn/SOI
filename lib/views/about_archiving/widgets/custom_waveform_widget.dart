import 'package:flutter/material.dart';

/// 커스텀 파형 위젯
class CustomWaveformWidget extends StatelessWidget {
  final List<double> waveformData;
  final Color color;
  final Color activeColor;
  final double progress;

  const CustomWaveformWidget({
    super.key,
    required this.waveformData,
    this.color = Colors.grey,
    this.activeColor = Colors.blue,
    this.progress = 0.0, // 0.0 ~ 1.0
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

/// 파형을 그리는 커스텀 페인터
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color color;
  final Color activeColor;
  final double progress;

  WaveformPainter({
    required this.waveformData,
    required this.color,
    required this.activeColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint =
        Paint()
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;

    // 파형 데이터를 화면 너비에 맞게 샘플링
    final barCount = (size.width / 4).floor(); // 4픽셀 간격으로 바 생성
    final sampledData = _sampleData(waveformData, barCount);

    final barSpacing = 4.0;
    final centerY = size.height / 2;
    final maxBarHeight = size.height * 0.8;

    for (int i = 0; i < sampledData.length; i++) {
      final x = i * barSpacing;
      if (x >= size.width) break;

      // 파형 높이 계산 (0.0 ~ 1.0 범위의 데이터를 바 높이로 변환)
      final normalizedHeight = sampledData[i].clamp(0.0, 1.0);
      final barHeight = normalizedHeight * maxBarHeight;

      // 진행 상태에 따라 색상 결정
      final isActive = progress > 0 && (i / sampledData.length) <= progress;
      paint.color = isActive ? activeColor : color;

      // 파형 바 그리기 (중앙에서 위아래로)
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  /// 파형 데이터를 지정된 개수로 샘플링
  List<double> _sampleData(List<double> data, int targetCount) {
    if (data.length <= targetCount) return data;

    final step = data.length / targetCount;
    final sampledData = <double>[];

    for (int i = 0; i < targetCount; i++) {
      final startIndex = (i * step).floor();
      final endIndex = ((i + 1) * step).floor().clamp(0, data.length);

      // 구간 내 최대값 사용 (더 시각적으로 보기 좋음)
      double maxValue = 0.0;
      for (int j = startIndex; j < endIndex; j++) {
        maxValue = maxValue > data[j] ? maxValue : data[j];
      }
      sampledData.add(maxValue);
    }

    return sampledData;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! WaveformPainter ||
        oldDelegate.waveformData != waveformData ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.activeColor != activeColor;
  }
}
