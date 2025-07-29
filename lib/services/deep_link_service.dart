import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/friend_request_controller.dart';

class DeepLinkService {
  static final _appLinks = AppLinks();
  static bool _initialized = false;

  /// Deep Link 서비스 초기화
  static Future<void> initialize(BuildContext context) async {
    if (_initialized) return;

    try {
      // 앱이 실행 중일 때 링크 처리
      _appLinks.uriLinkStream.listen((uri) {
        _handleDeepLink(context, uri);
      });

      // 앱이 종료된 상태에서 링크로 실행될 때
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        // 앱이 완전히 로드된 후 처리하기 위해 지연
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLink(context, initialUri);
        });
      }

      _initialized = true;
      debugPrint('DeepLinkService 초기화 완료');
    } catch (e) {
      debugPrint('DeepLinkService 초기화 실패: $e');
    }
  }

  /// Deep Link 처리
  static void _handleDeepLink(BuildContext context, Uri uri) {
    debugPrint('Deep Link 수신: $uri');

    // soi://invite?inviter=친구이름&inviterId=uid&invitee=내이름
    if (uri.scheme == 'soi' && uri.host == 'invite') {
      final inviterName = uri.queryParameters['inviter'];
      final inviterId = uri.queryParameters['inviterId'];
      final inviteeName = uri.queryParameters['invitee'];

      if (inviterId != null && inviterName != null) {
        _showFriendRequestDialog(context, inviterName, inviterId, inviteeName);
      }
    }
  }

  /// 친구 요청 다이얼로그 표시
  static void _showFriendRequestDialog(
    BuildContext context,
    String inviterName,
    String inviterId,
    String? inviteeName,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                const Icon(Icons.person_add, color: Color(0xfff9f9f9)),
                const SizedBox(width: 8),
                const Text('친구 요청', style: TextStyle(color: Color(0xfff9f9f9))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$inviterName님이 SOI에서 친구 요청을 보냈습니다.',
                  style: const TextStyle(
                    color: Color(0xffd9d9d9),
                    fontSize: 16,
                  ),
                ),
                if (inviteeName != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '초대받은 사람: $inviteeName',
                    style: const TextStyle(
                      color: Color(0xff666666),
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  '친구 요청을 수락하시겠습니까?',
                  style: TextStyle(color: Color(0xffd9d9d9), fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  '나중에',
                  style: TextStyle(color: Color(0xff666666)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _acceptFriendRequest(context, inviterId, inviterName);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xfff9f9f9),
                  foregroundColor: const Color(0xff1c1c1c),
                ),
                child: const Text('수락'),
              ),
            ],
          ),
    );
  }

  /// 친구 요청 자동 수락
  static Future<void> _acceptFriendRequest(
    BuildContext context,
    String inviterId,
    String inviterName,
  ) async {
    try {
      final friendRequestController = Provider.of<FriendRequestController>(
        context,
        listen: false,
      );

      // 친구 요청 전송 (상호 친구 요청)
      final success = await friendRequestController.sendFriendRequest(
        receiverUid: inviterId,
        message: 'SOI 초대를 통해 친구가 되었습니다!',
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$inviterName님과 친구가 되었습니다!'),
            backgroundColor: const Color(0xff404040),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('친구 요청 처리 실패: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('친구 요청 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 초대 링크 생성
  static String generateInviteLink({
    required String currentUserName,
    required String currentUserId,
    required String inviteeName,
  }) {
    return 'https://soi-sns.web.app?'
        'inviter=${Uri.encodeComponent(currentUserName)}'
        '&inviterId=${Uri.encodeComponent(currentUserId)}'
        '&invitee=${Uri.encodeComponent(inviteeName)}';
  }
}
