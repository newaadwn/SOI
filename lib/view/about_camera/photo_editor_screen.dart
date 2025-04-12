import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../model/editable_text_model.dart';
import '../../theme/theme.dart';
import '../../view_model/auth_view_model.dart';
import '../../view_model/category_view_model.dart';
import '../../view_model/audio_view_model.dart';

class PhotoEditorScreen extends StatefulWidget {
  final String imagePath;
  final String categoryId;

  const PhotoEditorScreen({
    Key? key,
    required this.imagePath,
    required this.categoryId,
  }) : super(key: key);

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final GlobalKey _globalKey = GlobalKey();

  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;

  // 텍스트 요소 리스트
  final List<EditableTextElement> _textElements = [];

  String dropdownValue = '';

  TextEditingController captionStringController = TextEditingController();

  @override
  void dispose() {
    // 모든 텍스트 요소의 컨트롤러와 포커스 노드를 해제
    for (var element in _textElements) {
      element.controller.dispose();
      element.focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final audioViewModel = Provider.of<AudioViewModel>(context);
    final isRecording = audioViewModel.isRecording;

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: Colors.white, //색변경
        ),
        title: Text(
          'SOI',
          style: TextStyle(color: AppTheme.lightTheme.colorScheme.secondary),
        ),
        actions: [_photoEditButton()],
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        toolbarHeight: 70,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 51),

                // 캡처 영역
                Stack(
                  children: [
                    RepaintBoundary(
                      key: _globalKey,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(widget.imagePath),
                          width: (261 / 393) * mediaQuery.size.width,
                          height: (451 / 852) * mediaQuery.size.height,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 250,
                      left: 75,
                      child: isRecording
                          ? SizedBox(
                              height: 100,
                              child: Lottie.asset(
                                'assets/recording_ui.json',
                                repeat: true,
                                animate: true,
                              ),
                            )
                          : SizedBox(),
                    ),
                  ],
                ),

                TextField(
                  style: AppTheme.lightTheme.textTheme.labelMedium!.copyWith(
                    color: Color(0xff535252),
                  ),
                  decoration: InputDecoration(
                    hintText: '켑션 추가하기...',
                    hintStyle:
                        AppTheme.lightTheme.textTheme.labelMedium!.copyWith(
                      color: Color(0xff535252),
                    ),
                    border: InputBorder.none,
                  ),
                  textAlign: TextAlign.center,
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () async {
                        if (isRecording) {
                          await audioViewModel.stopRecording();
                        } else {
                          await audioViewModel.startRecording();
                        }
                      },
                      icon: SizedBox(
                        width: 52,
                        height: 52,
                        child: Image.asset('assets/recording_ui.png'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 상단 '공유하기' / '추가하기 +' 버튼
  Widget _photoEditButton() {
    return Row(
      children: [
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.share, color: Colors.white),
        ),
        IconButton(
          onPressed: () async {
            // 1. 캡처 영역 데이터를 미리 가져옵니다.
            final boundary = _globalKey.currentContext?.findRenderObject()
                as RenderRepaintBoundary?;
            if (boundary == null) return;
            final capturedImageFuture = boundary.toImage(pixelRatio: 2.0);

            // 2. 필요한 Provider 데이터도 미리 받아옵니다.
            final categoryViewModel =
                Provider.of<CategoryViewModel>(context, listen: false);
            final authViewModel =
                Provider.of<AuthViewModel>(context, listen: false);
            final audioViewModel =
                Provider.of<AudioViewModel>(context, listen: false);

            // 3. 카테고리 id와 닉네임 등 미리 캡처 (필요 시)
            final currentCategoryId = widget.categoryId;
            final nickName = await authViewModel.getNickNameFromFirestore();
            final audioFilePath = audioViewModel.audioFilePath;

            // 4. 화면을 즉시 pop 합니다.
            Navigator.pop(context);

            // 5. pop 이후에 백그라운드로 저장 작업을 진행합니다.
            categoryViewModel.saveEditedPhoto(
              capturedImageFuture,
              currentCategoryId,
              nickName,
              audioFilePath,
              audioViewModel,
              captionStringController.text,
            );
          },
          icon: Icon(Icons.file_download_outlined, color: Colors.white),
        )
      ],
    );
  }
}
