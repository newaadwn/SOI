import 'dart:io';
import 'package:flutter/material.dart';

class PhotoEditorScreen extends StatefulWidget {
  final String imagePath;

  const PhotoEditorScreen({Key? key, required this.imagePath})
    : super(key: key);

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 354,
          height: 471,
          clipBehavior: Clip.antiAlias, // 이 설정은 유지합니다
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            // 이미지를 감싸는 ClipRRect 추가
            borderRadius: BorderRadius.circular(16), // 동일한 radius 적용
            child: Image.file(
              File(widget.imagePath),
              width: 354, // 명시적 너비 지정
              height: 471, // 명시적 높이 지정
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
