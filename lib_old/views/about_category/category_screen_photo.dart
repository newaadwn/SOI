import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../controllers/category_controller.dart';
import 'package:provider/provider.dart';
import '../../models/photo_model.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/comment_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryScreenPhoto extends StatefulWidget {
  final String categoryId; // 카테고리 ID
  final String? fileName; // 카메라 등에서 넘겨받을 수 있는 파일 이름

  const CategoryScreenPhoto({Key? key, required this.categoryId, this.fileName})
    : super(key: key);

  @override
  State<CategoryScreenPhoto> createState() => _CategoryScreenPhotoState();
}

class _CategoryScreenPhotoState extends State<CategoryScreenPhoto> {
  AudioPlayer? audioPlayer; // 오디오 플레이어 객체

  @override
  Widget build(BuildContext context) {
    // Provider로부터 필요한 Controller들을 가져옴
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    final authController = Provider.of<AuthController>(context, listen: false);
    final commentController = Provider.of<CommentController>(
      context,
      listen: false,
    );

    return Scaffold(
      // 상단 AppBar 빌드
      appBar: _buildAppBar(categoryController),
      body: FutureBuilder<String>(
        // Firestore에서 사용자의 닉네임을 가져옴
        future: authController.getIdFromFirestore(),
        builder: (context, nicknameSnapshot) {
          return SingleChildScrollView(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // 선택된 카테고리에 속한 사진 목록을 실시간으로 불러오는 Stream
              stream: categoryController.getPhotosStream(widget.categoryId),
              builder: (context, photosSnapshot) {
                // 로딩 중인 경우
                if (photosSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // 에러 발생 시
                if (photosSnapshot.hasError) {
                  return Center(child: Text('Error: ${photosSnapshot.error}'));
                }

                // 사진 데이터가 있을 경우, 맵을 PhotoModel 객체로 변환
                final List<PhotoModel> photos =
                    (photosSnapshot.data ?? [])
                        .map(
                          (photoMap) => PhotoModel(
                            id: photoMap['id'] ?? '',
                            imageUrl: photoMap['imageUrl'] ?? '',
                            audioUrl: photoMap['audioUrl'] ?? '',
                            userID:
                                photoMap['userId'] ??
                                '', // Map uses 'userId', but class expects 'userID'
                            createdAt:
                                photoMap['createdAt'] ??
                                Timestamp.now(), // Default to current timestamp if null
                            userIds:
                                (photoMap['userIds'] as List<dynamic>?)
                                    ?.cast<String>() ??
                                [], // Convert to List<String> and provide empty list if null
                          ),
                        )
                        .toList();

                // 사진이 비어있을 경우
                if (photos.isEmpty) {
                  return const Center(child: Text('아직 등록된 사진이 없습니다.'));
                }

                // 사진이 있을 경우, 버튼 및 사진 그리드 구성
                return Column(
                  children: [
                    _buildPhotoGrid(
                      context,
                      photos,
                      categoryController,
                      commentController,
                      nicknameSnapshot.data,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// 카테고리 이름을 앱바에 표시하는 AppBar 위젯
  AppBar _buildAppBar(CategoryController categoryController) {
    return AppBar(
      title: FutureBuilder<String>(
        // 카테고리 ID로부터 카테고리 이름을 가져옴
        future: categoryController.getCategoryName(widget.categoryId),
        builder: (context, categoryNameSnapshot) {
          // 로딩 중인 경우
          if (categoryNameSnapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          // 에러 발생 시
          if (categoryNameSnapshot.hasError) {
            return const Text('예상치 못한 에러가 발생했습니다. 앱을 다시 실행하세요.');
          }
          // 카테고리 이름이 설정되지 않은 경우
          if (!categoryNameSnapshot.hasData ||
              categoryNameSnapshot.data == null) {
            return const Text('카테고리 이름을 먼저 설정하세요!');
          }
          // 정상적으로 카테고리 이름이 있을 때
          return Text(categoryNameSnapshot.data!);
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.camera),
          // 카메라 아이콘 버튼 클릭 시 CameraScreen으로 이동
          onPressed: () async {},
        ),
      ],
    );
  }

  /// 사진을 그리드 형태로 보여주는 메서드
  Widget _buildPhotoGrid(
    BuildContext context,
    List<PhotoModel> photos,
    CategoryController categoryController,
    CommentController commentController,
    String? nickname,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 한 행에 2개씩
        crossAxisSpacing: 8, // 열 간격
        mainAxisSpacing: 8, // 행 간격
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        // 이미지 URL이 비어있다면 표시하지 않음
        if (photo.imageUrl.isEmpty) return const SizedBox();
        return _buildPhotoItem(
          context,
          photo,
          categoryController,
          commentController,
          nickname,
        );
      },
    );
  }

  /// 그리드의 각 사진 아이템 위젯
  Widget _buildPhotoItem(
    BuildContext context,
    PhotoModel photo,
    CategoryController categoryController,
    CommentController commentController,
    String? nickname,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // 사진 클릭 시 상세 Dialog 호출
      child: GestureDetector(
        onTap:
            () => _showPhotoDialog(
              context,
              photo,
              categoryController,
              commentController,
              nickname,
            ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: CachedNetworkImage(
            imageUrl: photo.imageUrl,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  void _showPhotoDialog(
    BuildContext context,
    PhotoModel photo,
    CategoryController categoryController,
    CommentController commentController,
    String? nickname,
  ) {
    // Get AuthController instance
    final authController = Provider.of<AuthController>(context, listen: false);

    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: commentController.fetchComments(
                widget.categoryId,
                photo.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error fetching comments'));
                }

                final comments = snapshot.data!;
                return StatefulBuilder(
                  builder: (context, setState) {
                    IconData playIcon = Icons.play_arrow;
                    AudioPlayer audioPlayer = AudioPlayer();

                    void playAudio(String audioUrl) async {
                      await audioPlayer.play(UrlSource(audioUrl));
                      setState(() {
                        playIcon = Icons.pause;
                      });
                    }

                    void pauseAudio() async {
                      await audioPlayer.pause();
                      setState(() {
                        playIcon = Icons.play_arrow;
                      });
                    }

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.network(
                            photo.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                          ElevatedButton(
                            child: const Text('음성녹음 듣기'),
                            onPressed: () async {
                              playAudio(photo.audioUrl);
                            },
                          ),
                          ElevatedButton(
                            child: const Text('음성 답글 달기'),
                            onPressed: () async {
                              if (commentController.isRecording) {
                                await commentController.stopRecording();
                                final currentUserId =
                                    authController.getUserId ?? "";

                                // uploadAudio returns a bool, not a String
                                final success = await commentController
                                    .uploadAudio(
                                      widget.categoryId,
                                      photo.id,
                                      nickname ?? "",
                                      currentUserId,
                                    );

                                final String? audioUrl =
                                    commentController.audioFilePath;

                                final photoDocumentId = await categoryController
                                    .getPhotoDocumentId(
                                      widget.categoryId,
                                      photo.imageUrl,
                                    );

                                if (photoDocumentId != null &&
                                    audioUrl != null &&
                                    success) {
                                  await commentController.uploadAudio(
                                    widget.categoryId,
                                    photoDocumentId,
                                    nickname ?? 'unknown_user',
                                    currentUserId,
                                  );
                                }
                              } else {
                                await commentController.startRecording();
                              }
                            },
                          ),
                          const Text('Comments:'),
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return ListTile(
                                title: Text(comment['userNickname']),
                                subtitle: Text(
                                  comment['createdAt'].toDate().toString(),
                                ),
                                trailing: IconButton(
                                  icon: Icon(playIcon),
                                  onPressed: () {
                                    if (playIcon == Icons.play_arrow) {
                                      playAudio(comment['audioUrl']);
                                    } else {
                                      pauseAudio();
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
    );
  }
}
