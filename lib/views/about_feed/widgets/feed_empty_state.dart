import 'package:flutter/material.dart';

/// 📭 피드 빈 상태 위젯
/// 로딩 상태와 빈 피드 상태를 표시합니다.
class FeedEmptyState extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onRetry;

  const FeedEmptyState({super.key, required this.isLoading, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('사진을 불러오는 중...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 80),
          SizedBox(height: 16),
          Text(
            '아직 사진이 없어요',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '친구들과 카테고리를 만들고\n첫 번째 사진을 공유해보세요!',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                debugPrint('🔄 수동 리로드 시작');
                onRetry!();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
              child: Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }
}
