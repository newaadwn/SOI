import 'package:flutter/material.dart';

class PermissionSettingsDialog {
  static void show(BuildContext context, VoidCallback onOpenSettings) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1c1c1c),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '연락처 동기화 비활성화',
            style: TextStyle(
              color: Color(0xfff9f9f9),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            '연락처 동기화를 비활성화하려면 기기 설정에서 연락처 권한을 직접 해제해주세요.',
            style: TextStyle(color: Color(0xffd9d9d9)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                '취소',
                style: TextStyle(color: Color(0xff666666)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                onOpenSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff404040),
                foregroundColor: Colors.white,
              ),
              child: const Text('설정으로 이동'),
            ),
          ],
        );
      },
    );
  }
}
