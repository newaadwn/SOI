import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/photo_controller.dart';

/// ⏳ 피드 로딩 인디케이터 위젯
/// 무한 스크롤 시 추가 로딩 상태를 표시합니다.
class FeedLoadingIndicator extends StatelessWidget {
  const FeedLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoController>(
      builder: (context, photoController, child) {
        if (!photoController.isLoadingMore) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '추가 사진 로딩 중...',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
