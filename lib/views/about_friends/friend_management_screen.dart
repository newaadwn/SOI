import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/friend_request_controller.dart';
import '../../controllers/contact_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/friend_request_model.dart';
import '../../theme/theme.dart';

/// 친구 관리 메인 화면
/// 스크린샷과 같은 UI로 구성
class FriendManagementScreen extends StatefulWidget {
  const FriendManagementScreen({super.key});

  @override
  State<FriendManagementScreen> createState() => _FriendManagementScreenState();
}

class _FriendManagementScreenState extends State<FriendManagementScreen> {
  late FriendRequestController friendController;
  late ContactController contactController;
  late AuthController authController;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });
  }

  Future<void> _initializeControllers() async {
    friendController = Provider.of<FriendRequestController>(
      context,
      listen: false,
    );
    contactController = Provider.of<ContactController>(context, listen: false);
    authController = Provider.of<AuthController>(context, listen: false);

    // ContactController 먼저 초기화
    await contactController.initialize();

    // FriendRequestController 초기화 (ContactController 연동)
    final userId = authController.getUserId;
    if (userId != null) {
      await friendController.initialize(
        userId,
        contactController: contactController,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '친구 추가',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: Consumer3<
        FriendRequestController,
        ContactController,
        AuthController
      >(
        builder: (
          context,
          friendController,
          contactController,
          authController,
          child,
        ) {
          if (friendController.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 친구 추가 섹션
                _buildFriendAddSection(friendController, authController),

                const SizedBox(height: 24),

                // 초대 링크 섹션
                _buildInviteLinkSection(),

                const SizedBox(height: 24),

                // 친구 요청 섹션
                _buildFriendRequestsSection(friendController, authController),

                const SizedBox(height: 24),

                // 친구 목록 섹션
                _buildFriendsSection(friendController),

                const SizedBox(height: 24),

                // 친구 추천 섹션
                _buildFriendSuggestionsSection(
                  friendController,
                  authController,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 친구 추가 섹션
  Widget _buildFriendAddSection(
    FriendRequestController friendController,
    AuthController authController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '친구 추가',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // 연락처 동기화 토글
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.contacts, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '연락처 동기화',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              Switch(
                value: friendController.contactSyncEnabled,
                activeColor: Colors.yellow,
                onChanged: (value) async {
                  final userId = authController.getUserId;
                  if (userId != null) {
                    await friendController.toggleContactSync(userId);
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ID로 추가하기
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_add, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _idController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'ID로 추가하기',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  onSubmitted:
                      (value) =>
                          _sendFriendRequestByNickname(value, authController),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed:
                    () => _sendFriendRequestByNickname(
                      _idController.text,
                      authController,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 초대 링크 섹션
  Widget _buildInviteLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '초대 링크',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // 소셜 플랫폼 아이콘들
        Row(
          children: [
            _buildSocialIcon(Icons.message, Colors.yellow, '카카오톡'),
            const SizedBox(width: 16),
            _buildSocialIcon(Icons.share, Colors.blue, '공유'),
            const SizedBox(width: 16),
            _buildSocialIcon(Icons.camera_alt, Colors.purple, '인스타그램'),
            const SizedBox(width: 16),
            _buildSocialIcon(Icons.message, Colors.green, '메시지'),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color, String tooltip) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  /// 친구 요청 섹션
  Widget _buildFriendRequestsSection(
    FriendRequestController friendController,
    AuthController authController,
  ) {
    final receivedRequests = friendController.receivedRequests;

    if (receivedRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '친구 요청',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        ...receivedRequests
            .map((request) => _buildFriendRequestItem(request, authController))
            .toList(),
      ],
    );
  }

  Widget _buildFriendRequestItem(
    FriendRequestModel request,
    AuthController authController,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 프로필 이미지
          FutureBuilder<String>(
            future: authController.getUserProfileImageUrlById(
              request.fromUserId,
            ),
            builder: (context, snapshot) {
              return CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                backgroundImage:
                    snapshot.hasData && snapshot.data!.isNotEmpty
                        ? NetworkImage(snapshot.data!)
                        : null,
                child:
                    snapshot.hasData && snapshot.data!.isNotEmpty
                        ? null
                        : Text(
                          request.fromUserNickname.isNotEmpty
                              ? request.fromUserNickname[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
              );
            },
          ),

          const SizedBox(width: 12),

          // 사용자 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.fromUserNickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (request.message != null)
                  Text(
                    request.message!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),

          // 수락/거절 버튼
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                '수락',
                Colors.blue,
                () => _acceptFriendRequest(request.id, authController),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                '거절',
                Colors.grey,
                () => _rejectFriendRequest(request.id, authController),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onPressed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onPressed,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 친구 목록 섹션
  Widget _buildFriendsSection(FriendRequestController friendController) {
    final friends = friendController.friends;

    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '친구 목록 (${friends.length})',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        ...friends.take(5).map((friend) => _buildFriendItem(friend)).toList(),

        if (friends.length > 5)
          TextButton(
            onPressed: () {
              // 전체 친구 목록 보기
            },
            child: const Text('더보기', style: TextStyle(color: Colors.blue)),
          ),
      ],
    );
  }

  Widget _buildFriendItem(FriendModel friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey,
            backgroundImage:
                friend.profileImageUrl != null &&
                        friend.profileImageUrl!.isNotEmpty
                    ? NetworkImage(friend.profileImageUrl!)
                    : null,
            child:
                friend.profileImageUrl == null ||
                        friend.profileImageUrl!.isEmpty
                    ? Text(
                      friend.nickname.isNotEmpty
                          ? friend.nickname[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    )
                    : null,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '친구가 된 날: ${_formatDate(friend.becameFriendsAt)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onPressed: () {
              // 친구 옵션 메뉴
            },
          ),
        ],
      ),
    );
  }

  /// 친구 추천 섹션
  Widget _buildFriendSuggestionsSection(
    FriendRequestController friendController,
    AuthController authController,
  ) {
    final suggestions = friendController.friendSuggestions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '친구 추천',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (friendController.contactSyncEnabled)
              const Expanded(
                child: Text(
                  ' (연락처 기반)',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            IconButton(
              icon:
                  friendController.isGeneratingSuggestions
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 20,
                      ),
              onPressed: () async {
                final userId = authController.getUserId;
                if (userId != null) {
                  await friendController.refreshFriendSuggestions(userId);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (!friendController.contactSyncEnabled)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  '연락처를 동기화하면\n친구를 더 쉽게 찾을 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    final userId = authController.getUserId;
                    if (userId != null) {
                      await friendController.requestContactPermissionAndSync(
                        userId,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    '연락처 동기화하기',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        else if (suggestions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '추천할 친구가 없습니다.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          )
        else
          ...suggestions
              .map(
                (suggestion) =>
                    _buildSuggestionItem(suggestion, authController),
              )
              .toList(),
      ],
    );
  }

  Widget _buildSuggestionItem(
    FriendSuggestionModel suggestion,
    AuthController authController,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey,
            backgroundImage:
                suggestion.profileImageUrl != null &&
                        suggestion.profileImageUrl!.isNotEmpty
                    ? NetworkImage(suggestion.profileImageUrl!)
                    : null,
            child:
                suggestion.profileImageUrl == null ||
                        suggestion.profileImageUrl!.isEmpty
                    ? Text(
                      suggestion.nickname.isNotEmpty
                          ? suggestion.nickname[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.white),
                    )
                    : null,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (suggestion.reasons.isNotEmpty)
                  Text(
                    suggestion.reasons.first,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),

          _buildActionButton(
            '친구 추가',
            Colors.blue,
            () => _sendFriendRequestFromSuggestion(suggestion, authController),
          ),
        ],
      ),
    );
  }

  // ==================== 액션 메서드들 ====================

  Future<void> _sendFriendRequestByNickname(
    String nickname,
    AuthController authController,
  ) async {
    if (nickname.trim().isEmpty) return;

    final userId = authController.getUserId;
    final userNickname = await authController.getUserID();

    if (userId == null) return;

    final success = await friendController.sendFriendRequestByNickname(
      fromUserId: userId,
      fromUserNickname: userNickname,
      targetNickname: nickname.trim(),
    );

    if (success) {
      _idController.clear();
      _showSnackBar('친구 요청을 보냈습니다.');
    } else {
      _showSnackBar(friendController.error ?? '친구 요청 전송에 실패했습니다.');
    }
  }

  Future<void> _sendFriendRequestFromSuggestion(
    FriendSuggestionModel suggestion,
    AuthController authController,
  ) async {
    final userId = authController.getUserId;
    final userNickname = await authController.getUserID();

    if (userId == null) return;

    final success = await friendController.sendFriendRequestFromSuggestion(
      fromUserId: userId,
      fromUserNickname: userNickname,
      suggestion: suggestion,
    );

    if (success) {
      _showSnackBar('${suggestion.nickname}님에게 친구 요청을 보냈습니다.');
    } else {
      _showSnackBar(friendController.error ?? '친구 요청 전송에 실패했습니다.');
    }
  }

  Future<void> _acceptFriendRequest(
    String requestId,
    AuthController authController,
  ) async {
    final userId = authController.getUserId;
    if (userId == null) return;

    final success = await friendController.acceptFriendRequest(
      requestId: requestId,
      respondingUserId: userId,
    );

    if (success) {
      _showSnackBar('친구 요청을 수락했습니다.');
    } else {
      _showSnackBar(friendController.error ?? '친구 요청 수락에 실패했습니다.');
    }
  }

  Future<void> _rejectFriendRequest(
    String requestId,
    AuthController authController,
  ) async {
    final userId = authController.getUserId;
    if (userId == null) return;

    final success = await friendController.rejectFriendRequest(
      requestId: requestId,
      respondingUserId: userId,
    );

    if (success) {
      _showSnackBar('친구 요청을 거절했습니다.');
    } else {
      _showSnackBar(friendController.error ?? '친구 요청 거절에 실패했습니다.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1C1C1C),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _idController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
