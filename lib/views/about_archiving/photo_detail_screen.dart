import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../../models/photo_data_model.dart';

class PhotoDetailScreen extends StatefulWidget {
  final List<PhotoDataModel> photos;
  final int initialIndex;
  final String categoryName;
  final String categoryId;

  const PhotoDetailScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late final PlayerController _playerController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _playerController = PlayerController();
    // 위젯이 빌드된 후 첫 번째 사진의 오디오로 플레이어를 준비합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preparePlayer(widget.photos[_currentIndex]);
    });
  }

  @override
  void dispose() {
    _playerController.dispose(); // 리소스 정리
    super.dispose();
  }

  /// 날짜를 안전하게 포맷팅하는 메서드
  String _formatDate(DateTime date) {
    try {
      return DateFormat('yyyy.MM.dd').format(date);
    } catch (e) {
      debugPrint('Date formatting error: $e');
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }
  }

  /// 페이지가 변경될 때마다 호출되어 현재 사진을 업데이트합니다.
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _preparePlayer(widget.photos[index]);
  }

  /// PhotoDataModel을 사용하여 플레이어를 준비하고 파형을 설정합니다.
  Future<void> _preparePlayer(PhotoDataModel photo) async {
    try {
      // 이전에 재생 중이던 것이 있으면 완전히 정지
      if (_playerController.playerState == PlayerState.playing) {
        await _playerController.stopPlayer();
      }

      // 새 오디오 URL이 없으면 함수 종료
      if (photo.audioUrl.isEmpty) {
        return;
      }

      debugPrint('🎵 플레이어 준비 시작: ${photo.audioUrl}');

      // 저장된 파형 데이터가 있는지 확인
      if (photo.waveformData != null && photo.waveformData!.isNotEmpty) {
        debugPrint('✅ 저장된 파형 데이터 사용: ${photo.waveformData!.length} samples');
        debugPrint('⚠️ OSStatus 오류 방지를 위해 플레이어 초기화 생략');

        // 저장된 파형 데이터가 있으면 플레이어 초기화를 최소화하여 OSStatus 오류 방지
        // 실제 재생이 필요할 때만 초기화하도록 지연
        return;
      } else {
        debugPrint('⚠️ 파형 데이터가 없음. 실시간 추출 시도...');

        // 하위 호환성: 구 버전 데이터는 실시간으로 파형 추출
        await _playerController.preparePlayer(
          path: photo.audioUrl,
          shouldExtractWaveform: true,
          noOfSamples: 200,
          volume: 1.0,
        );

        debugPrint('✅ 실시간 파형 추출로 플레이어 준비 완료');
      }
    } catch (e) {
      debugPrint("❌ 오디오 플레이어 준비 중 오류 발생: $e");

      // 에러 발생 시 사용자에게 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('음성 파일을 로드할 수 없습니다: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 저장된 파형 데이터 여부에 따라 적절한 파형 위젯을 빌드합니다.
  /// 녹음 시와 동일한 스타일의 파형을 표시합니다.
  Widget _buildAudioWaveforms(PhotoDataModel photo) {
    // 디버그 정보 출력
    debugPrint('📊 DetailScreen 파형 데이터 상태:');
    debugPrint('  - 사진 ID: ${photo.id}');
    debugPrint('  - waveformData null 여부: ${photo.waveformData == null}');
    debugPrint('  - waveformData 길이: ${photo.waveformData?.length ?? 0}');

    // 저장된 파형 데이터가 있으면 녹음 스타일의 커스텀 파형 사용
    if (photo.waveformData != null && photo.waveformData!.isNotEmpty) {
      debugPrint(
        '✅ DetailScreen: 저장된 파형 데이터 사용 (${photo.waveformData!.length} samples)',
      );
      return Container(
        width: MediaQuery.of(context).size.width - 100,
        height: 50.0,
        decoration: BoxDecoration(
          color: Color(0xff1c1c1c), // 녹음 시와 동일한 배경색
          borderRadius: BorderRadius.circular(14.6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: CustomPaint(
            size: Size(MediaQuery.of(context).size.width - 132, 34.0),
            painter: RecordingStyleWaveformPainter(
              waveformData: photo.waveformData!, // 원본 데이터 그대로 사용 (압축 없음)
              waveColor: Colors.white, // 녹음 시와 동일한 흰색
              backgroundColor: Colors.transparent,
              showMiddleLine: false, // 녹음 스타일에 맞게 중간선 제거
              extendWaveform: true, // 녹음 스타일에 맞게 파형 확장
            ),
          ),
        ),
      );
    }

    // 저장된 파형 데이터가 없으면 기본 AudioFileWaveforms 사용
    debugPrint('⚠️ DetailScreen: 저장된 파형 데이터 없음, AudioFileWaveforms 사용');
    return AudioFileWaveforms(
      size: Size(MediaQuery.of(context).size.width - 100, 50.0),
      playerController: _playerController,
      enableSeekGesture: true,
      waveformType: WaveformType.long,
      playerWaveStyle: const PlayerWaveStyle(
        fixedWaveColor: Colors.white54,
        liveWaveColor: Colors.white,
        spacing: 6,
        showSeekLine: false,
      ),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.black,
        title: Text(
          widget.categoryName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: 수정하기 기능 구현
            },
            child: const Text('수정하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.photos.length,
        onPageChanged: _onPageChanged, // 페이지 변경 감지
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 사진 이미지
                  SizedBox(
                    width: 343,
                    height: 571,
                    child: CachedNetworkImage(
                      imageUrl: photo.imageUrl,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Container(color: Colors.grey[900]),
                      errorWidget:
                          (context, url, error) =>
                              const Icon(Icons.error, color: Colors.white),
                    ),
                  ),

                  // 상단 날짜 표시
                  Positioned(
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatDate(photo.createdAt),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  // 하단 음성 컨트롤 UI (오디오가 있을 경우에만 표시)
                  if (photo.audioUrl.isNotEmpty)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            // 재생/일시정지 버튼
                            StreamBuilder<PlayerState>(
                              stream: _playerController.onPlayerStateChanged,
                              builder: (context, snapshot) {
                                final playerState = snapshot.data;
                                final isCurrentTrack = index == _currentIndex;

                                return IconButton(
                                  onPressed: () {
                                    if (isCurrentTrack) {
                                      if (playerState == PlayerState.playing) {
                                        _playerController.pausePlayer();
                                      } else {
                                        _playerController.startPlayer();
                                      }
                                    }
                                  },
                                  icon: Icon(
                                    (isCurrentTrack &&
                                            playerState == PlayerState.playing)
                                        ? Icons.pause_circle_filled_rounded
                                        : Icons.play_circle_filled_rounded,
                                    color: Colors.white,
                                    size: 42,
                                  ),
                                  padding: EdgeInsets.zero,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            // 오디오 파형 (저장된 데이터 우선 사용)
                            Expanded(child: _buildAudioWaveforms(photo)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 녹음 시와 동일한 스타일의 파형을 그리는 커스텀 페인터
/// AudioWaveforms 위젯의 스타일을 모방합니다.
class RecordingStyleWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color waveColor;
  final Color backgroundColor;
  final bool showMiddleLine;
  final bool extendWaveform;

  RecordingStyleWaveformPainter({
    required this.waveformData,
    required this.waveColor,
    required this.backgroundColor,
    this.showMiddleLine = false,
    this.extendWaveform = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint =
        Paint()
          ..color = waveColor
          ..strokeWidth =
              2.0 // 녹음 시와 비슷한 두께
          ..style = PaintingStyle.fill; // 채워진 스타일

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    // 녹음 스타일처럼 수직 바 형태로 그리기
    final barWidth = 2.0;
    final spacing = 3.0; // 녹음 시와 비슷한 간격
    final totalBarWidth = barWidth + spacing;
    final maxBars = (width / totalBarWidth).floor();

    // 데이터 포인트를 최대 바 개수에 맞게 조정
    final step = waveformData.length / maxBars;

    for (int i = 0; i < maxBars && i < waveformData.length; i++) {
      final dataIndex = (i * step).floor().clamp(0, waveformData.length - 1);
      final amplitude = waveformData[dataIndex].abs();

      // 진폭을 높이에 맞게 스케일링 (최소 높이 보장)
      final barHeight = (amplitude * height * 0.8).clamp(
        height * 0.1,
        height * 0.9,
      );

      final x = i * totalBarWidth;
      final top = centerY - (barHeight / 2);
      final bottom = centerY + (barHeight / 2);

      // 수직 바 그리기 (녹음 시와 동일한 스타일)
      final rect = Rect.fromLTRB(x, top, x + barWidth, bottom);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(1.0)),
        paint,
      );
    }

    // 중간선 그리기 (옵션)
    if (showMiddleLine) {
      final linePaint =
          Paint()
            ..color = waveColor.withOpacity(0.3)
            ..strokeWidth = 1.0;
      canvas.drawLine(Offset(0, centerY), Offset(width, centerY), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}
