/*
 * ShowDetailedPhoto
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

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/photo_model.dart';
import '../../controllers/category_controller.dart';

class ShowDetailedPhoto extends StatefulWidget {
  final List<PhotoModel> photos;
  final int initialIndex;
  final String categoryName;
  final String categoryId;

  const ShowDetailedPhoto({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    required this.categoryName,
    required this.categoryId,
  });

  @override
  State<ShowDetailedPhoto> createState() => _ShowDetailedPhotoState();
}

class _ShowDetailedPhotoState extends State<ShowDetailedPhoto> {
  @override
  Widget build(BuildContext context) {
    CategoryController categoryViewModel = Provider.of<CategoryController>(
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
                  Image.network(
                    photo.imageUrl,
                    width: 343,
                    height: 571,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 12,
                    child: Container(
                      color: Color.fromRGBO(0, 0, 0, 0.3),
                      child: Text(
                        DateFormat(
                          'yyyy.MM.dd',
                        ).format(photo.createdAt.toDate()),
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
                        String? photoId = await categoryViewModel
                            .getPhotoDocumentId(
                              widget.categoryId,
                              photo.imageUrl,
                            );
                        String? audioUrl = await categoryViewModel
                            .getPhotoAudioUrl(widget.categoryId, photoId!);
                        if (audioUrl != null) {
                          final player = AudioPlayer();
                          await player.play(UrlSource(audioUrl));
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
