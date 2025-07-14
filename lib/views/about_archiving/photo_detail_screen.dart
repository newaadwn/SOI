/*
 * PhotoDetailScreen
 * 
 * 이 파일은 사진 상세 보기 페이지를 구현한 코드입니다.
 * 
 * 기능:
 * 1. 선택된 카테고리의 사진을 전체화면으로 표시합니다.
 * 2. 사진 상단에 촬영 날짜를 표시합니다.
 * 3. 사진에 첨부된 음성 메모를 재생할 수 있는 버튼을 제공합니다.
 * 4. 좌우 스와이프를 통해 카테고리 내의 다른 사진들을 탐색할 수 있습니다.
 * 5. 수정하기 버튼을 통해 사진 편집 기능에 접근할 수 있습니다.
 * 
 * 데이터 흐름:
 * - 생성자를 통해 카테고리 ID, 이름, 사진 목록, 초기 표시할 사진 인덱스를 전달받습니다.
 * - CategoryViewModel을 통해 사진과 관련된 추가 정보(음성 메모 URL 등)를 조회합니다.
 * - 음성 메모 재생 시 AudioPlayer를 사용하여 원격 URL의 오디오를 재생합니다.
 * - DateFormat을 사용하여 Firestore의 Timestamp를 사용자 친화적인 날짜 형식으로 변환합니다.
 * 
 * 주요 위젯:
 * - PageView.builder: 사진 간 좌우 스와이프 탐색을 제공합니다.
 * - Stack: 사진 위에 날짜와 음성 메모 버튼을 오버레이 형태로 배치합니다.
 * - ClipRRect: 이미지를 둥근 모서리로 표시합니다.
 * - IconButton: 음성 메모 재생 기능을 제공합니다.
 * - AudioPlayer: 음성 메모 재생을 담당하는 외부 패키지입니다.
 */

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/audio_controller.dart';
import '../../models/category_data_model.dart';
import '../../models/photo_data_model.dart';
import '../widgets/smart_waveform_widget.dart';

class PhotoDetailScreen extends StatefulWidget {
  final CategoryDataModel? categoryModel;
  final List<PhotoDataModel> photos;
  final int initialIndex;
  final String categoryName;
  final String categoryId;

  const PhotoDetailScreen({
    super.key,
    this.categoryModel,
    required this.photos,
    this.initialIndex = 0,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 사진 페이지뷰
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return Center(
                child: CachedNetworkImage(
                  imageUrl: photo.imageUrl,
                  fit: BoxFit.contain,
                  placeholder:
                      (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              );
            },
          ),

          // 상단 바
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.categoryName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // 뒤로가기 버튼과 대칭을 위한 공간
                ],
              ),
            ),
          ),

          // 음성 파형 UI (하단)
          if (widget.photos[_currentIndex].audioUrl.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 40,
              right: 40,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // 파형 표시 영역
                    Container(
                      height: 80,
                      width: double.infinity,
                      child: SmartWaveformWidget(
                        audioUrl: widget.photos[_currentIndex].audioUrl,
                        width: MediaQuery.of(context).size.width - 80,
                        height: 80,
                        waveColor: Colors.white,
                        progressColor: Colors.blue,
                        isPlaying: false, // 나중에 실제 재생 상태로 연결
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 재생 컨트롤 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Consumer<AudioController>(
                          builder: (context, audioController, child) {
                            return IconButton(
                              onPressed: () async {
                                try {
                                  final photo = widget.photos[_currentIndex];

                                  // 재생/일시정지 토글
                                  if (audioController.isPlaying) {
                                    await audioController.pausePlaying();
                                  } else {
                                    await audioController.playAudioFromUrl(
                                      photo.audioUrl,
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('재생 오류: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('음성 재생에 실패했습니다.'),
                                    ),
                                  );
                                }
                              },
                              icon: Icon(
                                audioController.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 28,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 수정 버튼 (우측 하단)
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              onPressed: () {
                // 수정 기능 추가 예정
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('수정 기능은 준비중입니다.')));
              },
              backgroundColor: Colors.blue,
              child: const Icon(Icons.edit, color: Colors.white),
            ),
          ),

          // 페이지 인디케이터
          if (widget.photos.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.photos.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
