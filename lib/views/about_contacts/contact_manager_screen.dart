import 'package:flutter/material.dart';
import 'package:flutter_boxicons/flutter_boxicons.dart';
import 'package:provider/provider.dart';

import '../../controllers/contact_controller.dart';
import '../../controllers/friend_request_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/friend_request_model.dart';

class ContactManagerScreen extends StatefulWidget {
  const ContactManagerScreen({super.key});

  @override
  State<ContactManagerScreen> createState() => _ContactManagerScreenState();
}

class _ContactManagerScreenState extends State<ContactManagerScreen>
    with WidgetsBindingObserver {
  bool isContactSyncEnabled = true;
  late ContactController _contactController;

  @override
  void initState() {
    super.initState();
    _contactController = Provider.of<ContactController>(context, listen: false);
    WidgetsBinding.instance.addObserver(this);

    // 디버깅용 로그
    debugPrint('🔄 ContactManagerScreen 초기화 시작');

    // 초기 권한 상태 확인
    _checkPermissionStatus();

    // FriendRequestController 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFriendRequestController();
    });
  }

  @override
  void dispose() {
    // 앱 라이프사이클 옵저버 제거
    WidgetsBinding.instance.removeObserver(this);

    // 필요시 다이얼로그 강제 닫기 (안전하게)
    try {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('dispose 중 Navigator 정리 실패: $e');
    }

    // ContactController의 에러 상태 초기화
    try {
      _contactController.clearError();
    } catch (e) {
      debugPrint('dispose 중 ContactController 정리 실패: $e');
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 다시 활성화될 때 권한 상태 재확인
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  /// 권한 상태 확인
  Future<void> _checkPermissionStatus() async {
    if (!mounted) return;

    try {
      await _contactController.checkContactPermission();
      debugPrint('📱 연락처 권한 상태: ${_contactController.isContactSyncEnabled}');

      // 권한이 허용된 상태에서 돌아왔을 때 친구 추천 업데이트
      if (mounted && _contactController.isContactSyncEnabled) {
        await _initializeFriendRequestController();
      }
    } catch (e) {
      debugPrint('권한 상태 확인 오류: $e');
    }
  }

  /// FriendRequestController 초기화 및 상태 확인
  Future<void> _initializeFriendRequestController() async {
    try {
      final friendRequestController = context.read<FriendRequestController>();
      final authController = context.read<AuthController>();

      debugPrint('👤 현재 사용자: ${authController.currentUser?.uid}');
      debugPrint('🤝 FriendRequestController 상태:');
      debugPrint('  - 로딩: ${friendRequestController.isLoading}');
      debugPrint('  - 에러: ${friendRequestController.error}');
      debugPrint(
        '  - 친구 추천 수: ${friendRequestController.friendSuggestions.length}',
      );

      // 연락처 동기화가 활성화되어 있으면 친구 추천 생성 시도
      if (_contactController.isContactSyncEnabled &&
          authController.currentUser != null) {
        debugPrint('🔄 친구 추천 생성 시작...');
        await friendRequestController.generateFriendSuggestions(
          authController.currentUser!.uid,
          forceRefresh: true,
        );
        debugPrint(
          '✅ 친구 추천 생성 완료: ${friendRequestController.friendSuggestions.length}개',
        );
      } else {
        debugPrint('⚠️ 친구 추천 생성 조건 미충족:');
        debugPrint('  - 연락처 동기화: ${_contactController.isContactSyncEnabled}');
        debugPrint('  - 사용자 로그인: ${authController.currentUser != null}');
      }
    } catch (e) {
      debugPrint('❌ FriendRequestController 초기화 실패: $e');
    }
  }

  // 반응형 크기 계산을 위한 헬퍼 메서드들
  double _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 16.0; // 작은 화면
    if (screenWidth < 414) return 19.0; // 중간 화면
    return 24.0; // 큰 화면
  }

  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375; // iPhone X 기준
    return baseFontSize * scaleFactor.clamp(0.8, 1.2);
  }

  double _getResponsiveIconSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 360) return 40.0;
    if (screenWidth < 414) return 44.0;
    return 48.0;
  }

  double _getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scaleFactor = screenWidth / 375;
    return baseSpacing * scaleFactor.clamp(0.8, 1.2);
  }

  /// 연락처 동기화 활성화
  Future<void> _enableContactSync() async {
    if (!mounted) return;

    try {
      // 로딩 다이얼로그 표시
      _showLoadingDialog();

      // 1. 권한 요청
      await _contactController.requestContactPermission();

      if (!mounted) {
        _hideLoadingDialog();
        return;
      }

      if (_contactController.permissionDenied) {
        _hideLoadingDialog();
        _showPermissionDialog();
        return;
      }

      _hideLoadingDialog();

      if (_contactController.error != null) {
        _showErrorSnackBar(_contactController.error!);
      } else {
        _showSuccessSnackBar('연락처 동기화가 활성화되었습니다.');

        // 친구 추천 재생성
        if (mounted) {
          _initializeFriendRequestController();
        }
      }
    } catch (e) {
      debugPrint('연락처 동기화 오류: $e');
      if (mounted) {
        _hideLoadingDialog();
        _showErrorSnackBar('연락처 동기화 활성화 중 오류가 발생했습니다.');
      }
    }
  }

  /// 테스트용: 연락처 데이터 확인
  Future<void> _debugContactData() async {
    try {
      debugPrint('🔍 연락처 데이터 디버그 시작');

      // ContactController 상태 확인
      debugPrint('📱 ConnctController 상태:');
      debugPrint('  - 권한 상태: ${_contactController.isContactSyncEnabled}');
      debugPrint('  - 에러: ${_contactController.error}');

      // 연락처 목록 가져오기 시도
      if (_contactController.isContactSyncEnabled) {
        final contacts = _contactController.contacts;
        debugPrint('📞 연락처 수: ${contacts.length}');

        // 처음 5개 연락처 정보 출력
        for (int i = 0; i < contacts.length && i < 5; i++) {
          final contact = contacts[i];
          debugPrint(
            '  [$i] ${contact.displayName} - ${contact.phoneNumber.isNotEmpty ? contact.phoneNumber : "번호없음"}',
          );
        }
      }

      _showSuccessSnackBar('연락처 데이터가 디버그 로그에 출력되었습니다.');
    } catch (e) {
      debugPrint('❌ 연락처 데이터 디버그 실패: $e');
      _showErrorSnackBar('연락처 데이터 확인 중 오류가 발생했습니다.');
    }
  }

  /// 연락처 동기화 비활성화 (설정으로 안내)
  Future<void> _disableContactSync() async {
    _showPermissionDisableDialog();
  }

  /// 로딩 다이얼로그 표시
  void _showLoadingDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            backgroundColor: Color(0xFF1C1C1C),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFF8F8F8)),
                SizedBox(width: 16),
                Text(
                  '연락처 권한 확인 중...',
                  style: TextStyle(color: Color(0xFFF8F8F8)),
                ),
              ],
            ),
          ),
    );
  }

  /// 로딩 다이얼로그 숨기기
  void _hideLoadingDialog() {
    if (!mounted) return;

    // Navigator가 pop할 수 있는 상태인지 확인
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// 권한 요청 다이얼로그
  void _showPermissionDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1C),
            title: const Text(
              '권한 필요',
              style: TextStyle(color: Color(0xFFF8F8F8)),
            ),
            content: const Text(
              '연락처 동기화를 위해 연락처 접근 권한이 필요합니다.\n설정에서 권한을 허용해주세요.',
              style: TextStyle(color: Color(0xFFF8F8F8)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  '취소',
                  style: TextStyle(color: Color(0xFFc1c1c1)),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  }
                  _contactController.openAppSettings();
                },
                child: const Text(
                  '설정으로 이동',
                  style: TextStyle(color: Color(0xFFF8F8F8)),
                ),
              ),
            ],
          ),
    );
  }

  /// 권한 비활성화 안내 다이얼로그
  void _showPermissionDisableDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1C),
            title: const Text(
              '연락처 권한 관리',
              style: TextStyle(color: Color(0xFFF8F8F8)),
            ),
            content: const Text(
              '연락처 권한을 끄려면 기기 설정에서 변경해주세요.\n\n설정 > SOI > 연락처 접근 권한을 끄실 수 있습니다.',
              style: TextStyle(color: Color(0xFFF8F8F8)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  }
                },
                child: const Text(
                  '확인',
                  style: TextStyle(color: Color(0xFFc1c1c1)),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  }
                  _contactController.openAppSettings();
                },
                child: const Text(
                  '설정으로 이동',
                  style: TextStyle(color: Color(0xFFF8F8F8)),
                ),
              ),
            ],
          ),
    );
  }

  /// 성공 스낵바
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 에러 스낵바
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildContactCardAdd() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = _getResponsiveIconSize(context);
        final sidePadding = _getResponsiveSpacing(context, 18);
        final verticalSpacing = _getResponsiveSpacing(context, 12);
        final titleFontSize = _getResponsiveFontSize(context, 16);

        return Card(
          color: const Color(0xFF1C1C1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          child: Column(
            children: [
              // 연락처 동기화
              Column(
                children: [
                  SizedBox(height: verticalSpacing),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: sidePadding),
                    child: Row(
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFF323232),
                            borderRadius: BorderRadius.circular(iconSize / 2),
                          ),
                          child: Icon(
                            Boxicons.bxs_contact,
                            color: const Color(0xFFF9F9F9),
                            size: iconSize * 0.55,
                          ),
                        ),
                        SizedBox(width: _getResponsiveSpacing(context, 6)),
                        Expanded(
                          child: Text(
                            '연락처 동기화',
                            style: TextStyle(
                              color: const Color(0xFFF9F9F9),
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: constraints.maxWidth < 360 ? 0.8 : 1.0,
                          child: SizedBox(
                            width: _getResponsiveSpacing(context, 50),
                            height: _getResponsiveSpacing(context, 30),
                            child: Switch(
                              value:
                                  context
                                      .watch<ContactController>()
                                      .isContactSyncEnabled,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (value) async {
                                if (value) {
                                  // 연락처 동기화 활성화
                                  await _enableContactSync();
                                } else {
                                  // 연락처 동기화 비활성화
                                  await _disableContactSync();
                                }
                              },
                              activeColor: const Color(0xFF1C1C1C),
                              activeTrackColor: const Color(0xFFF8F8F8),
                              inactiveThumbColor: const Color(0xFF1C1C1C),
                              inactiveTrackColor: const Color(0xFFc1c1c1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: verticalSpacing),
                ],
              ),
              const Divider(color: Color(0xFF323232), thickness: 1),
              // ID로 추가하기
              Column(
                children: [
                  SizedBox(height: verticalSpacing),
                  GestureDetector(
                    onTap: () {
                      debugPrint('ID로 추가하기 클릭됨');
                      // 임시: 연락처 데이터 디버그
                      _debugContactData();
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: sidePadding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: iconSize,
                            height: iconSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF323232),
                              borderRadius: BorderRadius.circular(iconSize / 2),
                            ),
                            child: Text(
                              'ID',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFFF8F8F8),
                                fontSize: _getResponsiveFontSize(context, 22),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: _getResponsiveSpacing(context, 9)),
                          Expanded(
                            child: Text(
                              'ID로 추가 하기',
                              style: TextStyle(
                                color: const Color(0xFFF9F9F9),
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: verticalSpacing),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 친구 추천 섹션 빌드
  Widget _buildFriendSuggestionsSection() {
    return Consumer<FriendRequestController>(
      builder: (context, friendRequestController, child) {
        // 연락처 동기화가 활성화된 경우에만 추천 표시
        final contactController = context.watch<ContactController>();
        if (!contactController.isContactSyncEnabled) {
          return Card(
            color: const Color(0xFF1C1C1C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(_getResponsiveSpacing(context, 20)),
              child: Center(
                child: Text(
                  '연락처 동기화를 활성화하면\n친구 추천을 확인할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFc1c1c1),
                    fontSize: _getResponsiveFontSize(context, 14),
                  ),
                ),
              ),
            ),
          );
        }

        // 로딩 상태
        if (friendRequestController.isLoading) {
          return Card(
            color: const Color(0xFF1C1C1C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(_getResponsiveSpacing(context, 30)),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFF8F8F8)),
              ),
            ),
          );
        }

        // 에러 상태
        if (friendRequestController.error != null) {
          return Card(
            color: const Color(0xFF1C1C1C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(_getResponsiveSpacing(context, 20)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '친구 추천을 불러올 수 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFc1c1c1),
                        fontSize: _getResponsiveFontSize(context, 14),
                      ),
                    ),
                    SizedBox(height: _getResponsiveSpacing(context, 8)),
                    TextButton(
                      onPressed: () {
                        final authController = context.read<AuthController>();
                        if (authController.currentUser != null) {
                          friendRequestController.refreshFriendSuggestions(
                            authController.currentUser!.uid,
                          );
                        }
                      },
                      child: Text(
                        '다시 시도',
                        style: TextStyle(
                          color: const Color(0xFFF8F8F8),
                          fontSize: _getResponsiveFontSize(context, 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 친구 추천 리스트
        final suggestions = friendRequestController.friendSuggestions;

        if (suggestions.isEmpty) {
          return Card(
            color: const Color(0xFF1C1C1C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(_getResponsiveSpacing(context, 20)),
              child: Center(
                child: Text(
                  '추천할 친구가 없습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFc1c1c1),
                    fontSize: _getResponsiveFontSize(context, 14),
                  ),
                ),
              ),
            ),
          );
        }

        return Card(
          color: const Color(0xFF1C1C1C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          child: Column(
            children:
                suggestions.asMap().entries.map((entry) {
                  int index = entry.key;
                  FriendSuggestionModel suggestion = entry.value;
                  return _buildFriendSuggestionItem(
                    suggestion,
                    index,
                    suggestions.length,
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  /// 개별 친구 추천 아이템 빌드
  Widget _buildFriendSuggestionItem(
    FriendSuggestionModel suggestion,
    int index,
    int totalLength,
  ) {
    final iconSize = _getResponsiveIconSize(context);
    final sidePadding = _getResponsiveSpacing(context, 18);
    final verticalSpacing = _getResponsiveSpacing(context, 12);
    final titleFontSize = _getResponsiveFontSize(context, 16);
    final subtitleFontSize = _getResponsiveFontSize(context, 12);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sidePadding,
            vertical: verticalSpacing,
          ),
          child: Row(
            children: [
              // 프로필 사진 또는 이니셜
              CircleAvatar(
                radius: iconSize / 2,
                backgroundColor: const Color(0xFF323232),
                backgroundImage:
                    suggestion.profileImageUrl != null
                        ? NetworkImage(suggestion.profileImageUrl!)
                        : null,
                child:
                    suggestion.profileImageUrl == null
                        ? Text(
                          _getInitials(suggestion.nickname),
                          style: TextStyle(
                            color: const Color(0xFFF8F8F8),
                            fontSize: _getResponsiveFontSize(context, 18),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                        : null,
              ),
              SizedBox(width: _getResponsiveSpacing(context, 12)),

              // 이름과 연락처 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.nickname,
                      style: TextStyle(
                        color: const Color(0xFFF9F9F9),
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (suggestion.phoneNumber != null) ...[
                      SizedBox(height: 2),
                      Text(
                        suggestion.phoneNumber!,
                        style: TextStyle(
                          color: const Color(0xFFc1c1c1),
                          fontSize: subtitleFontSize,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 친구 추가 버튼
              Consumer<FriendRequestController>(
                builder: (context, controller, child) {
                  final isLoading = controller.isLoading;

                  return SizedBox(
                    height: _getResponsiveSpacing(context, 32),
                    child: ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                try {
                                  final authController =
                                      context.read<AuthController>();
                                  if (authController.currentUser != null) {
                                    // 현재 사용자의 닉네임을 가져와야 하지만 임시로 빈 문자열 사용
                                    await controller
                                        .sendFriendRequestFromSuggestion(
                                          fromUserId:
                                              authController.currentUser!.uid,
                                          fromUserNickname:
                                              '', // 실제로는 AuthController에서 닉네임을 가져와야 함
                                          suggestion: suggestion,
                                        );
                                    _showSuccessSnackBar('친구 요청을 보냈습니다.');
                                  }
                                } catch (e) {
                                  _showErrorSnackBar('친구 요청을 보내는데 실패했습니다.');
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8F8F8),
                        foregroundColor: const Color(0xFF1C1C1C),
                        padding: EdgeInsets.symmetric(
                          horizontal: _getResponsiveSpacing(context, 16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        '추가',
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // 마지막 아이템이 아니면 구분선 추가
        if (index < totalLength - 1)
          const Divider(color: Color(0xFF323232), thickness: 1, height: 1),
      ],
    );
  }

  /// 이름에서 이니셜 추출
  String _getInitials(String name) {
    if (name.isEmpty) return '?';

    List<String> nameParts = name.trim().split(' ');
    if (nameParts.length == 1) {
      return nameParts[0][0].toUpperCase();
    } else {
      return (nameParts[0][0] + nameParts[nameParts.length - 1][0])
          .toUpperCase();
    }
  }

  /// 테스트용: 더미 친구 추천 데이터 생성
  Future<void> _generateTestSuggestions() async {
    try {
      debugPrint('🧪 테스트용 친구 추천 데이터 생성');

      final friendRequestController = context.read<FriendRequestController>();

      // 테스트용 FriendSuggestionModel 리스트 생성
      final testSuggestions = [
        FriendSuggestionModel(
          userId: 'test_user_1',
          nickname: '테스트 사용자 1',
          phoneNumber: '010-1234-5678',
          score: 0.9,
          reasons: ['연락처에서 발견'],
        ),
        FriendSuggestionModel(
          userId: 'test_user_2',
          nickname: '테스트 사용자 2',
          phoneNumber: '010-9876-5432',
          score: 0.8,
          reasons: ['연락처에서 발견'],
          profileImageUrl: 'https://via.placeholder.com/150',
        ),
        FriendSuggestionModel(
          userId: 'test_user_3',
          nickname: '홍길동',
          phoneNumber: '010-5555-1234',
          score: 0.7,
          reasons: ['연락처에서 발견'],
        ),
      ];

      // 직접 suggestions 리스트 업데이트 (테스트용)
      // 실제로는 private 변수이므로 이 방법은 작동하지 않을 수 있음
      // 대신 FriendRequestController에 테스트 메서드를 추가해야 할 수 있음

      debugPrint('🧪 테스트 데이터 ${testSuggestions.length}개 생성 완료');
      _showSuccessSnackBar('테스트용 친구 추천 ${testSuggestions.length}개가 생성되었습니다.');
    } catch (e) {
      debugPrint('❌ 테스트 데이터 생성 실패: $e');
      _showErrorSnackBar('테스트 데이터 생성 중 오류가 발생했습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = _getResponsivePadding(context);
    final titleFontSize = _getResponsiveFontSize(context, 18);
    final smallSpacing = _getResponsiveSpacing(context, 6);
    final mediumSpacing = _getResponsiveSpacing(context, 16);
    final largeSpacing = _getResponsiveSpacing(context, 32);
    final cardHeight = _getResponsiveSpacing(context, 96);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        iconTheme: const IconThemeData(color: Color(0xFFF9F9F9)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 친구 추가 제목
            Text(
              '친구 추가',
              style: TextStyle(
                color: const Color(0xFFffffff),
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: smallSpacing),
            _buildContactCardAdd(),

            // 연락처 동기화 & ID로 추가하기 섹션
            SizedBox(height: mediumSpacing),

            // 초대 링크 제목
            Text(
              '초대 링크',
              style: TextStyle(
                color: const Color(0xFFffffff),
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: smallSpacing),

            // 초대 링크 섹션 (빈 컨테이너)
            Card(
              color: const Color(0xFF1C1C1C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              child: SizedBox(width: double.infinity, height: cardHeight),
            ),
            SizedBox(height: largeSpacing),

            // 친구 요청 제목
            Text(
              '친구 요청',
              style: TextStyle(
                color: const Color(0xFFffffff),
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: smallSpacing),

            // 친구 요청 섹션 (빈 컨테이너)
            Card(
              color: const Color(0xFF1C1C1C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              child: SizedBox(width: double.infinity, height: cardHeight),
            ),
            SizedBox(height: _getResponsiveSpacing(context, 26)),

            // 친구 목록 제목
            Text(
              '친구 목록',
              style: TextStyle(
                color: const Color(0xFFffffff),
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: smallSpacing),

            // 친구 목록 섹션 (빈 컨테이너)
            Card(
              color: const Color(0xFF1C1C1C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              child: SizedBox(width: double.infinity, height: cardHeight),
            ),
            SizedBox(height: _getResponsiveSpacing(context, 26)),

            Text(
              '친구 추천',
              style: TextStyle(
                color: const Color(0xFFffffff),
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: smallSpacing),

            // 친구 추천 섹션
            _buildFriendSuggestionsSection(),
          ],
        ),
      ),
    );
  }
}
