import 'package:flutter/material.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/contact_controller.dart';
import '../../controllers/user_matching_controller.dart';
import '../../controllers/friend_request_controller.dart';
import '../../models/friend_request_model.dart';
import '../../services/contact_service.dart';
import '../../services/user_matching_service.dart';

class FriendManagementScreen extends StatefulWidget {
  const FriendManagementScreen({super.key});

  @override
  State<FriendManagementScreen> createState() => _FriendManagementScreenState();
}

class _FriendManagementScreenState extends State<FriendManagementScreen> {
  List<Contact> _contacts = [];

  // ✅ 백그라운드 로딩을 위한 상태 변수들 추가
  bool _isInitializing = false;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // ✅ 화면을 즉시 표시하고 백그라운드에서 초기화 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeContactPermissionInBackground();
    });
  }

  /// ✅ 백그라운드에서 연락처 권한 및 초기화 처리 (화면 전환 지연 방지)
  Future<void> _initializeContactPermissionInBackground() async {
    if (_hasInitialized) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      if (!mounted) return;

      final contactController = Provider.of<ContactController>(
        context,
        listen: false,
      );

      // ✅ 1단계: 권한 확인 (빠른 처리)
      final result = await contactController.initializeContactPermission();

      // ✅ 2단계: 권한이 허용된 경우에만 연락처 로드 (느린 처리)
      if (result.isEnabled && mounted) {
        try {
          _contacts = await contactController.getContacts();
          debugPrint('연락처 로드 성공: ${_contacts}');
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          debugPrint('연락처 로드 실패: $e');
        }
      }

      // ✅ 3단계: 초기화 완료 및 메시지 표시
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasInitialized = true;
        });
        _showInitSnackBar(result.message, result.type);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasInitialized = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('초기화 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 연락처 목록 새로고침
  Future<void> _refreshContacts() async {
    try {
      if (!mounted) return;

      final contactController = Provider.of<ContactController>(
        context,
        listen: false,
      );
      if (contactController.contactSyncEnabled) {
        _contacts = await contactController.getContacts();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('연락처 새로고침 실패: $e');
    }
  }

  /// 토글 클릭 시 처리
  Future<void> _handleToggleChange(ContactController contactController) async {
    final result = await contactController.handleToggleChange();

    if (result.type == ContactToggleResultType.requiresSettings) {
      // 설정 이동 팝업 표시
      _showPermissionSettingsDialog();
    } else {
      // 토글 상태가 변경된 경우 연락처 목록 새로고침
      if (result.isEnabled) {
        await _refreshContacts();
      } else {
        // 연락처 동기화가 비활성화된 경우 목록 초기화
        _contacts.clear();
        if (mounted) {
          setState(() {});
        }
      }

      if (mounted) {
        _showSnackBar(result.message, result.type);
      }
    }
  }

  /// SnackBar 표시 (결과 타입에 따른 색상)
  void _showSnackBar(String message, ContactToggleResultType type) {
    Color backgroundColor;

    switch (type) {
      case ContactToggleResultType.success:
        backgroundColor = const Color(0xff404040);
        break;
      case ContactToggleResultType.failure:
        backgroundColor = Colors.orange;
        break;
      case ContactToggleResultType.error:
        backgroundColor = Colors.red;
        break;
      case ContactToggleResultType.requiresSettings:
        backgroundColor = Colors.orange;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  /// 초기화 결과 SnackBar 표시
  void _showInitSnackBar(String message, ContactInitResultType type) {
    Color backgroundColor;

    switch (type) {
      case ContactInitResultType.success:
        backgroundColor = const Color(0xff404040);
        break;
      case ContactInitResultType.failure:
        backgroundColor = Colors.orange;
        break;
      case ContactInitResultType.error:
        backgroundColor = Colors.red;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  /// 설정 이동 팝업 다이얼로그
  void _showPermissionSettingsDialog() {
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
                await _openAppSettings();
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

  /// 앱 설정 화면 열기
  Future<void> _openAppSettings() async {
    try {
      await openAppSettings();

      // 설정에서 돌아왔을 때 권한 상태 재확인
      Future.delayed(const Duration(seconds: 1), () async {
        if (!mounted) return;

        final contactController = Provider.of<ContactController>(
          context,
          listen: false,
        );
        final result = await contactController.checkPermissionAfterSettings();
        if (mounted) {
          _showSnackBar(result.message, result.type);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('설정 화면을 열 수 없습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 UI를 위한 화면 너비 및 스케일 팩터 계산
    final screenWidth = MediaQuery.of(context).size.width;
    const double referenceWidth = 393;
    final double scale = screenWidth / referenceWidth;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xffd9d9d9)),
      ),
      body: Consumer<ContactController>(
        builder: (context, contactController, child) {
          return SingleChildScrollView(
            // 전체적인 좌우 패딩을 반응형으로 적용
            padding: EdgeInsets.symmetric(horizontal: 16 * scale),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 페이지 제목
                Padding(
                  padding: EdgeInsets.only(
                    left: 17 * scale,
                    bottom: 11 * scale,
                  ),
                  child: Text(
                    '친구추가',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // 친구 추가 옵션 카드 위젯 함수 호출
                _buildFriendAddOptionsCard(context, scale, contactController),

                SizedBox(height: 24 * scale),

                Padding(
                  padding: EdgeInsets.only(
                    left: 17 * scale,
                    bottom: 11 * scale,
                  ),
                  child: Text(
                    '초대링크',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 18.02 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // 가로 스크롤 링크 카드 목록
                _buildLinkCard(context, scale),

                SizedBox(height: 24 * scale),

                Padding(
                  padding: EdgeInsets.only(
                    left: 17 * scale,
                    bottom: 11 * scale,
                  ),
                  child: Text(
                    '친구 요청',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 18.02 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildRequestCard(context, scale),
                SizedBox(height: 24 * scale),
                Padding(
                  padding: EdgeInsets.only(
                    left: 17 * scale,
                    bottom: 11 * scale,
                  ),
                  child: Text(
                    '친구 목록',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 18.02 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildFriendListCard(context, scale),
                SizedBox(height: 24 * scale),
                Padding(
                  padding: EdgeInsets.only(
                    left: 17 * scale,
                    bottom: 11 * scale,
                  ),
                  child: Text(
                    '친구 추천',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 18.02 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildFriendSuggestCard(context, scale),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 친구 추가 옵션 카드 위젯
  Widget _buildFriendAddOptionsCard(
    BuildContext context,
    double scale,
    ContactController contactController,
  ) {
    return Card(
      color: const Color(0xff1c1c1c),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Column(
        children: [
          // 연락처 동기화
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 18 * scale,
              vertical: 12 * scale,
            ),
            child: Row(
              children: [
                // 아이콘
                Container(
                  width: 44 * scale,
                  height: 44 * scale,
                  decoration: const BoxDecoration(
                    color: Color(0xff323232),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.contacts_outlined,
                    color: const Color(0xfff9f9f9),
                    size: 24 * scale,
                  ),
                ),
                SizedBox(width: 9 * scale),

                // 텍스트
                Expanded(
                  child: Text(
                    '연락처 동기화',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                // 토글 스위치 또는 로딩 스피너
                Transform.scale(
                  scale: scale,
                  child:
                      contactController.isLoading
                          ? SizedBox(
                            width: 24 * scale,
                            height: 24 * scale,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Switch(
                            value: contactController.contactSyncEnabled,
                            onChanged: (value) {
                              _handleToggleChange(
                                contactController,
                              ); // ContactController 전달
                            },
                            activeColor: Colors.white,
                            activeTrackColor: const Color(0xff404040),
                            inactiveThumbColor: const Color(0xff666666),
                            inactiveTrackColor: const Color(0xff2a2a2a),
                          ),
                ),
              ],
            ),
          ),

          // 구분선
          const Divider(color: Color(0xff404040), height: 1, thickness: 1),

          // ID로 추가 하기
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ID로 추가 하기 기능을 구현해주세요'),
                  backgroundColor: Color(0xff404040),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 18 * scale,
                vertical: 12 * scale,
              ),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    width: 44 * scale,
                    height: 44 * scale,
                    decoration: const BoxDecoration(
                      color: Color(0xff323232),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'ID',
                        style: TextStyle(
                          color: const Color(0xfff9f9f9),
                          fontSize: 25 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 9 * scale),

                  // 텍스트 (수정됨)
                  Expanded(
                    child: Text(
                      'ID로 추가 하기',
                      style: TextStyle(
                        color: const Color(0xfff9f9f9),
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  // 화살표 아이콘 (추가됨)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: const Color(0xff666666),
                    size: 16 * scale,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(BuildContext context, double scale) {
    return SizedBox(
      width: 354 * scale,
      height: 132 * scale,
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: const Color(0xff1c1c1c),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12 * scale),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 18 * scale),
              _buildLinkCardContent(context, scale, '랑크 복사', 'assets/link.png'),
              SizedBox(width: 21.24 * scale),
              _buildLinkCardContent(context, scale, '공유', 'assets/share.png'),
              SizedBox(width: 21.24 * scale),
              _buildLinkCardContent(context, scale, '카카오톡', 'assets/kakao.png'),
              SizedBox(width: 21.24 * scale),
              _buildLinkCardContent(
                context,
                scale,
                '인스타그램',
                'assets/insta.png',
              ),
              SizedBox(width: 21.24 * scale),
              _buildLinkCardContent(
                context,
                scale,
                '메세지',
                'assets/message.png',
              ),
              SizedBox(width: 18 * scale),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkCardContent(
    BuildContext context,
    double scale,
    String title,
    String imagePath,
  ) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공유 기능을 구현해주세요'),
            backgroundColor: Color(0xff404040),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Image.asset(
              imagePath,
              width: 51.76 * scale,
              height: 51.76 * scale,
            ),
          ),
          SizedBox(height: 7.24 * scale),
          Text(
            title,
            style: TextStyle(
              color: const Color(0xfff9f9f9),
              fontSize: 12 * scale,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 사용자에게 들어온 친구 요청들
  Widget _buildRequestCard(BuildContext context, double scale) {
    return Consumer<FriendRequestController>(
      builder: (context, friendRequestController, child) {
        final receivedRequests = friendRequestController.receivedRequests;

        return SizedBox(
          width: 354 * scale,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child:
                receivedRequests.isEmpty
                    ? SizedBox(
                      height: 132 * scale,
                      child: Center(
                        child: Text(
                          '받은 친구 요청이 없습니다',
                          style: TextStyle(
                            color: const Color(0xff666666),
                            fontSize: 14 * scale,
                          ),
                        ),
                      ),
                    )
                    : Column(
                      children:
                          receivedRequests.map((request) {
                            return _buildFriendRequestItem(
                              context,
                              scale,
                              request,
                              friendRequestController,
                            );
                          }).toList(),
                    ),
          ),
        );
      },
    );
  }

  /// 개별 친구 요청 아이템 위젯
  Widget _buildFriendRequestItem(
    BuildContext context,
    double scale,
    FriendRequestModel request,
    FriendRequestController controller,
  ) {
    final isProcessing = controller.isProcessingRequest(request.id);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 18 * scale,
        vertical: 12 * scale,
      ),
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 22 * scale,
            backgroundColor: const Color(0xff323232),
            child: Text(
              request.senderNickname.isNotEmpty
                  ? request.senderNickname[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: const Color(0xfff9f9f9),
                fontSize: 16 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 12 * scale),

          // 사용자 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.senderNickname.isNotEmpty
                      ? request.senderNickname
                      : '알 수 없는 사용자',
                  style: TextStyle(
                    color: const Color(0xffd9d9d9),
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (request.message != null && request.message!.isNotEmpty) ...[
                  SizedBox(height: 4 * scale),
                  Text(
                    request.message!,
                    style: TextStyle(
                      color: const Color(0xff999999),
                      fontSize: 13 * scale,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 4 * scale),
                Text(
                  _formatRequestTime(request.createdAt),
                  style: TextStyle(
                    color: const Color(0xff666666),
                    fontSize: 12 * scale,
                  ),
                ),
              ],
            ),
          ),

          // 수락/거절 버튼
          if (isProcessing) ...[
            SizedBox(
              width: 24 * scale,
              height: 24 * scale,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xfff9f9f9),
              ),
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 거절 버튼
                SizedBox(
                  width: 60 * scale,
                  height: 32 * scale,
                  child: ElevatedButton(
                    onPressed:
                        () => _rejectFriendRequest(request.id, controller),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff333333),
                      foregroundColor: const Color(0xff999999),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6 * scale),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      '거절',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8 * scale),
                // 수락 버튼
                SizedBox(
                  width: 60 * scale,
                  height: 32 * scale,
                  child: ElevatedButton(
                    onPressed:
                        () => _acceptFriendRequest(request.id, controller),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xfff9f9f9),
                      foregroundColor: const Color(0xff1c1c1c),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6 * scale),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      '수락',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 친구 요청 수락
  Future<void> _acceptFriendRequest(
    String requestId,
    FriendRequestController controller,
  ) async {
    final success = await controller.acceptFriendRequest(requestId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('친구 요청을 수락했습니다'),
          backgroundColor: Color(0xff404040),
        ),
      );
    }
  }

  /// 친구 요청 거절
  Future<void> _rejectFriendRequest(
    String requestId,
    FriendRequestController controller,
  ) async {
    final success = await controller.rejectFriendRequest(requestId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('친구 요청을 거절했습니다'),
          backgroundColor: Color(0xff666666),
        ),
      );
    }
  }

  /// 요청 시간 포맷팅
  String _formatRequestTime(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  // 사용자가 추가한 친구 목록
  Widget _buildFriendListCard(BuildContext context, double scale) {
    return SizedBox(
      width: 354 * scale,
      height: 132 * scale,
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: const Color(0xff1c1c1c),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12 * scale),
        ),
        child: const Center(
          child: Text('친구 목록', style: TextStyle(color: Color(0xfff9f9f9))),
        ),
      ),
    );
  }

  // 친구 추천
  Widget _buildFriendSuggestCard(BuildContext context, double scale) {
    return Consumer<ContactController>(
      builder: (context, contactController, child) {
        return SizedBox(
          width: 354 * scale,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: _buildFriendSuggestContent(
              context,
              scale,
              contactController,
            ),
          ),
        );
      },
    );
  }

  /// ✅ 친구 추천 카드 콘텐츠 (로딩 상태 개선)
  Widget _buildFriendSuggestContent(
    BuildContext context,
    double scale,
    ContactController contactController,
  ) {
    // ✅ 초기화 진행 중일 때
    if (_isInitializing) {
      return Container(
        padding: EdgeInsets.all(40 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24 * scale,
              height: 24 * scale,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xfff9f9f9),
              ),
            ),
            SizedBox(height: 16 * scale),
            Text(
              '연락처에서 친구를 찾는 중...',
              style: TextStyle(
                color: const Color(0xff666666),
                fontSize: 14 * scale,
              ),
            ),
          ],
        ),
      );
    }

    // ✅ 연락처 동기화가 활성화되어 있고 연락처가 있는 경우
    if (contactController.contactSyncEnabled && _contacts.isNotEmpty) {
      return Column(
        children:
            _contacts.map((contact) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xff323232),
                  child: Text(
                    contact.displayName.isNotEmpty
                        ? contact.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                title: Text(
                  contact.displayName.isNotEmpty
                      ? contact.displayName
                      : '이름 없음',
                  style: TextStyle(
                    color: const Color(0xffd9d9d9),
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                subtitle: () {
                  try {
                    final phones = contact.phones;
                    return phones.isNotEmpty
                        ? Text(
                          phones.first.number,
                          style: TextStyle(
                            color: const Color(0xff666666),
                            fontSize: 14 * scale,
                          ),
                        )
                        : null;
                  } catch (e) {
                    debugPrint('전화번호 접근 오류: $e');
                    return null;
                  }
                }(),
                trailing: SizedBox(
                  height: 29 * scale,
                  child: ElevatedButton(
                    onPressed: () {
                      _addFriendFromContact(contact);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        const Color(0xfff9f9f9),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13 * scale),
                        ),
                      ),
                    ),
                    child: Text(
                      '친구 추가',
                      style: TextStyle(
                        color: const Color(0xff1c1c1c),
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              );
            }).toList(),
      );
    }

    // ✅ 기본 상태 (연락처 동기화 비활성화 또는 연락처 없음)
    return Container(
      padding: EdgeInsets.all(20 * scale),
      child: Center(
        child: Text(
          contactController.contactSyncEnabled
              ? '연락처에서 친구를 찾을 수 없습니다'
              : '연락처 동기화를 활성화해주세요',
          style: TextStyle(
            color: const Color(0xff666666),
            fontSize: 14 * scale,
          ),
        ),
      ),
    );
  }

  /// 연락처에서 친구 추가
  Future<void> _addFriendFromContact(Contact contact) async {
    try {
      // UserMatchingController와 FriendRequestController 가져오기
      final userMatchingController = Provider.of<UserMatchingController>(
        context,
        listen: false,
      );
      final friendRequestController = Provider.of<FriendRequestController>(
        context,
        listen: false,
      );

      // 1. 해당 연락처가 SOI 사용자인지 확인
      final contactStatus = await userMatchingController.getContactSearchStatus(
        contact,
      );

      switch (contactStatus) {
        case ContactSearchStatus.canSendRequest:
          // SOI 사용자이고 친구 요청 가능
          // UserMatchingController를 통해 사용자 정보 다시 가져오기
          final matchedUser = await userMatchingController.findUserForContact(
            contact,
          );

          if (matchedUser != null) {
            debugPrint(
              '매칭된 사용자 찾음: ${matchedUser.uid}, ${matchedUser.nickname}',
            );
            final success = await friendRequestController.sendFriendRequest(
              receiverUid: matchedUser.uid,
              message: '${contact.displayName}님과 친구가 되고 싶어요!',
            );

            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${contact.displayName}님에게 친구 요청을 전송했습니다'),
                  backgroundColor: const Color(0xff404040),
                ),
              );
            }
          } else {
            // SOI 사용자이지만 정보를 찾을 수 없는 경우
            debugPrint('사용자 정보를 찾을 수 없음');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${contact.displayName}님의 정보를 확인하는 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
          break;

        case ContactSearchStatus.alreadyFriend:
          // 이미 친구인 경우
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${contact.displayName}님은 이미 친구입니다'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          break;

        case ContactSearchStatus.requestSent:
          // 이미 친구 요청을 보낸 경우
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${contact.displayName}님에게 이미 친구 요청을 보냈습니다'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          break;

        case ContactSearchStatus.requestReceived:
          // 상대방이 이미 친구 요청을 보낸 경우
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${contact.displayName}님으로부터 친구 요청이 와있습니다. 친구 요청 목록을 확인해주세요',
                ),
                backgroundColor: const Color(0xff404040),
              ),
            );
          }
          break;

        case ContactSearchStatus.notFound:
          // SOI 사용자가 아닌 경우 - SMS로 앱 설치 링크 전송
          await _sendInviteSMS(contact);
          break;

        case ContactSearchStatus.error:
          // 오류 발생
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${contact.displayName}님 정보를 확인하는 중 오류가 발생했습니다'),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
      }
    } catch (e) {
      debugPrint('친구 추가 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('친구 추가 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// SMS로 앱 설치 링크 전송
  Future<void> _sendInviteSMS(Contact contact) async {
    try {
      debugPrint('Contact 정보: ${contact.displayName}');
      debugPrint('Contact phones 길이: ${contact.phones.length}');

      // Contact의 전화번호 확인
      if (contact.phones.isEmpty) {
        debugPrint('전화번호가 없는 연락처: ${contact.displayName}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${contact.displayName}님의 전화번호가 없습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 첫 번째 전화번호 가져오기
      final phone = contact.phones.first;
      final phoneNumber = phone.number;

      debugPrint('전화번호: $phoneNumber');

      if (phoneNumber.isEmpty) {
        debugPrint('빈 전화번호: ${contact.displayName}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${contact.displayName}님의 유효한 전화번호가 없습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final appDownloadLink =
          'https://play.google.com/store/apps/details?id=com.soi.app'; // 실제 앱 스토어 링크로 변경
      final message =
          '안녕하세요! SOI 앱에서 친구 요청을 보내고 싶어요. 앱을 다운로드해보세요: $appDownloadLink';

      final uri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${contact.displayName}님에게 초대 메시지를 전송했습니다'),
              backgroundColor: const Color(0xff404040),
            ),
          );
        }
      } else {
        throw 'SMS 앱을 열 수 없습니다';
      }
    } catch (e) {
      debugPrint('SMS 전송 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메시지 전송 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
