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
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/category_controller.dart';
import '../../controllers/audio_controller.dart';
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
  @override
  Widget build(BuildContext context) {
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Colors.black,
        title: Text(
          widget.categoryName,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('수정하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initialIndex),
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  CachedNetworkImage(
                    imageUrl: photo.imageUrl,
                    width: 343,
                    height: 571,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 12,
                    child: Container(
                      color: Color.fromRGBO(0, 0, 0, 0.3),
                      child: Text(
                        DateFormat('yyyy.MM.dd').format(photo.createdAt),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 500,
                    left: 270,
                    child: IconButton(
                      onPressed: () async {
                        try {
                          // 사진의 오디오 URL이 이미 PhotoModel에 있는 경우
                          if (photo.audioUrl.isNotEmpty) {
                            await audioController.playAudioFromUrl(
                              photo.audioUrl,
                            );
                          } else {
                            // 사진 ID를 통해 오디오 URL을 조회하는 경우
                            String? photoId = await categoryController
                                .getPhotoDocumentId(
                                  widget.categoryId,
                                  photo.imageUrl,
                                );
                            if (photoId != null) {
                              String? audioUrl = await categoryController
                                  .getPhotoAudioUrl(widget.categoryId, photoId);
                              if (audioUrl != null && audioUrl.isNotEmpty) {
                                await audioController.playAudioFromUrl(
                                  audioUrl,
                                );
                              }
                            }
                          }
                        } catch (e) {
                          // 오류 발생 시 사용자에게 알림
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('음성 재생 중 오류가 발생했습니다.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: Image.asset(
                        'assets/voice.png',
                        width: 52,
                        height: 52,
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
