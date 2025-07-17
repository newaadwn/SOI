import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/friend_request_controller.dart';
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
    authController = Provider.of<AuthController>(context, listen: false);

    // FriendRequestController 초기화
    final userId = authController.getUserId;
    if (userId != null) {
      await friendController.initialize(userId);

      // 📱 자동으로 연락처 권한 확인 및 요청
      debugPrint('🔄 자동 연락처 권한 확인 시작');

      // 1. 먼저 권한 상태 확인
      final hasPermission = await friendController.checkContactPermission();
      debugPrint('📋 현재 연락처 권한 상태: $hasPermission');

      if (!hasPermission) {
        // 2. 권한이 없으면 영구적으로 거부되었는지 확인
        final isPermanentlyDenied = await friendController.isPermissionPermanentlyDenied;
        debugPrint('🔒 권한 영구 거부 상태: $isPermanentlyDenied');

        if (!isPermanentlyDenied) {
          // 3. 영구적으로 거부되지 않았으면 자동으로 요청
          debugPrint('🔓 연락처 권한 자동 요청 시작');
          final granted = await friendController.requestContactPermission();
          debugPrint('📱 연락처 권한 요청 결과: $granted');

          if (granted) {
            // 4. 권한이 허용되면 연락처 목록 로드
            debugPrint('✅ 연락처 권한 허용됨 - 연락처 목록 로드 시작');
            await friendController.loadContactList();
            debugPrint(
              '📇 연락처 목록 로드 완료: ${friendController.contactList.length}개',
            );
          } else {
            debugPrint('❌ 연락처 권한 거부됨');
          }
        } else {
          debugPrint('⚠️ 연락처 권한이 영구적으로 거부됨 - 사용자에게 설정 안내');
        }
      } else {
        // 권한이 이미 있으면 바로 연락처 목록 로드
        debugPrint('✅ 연락처 권한 이미 있음 - 연락처 목록 로드 시작');
        await friendController.loadContactList();
        debugPrint('📇 연락처 목록 로드 완료: ${friendController.contactList.length}개');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),

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
      body: Consumer2<FriendRequestController, AuthController>(
        builder: (context, friendController, authController, child) {
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

                // 연락처 목록 섹션 (새로운 단순한 방식)
                _buildContactListSection(friendController, authController),
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

        const SizedBox(height: 12),

        // 📞 전화번호로 추가하기
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.phone, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '전화번호로 추가하기 (예: 01012345678)',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  onSubmitted:
                      (value) =>
                          _sendFriendRequestByPhone(value, authController),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed:
                    () => _sendFriendRequestByPhone(
                      _phoneController.text,
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

  /// 연락처 목록 섹션 (새로운 단순한 방식)
  Widget _buildContactListSection(
    FriendRequestController friendController,
    AuthController authController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.contacts, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text(
              '연락처 목록',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // 연락처 권한 상태 표시
            if (friendController.hasContactPermission)
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    '동기화됨',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () async {
                      await friendController.refreshContactList();
                    },
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: '새로고침',
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        // 🔄 초기 로딩 중인 경우 (권한 요청 + 연락처 로딩)
        if (friendController.isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text(
                  '연락처 정보를 불러오는 중...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '연락처 권한을 확인하고 목록을 로드하고 있습니다',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

        // 📱 연락처 권한이 거부된 경우만 권한 요청 UI 표시
        if (!friendController.isLoading &&
            !friendController.hasContactPermission)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.contacts_outlined,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  '연락처 접근 권한 필요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '연락처에 저장된 친구들을 찾기 위해\n연락처 접근 권한이 필요합니다',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (friendController.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    friendController.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final granted =
                            await friendController.requestContactPermission();
                        if (granted) {
                          await friendController.loadContactList();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        '권한 요청',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await friendController.openAppSettings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        '설정으로 이동',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // 📇 연락처 목록 로딩 중인 경우 (권한은 있지만 연락처 로딩 중)
        if (friendController.hasContactPermission &&
            friendController.isLoadingContacts)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    '연락처 목록을 불러오는 중...',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        // 📭 연락처 목록이 비어있는 경우
        if (friendController.hasContactPermission &&
            !friendController.isLoadingContacts &&
            friendController.contactList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.contacts_outlined, color: Colors.grey, size: 48),
                SizedBox(height: 12),
                Text(
                  '연락처가 없습니다',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '기기에 저장된 연락처가 없거나\n전화번호가 없는 연락처입니다',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

        // 📋 연락처 목록 표시
        if (friendController.hasContactPermission &&
            !friendController.isLoadingContacts &&
            friendController.contactList.isNotEmpty) ...[
          // 연락처 개수 표시
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '총 ${friendController.contactList.length}명의 연락처',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          // 연락처 목록
          ...friendController.contactList
              .map((contact) => _buildContactItem(contact, authController))
              .toList(),
        ],
      ],
    );
  }

  Widget _buildContactItem(ContactItem contact, AuthController authController) {
    // ContactModel → ContactItem으로 변경
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
                contact.profileImageUrl != null &&
                        contact.profileImageUrl!.isNotEmpty
                    ? NetworkImage(contact.profileImageUrl!)
                    : null,
            child:
                contact.profileImageUrl == null ||
                        contact.profileImageUrl!.isEmpty
                    ? Text(
                      contact
                              .displayName
                              .isNotEmpty // nickname → displayName으로 변경
                          ? contact.displayName[0].toUpperCase()
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
                  contact.displayName, // nickname → displayName으로 변경
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '전화번호: ${contact.phoneNumber}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue),
            onPressed: () {
              _sendFriendRequestToContact(
                contact,
                authController,
              ); // 새로운 메서드 호출
            },
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

  /// 📞 전화번호로 친구 요청/초대 보내기 (추가 메서드)
  Future<void> _sendFriendRequestByPhone(
    String phoneNumber,
    AuthController authController,
  ) async {
    if (phoneNumber.trim().isEmpty) return;

    final userId = authController.getUserId;
    final userNickname = await authController.getUserID();

    if (userId == null) return;

    final success = await friendController.sendFriendRequestByPhone(
      fromUserId: userId,
      fromUserNickname: userNickname,
      phoneNumber: phoneNumber.trim(),
    );

    if (success) {
      _phoneController.clear();
      // 성공 메시지 사용 (SMS 초대 또는 친구 요청)
      final message = friendController.successMessage ?? '요청을 처리했습니다.';
      _showSnackBar(message);
    } else {
      _showSnackBar(friendController.error ?? '요청 처리에 실패했습니다.');
    }
  }

  /// 연락처로 친구 요청/초대 보내기 (새로운 메서드)
  Future<void> _sendFriendRequestToContact(
    ContactItem contact,
    AuthController authController,
  ) async {
    final userId = authController.getUserId;
    final userNickname = await authController.getUserID();

    if (userId == null) return;

    final success = await friendController.sendFriendRequestToContact(
      fromUserId: userId,
      fromUserNickname: userNickname,
      contact: contact,
    );

    if (success) {
      // 성공 메시지 사용 (SMS 초대 또는 친구 요청)
      final message =
          friendController.successMessage ??
          '${contact.displayName}님에게 요청을 보냈습니다.';
      _showSnackBar(message);
    } else {
      _showSnackBar(friendController.error ?? '요청 처리에 실패했습니다.');
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
