import 'package:share_plus/share_plus.dart';

/// 공유 관련 기능을 담당하는 서비스
class ShareService {
  /// 단순 링크 공유
  Future<void> shareLink(String link, {String? message}) async {
    final uri = Uri.tryParse(link);
    final shareParams = _buildParams(uri, link, message);

    await SharePlus.instance.share(shareParams);
  }

  ShareParams _buildParams(Uri? uri, String link, String? message) {
    if (message != null && message.trim().isNotEmpty) {
      final text = message.contains(link) ? message : '${message.trim()}\n$link';
      return ShareParams(text: text.trim());
    }

    if (uri != null) {
      return ShareParams(uri: uri);
    }

    return ShareParams(text: link);
  }
}
