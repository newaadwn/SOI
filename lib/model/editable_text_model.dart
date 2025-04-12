// 텍스트 요소 데이터 모델
import 'package:flutter/material.dart';

class EditableTextElement {
  String text;
  Offset position;
  TextEditingController controller;
  FocusNode focusNode;
  bool isEmoji;

  EditableTextElement({
    required this.text,
    required this.position,
    required this.controller,
    required this.focusNode,
    this.isEmoji = false,
  });
}
