import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/photo_data_model.dart';
import '../../controllers/audio_controller.dart';
import '../widgets/smart_waveform_widget.dart';

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
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
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
                            Consumer<AudioController>(
                              builder: (context, audioController, child) {
                                final isCurrentTrack = index == _currentIndex;
                                final isPlaying =
                                    audioController.isPlaying &&
                                    audioController.currentPlayingAudioUrl ==
                                        photo.audioUrl;

                                return IconButton(
                                  onPressed: () {
                                    if (isCurrentTrack) {
                                      if (isPlaying) {
                                        audioController.pause();
                                      } else {
                                        audioController.play(photo.audioUrl);
                                      }
                                    }
                                  },
                                  icon: Icon(
                                    (isCurrentTrack && isPlaying)
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
                            // 스마트 오디오 파형
                            Expanded(
                              child: SmartWaveformWidget(
                                audioUrl: photo.audioUrl,
                                width: MediaQuery.of(context).size.width - 100,
                                height: 50.0,
                                waveColor: Colors.white54,
                                progressColor: Colors.white,
                                isPlaying: index == _currentIndex,
                              ),
                            ),
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
