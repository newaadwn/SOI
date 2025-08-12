import 'package:flutter/material.dart';
import 'package:flutter_boxicons/flutter_boxicons.dart';
import 'package:flutter_contacts/contact.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_swift_camera/controllers/auth_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/contact_controller.dart';
import '../../controllers/user_matching_controller.dart';
import '../../controllers/friend_request_controller.dart';
import '../../controllers/friend_controller.dart';
import '../../models/friend_request_model.dart';
import '../../services/contact_service.dart';
import '../../services/user_matching_service.dart';
import 'friend_list_screen.dart';

class FriendManagementScreen extends StatefulWidget {
  const FriendManagementScreen({super.key});

  @override
  State<FriendManagementScreen> createState() => _FriendManagementScreenState();
}

class _FriendManagementScreenState extends State<FriendManagementScreen>
    with AutomaticKeepAliveClientMixin {
  List<Contact> _contacts = [];

  // ✅ 백그라운드 로딩을 위한 상태 변수들 추가
  bool _isInitializing = false;
  bool _hasInitialized = false;

  // ContactController 참조 저장
  ContactController? _contactController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // ✅ 화면을 즉시 표시하고 백그라운드에서 초기화 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
      // 페이지 진입 시 동기화 재개
      _resumeSyncIfNeeded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ContactController 참조를 안전하게 저장
    _contactController ??= Provider.of<ContactController>(
      context,
      listen: false,
    );
  }

  @override
  void dispose() {
    // 페이지를 벗어날 때 동기화 일시 중지 (비동기로 처리)
    _pauseSyncIfNeededAsync();
    super.dispose();
  }

  /// 동기화 재개 (필요한 경우)
  void _resumeSyncIfNeeded() {
    if (_contactController != null) {
      _contactController!.resumeSync();
    }
  }

  /// 동기화 일시 중지 (필요한 경우) - 비동기 버전
  void _pauseSyncIfNeededAsync() {
    if (_contactController != null) {
      // 다음 프레임에서 실행하여 위젯 트리 lock 문제 방지
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_contactController != null) {
          _contactController!.pauseSync();
        }
      });
    }
  }

  Future<void> _initializeControllers() async {
    // 백그라운드에서 순차적으로 초기화
    Future.microtask(() async {
      await _initializeFriendController();
      await _initializeFriendRequestController();

      // 연락처는 필요할 때만 로드
      if (_shouldLoadContacts()) {
        await _initializeContactPermissionInBackground();
      }
    });
  }

  bool _shouldLoadContacts() {
    // 이미 로드했거나 권한이 없으면 스킵
    if (!mounted || _contactController == null) return false;

    // 활성 동기화 상태일 때만 연락처 로드
    return _contactController!.isActivelySyncing && _contacts.isEmpty;
  }

  /// FriendController 초기화
  Future<void> _initializeFriendController() async {
    try {
      if (!mounted) return;

      final friendController = Provider.of<FriendController>(
        context,
        listen: false,
      );

      // 이미 초기화되어 있으면 스킵
      if (friendController.isInitialized) return;

      await friendController.initialize();
      // debugPrint('FriendController 초기화 완료');
    } catch (e) {
      // debugPrint('FriendController 초기화 실패: $e');
    }
  }

  /// FriendRequestController 초기화
  Future<void> _initializeFriendRequestController() async {
    try {
      if (!mounted) return;

      final friendRequestController = Provider.of<FriendRequestController>(
        context,
        listen: false,
      );

      // 이미 초기화되어 있으면 스킵
      if (friendRequestController.isInitialized) return;

      await friendRequestController.initialize();
      // debugPrint('FriendRequestController 초기화 완료');
    } catch (e) {
      // debugPrint('FriendRequestController 초기화 실패: $e');
    }
  }

  /// ✅ 백그라운드에서 연락처 권한 및 초기화 처리 (화면 전환 지연 방지)
  Future<void> _initializeContactPermissionInBackground() async {
    if (_hasInitialized) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      if (!mounted || _contactController == null) return;

      // ✅ 1단계: 권한 확인 (빠른 처리)
      final result = await _contactController!.initializeContactPermission();

      // ✅ 2단계: 권한이 허용된 경우에만 연락처 로드 (느린 처리)
      if (result.isEnabled &&
          mounted &&
          _contactController!.isActivelySyncing) {
        try {
          _contacts = await _contactController!.getContacts(
            forceRefresh: false,
          );
          // debugPrint('연락처 로드 성공: ${_contacts}');
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          // debugPrint('연락처 로드 실패: $e');
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
      if (!mounted || _contactController == null) return;

      if (_contactController!.contactSyncEnabled) {
        _contacts = await _contactController!.getContacts(forceRefresh: true);
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      rethrow;
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

  /// ID로 친구 추가 다이얼로그
  void _showAddByIdDialog(BuildContext context, double scale) {
    final TextEditingController idController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Color(0xff171717).withValues(alpha: 0.8), // 반투명 회색 배경
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Color(0xff323232),
          insetPadding: EdgeInsets.symmetric(horizontal: 40.w),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Container(
                width: 314.w,
                height: 204.h,
                decoration: BoxDecoration(
                  color: Color(0xff323232), // 어두운 회색 배경
                  borderRadius: BorderRadius.circular(14.2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 제목
                    Text(
                      '추가할 아이디를 입력해주세요',
                      style: TextStyle(
                        color: const Color(0xfff9f9f9),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 24.h),

                    // ID 입력 필드
                    Container(
                      width: 249.w,
                      height: 39.h,
                      decoration: BoxDecoration(
                        color: const Color(0xff323232),
                        borderRadius: BorderRadius.circular(8.89),
                        border: Border.all(
                          color: const Color(0xff5a5a5a),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: idController,
                        style: TextStyle(
                          color: const Color(0xfff9f9f9),
                          fontSize: 16.sp,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 14.h,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 35.h),

                    // 확인 버튼
                    SizedBox(
                      width: 145.w,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: () {
                          final enteredId = idController.text.trim();
                          if (enteredId.isNotEmpty) {
                            Navigator.of(context).pop();
                            _addFriendById(enteredId);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xffffffff),
                          foregroundColor: const Color(0xff000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.2),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          '확인',
                          style: TextStyle(
                            fontSize: (17.7778).sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// ID로 친구 추가 처리
  Future<void> _addFriendById(String id) async {
    try {
      // 로딩 상태 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
      );

      // UserMatchingController를 통해 사용자 검색
      final userMatchingController = Provider.of<UserMatchingController>(
        context,
        listen: false,
      );

      // 입력된 ID로 사용자 검색 (Controller를 통한 비즈니스 로직 처리)
      final searchResult = await userMatchingController.searchUserById(id);

      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.of(context).pop();

      if (searchResult == null) {
        // 사용자를 찾을 수 없는 경우
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ID "$id"를 찾을 수 없습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // FriendRequestController를 통해 친구 요청 전송
      final friendRequestController = Provider.of<FriendRequestController>(
        context,
        listen: false,
      );

      final success = await friendRequestController.sendFriendRequest(
        receiverUid: searchResult.single.uid,
        message: 'ID로 친구 요청을 보냅니다.',
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${searchResult.single.id}님에게 친구 요청을 보냈습니다'),
              backgroundColor: const Color(0xff404040),
            ),
          );
        } else {
          // 에러 메시지는 FriendRequestController에서 처리됨
          final errorMessage =
              friendRequestController.error ?? '친구 요청 전송에 실패했습니다';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      // 로딩 다이얼로그가 열려있다면 닫기
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

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
        if (!mounted || _contactController == null) return;

        final result = await _contactController!.checkPermissionAfterSettings();
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
    super.build(context); // AutomaticKeepAliveClientMixin 필수
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
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 페이지 제목
                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    '친구추가',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // 친구 추가 옵션 카드 위젯 함수 호출
                _buildFriendAddOptionsCard(context, scale, contactController),

                SizedBox(height: 24.h),

                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    '초대링크',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: (18.02).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // 가로 스크롤 링크 카드 목록
                _buildLinkCard(context, scale),

                SizedBox(height: 24.h),

                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    '친구 요청',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: (18.02).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildRequestCard(context, scale),
                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    '친구 목록',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: (18.02).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildFriendListCard(context, scale),
                SizedBox(height: 24.h),
                Padding(
                  padding: EdgeInsets.only(left: 17.w, bottom: 11.h),
                  child: Text(
                    '친구 추천',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: (18.02).sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildFriendSuggestCard(context, scale),
                SizedBox(height: 134.h),
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
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
            child: Row(
              children: [
                // 아이콘
                Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: const BoxDecoration(
                    color: Color(0xff323232),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Boxicons.bxs_contact,
                    color: const Color(0xfff9f9f9),
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 9.sp),

                // 텍스트
                Expanded(
                  child: Text(
                    '연락처 동기화',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                // 토글 스위치 또는 로딩 스피너
                Row(
                  children: [
                    // 일시중지 상태 표시
                    if (contactController.isSyncPaused) ...[
                      Icon(
                        Icons.pause_circle_filled,
                        color: Colors.orange,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.sp),
                    ],
                    Transform.scale(
                      scale: scale,
                      child:
                          contactController.isLoading
                              ? SizedBox(
                                width: 24.sp,
                                height: 24.sp,
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
              ],
            ),
          ),

          // 구분선
          Divider(color: Color(0xff1c1c1c), height: 1, thickness: 1),

          // ID로 추가 하기
          InkWell(
            onTap: () {
              _showAddByIdDialog(context, scale);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    width: 44.w,
                    height: 44.h,
                    decoration: const BoxDecoration(
                      color: Color(0xff323232),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'ID',
                        style: TextStyle(
                          color: const Color(0xfff9f9f9),
                          fontSize: 25.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 9.sp),

                  // 텍스트 (수정됨)
                  Expanded(
                    child: Text(
                      'ID로 추가 하기',
                      style: TextStyle(
                        color: const Color(0xfff9f9f9),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
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
      width: 354.w,
      height: 100.h,
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: const Color(0xff1c1c1c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 18.w),
              _buildLinkCardContent(context, scale, '링크 복사', 'assets/link.png'),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(context, scale, '공유', 'assets/share.png'),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(context, scale, '카카오톡', 'assets/kakao.png'),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                '인스타그램',
                'assets/insta.png',
              ),
              SizedBox(width: (21.24).w),
              _buildLinkCardContent(
                context,
                scale,
                '메세지',
                'assets/message.png',
              ),
              SizedBox(width: (18).w),
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
            child: Image.asset(imagePath, width: (51.76).w, height: (51.76).w),
          ),
          SizedBox(height: (7.24).h),
          Text(
            title,
            style: TextStyle(
              color: const Color(0xfff9f9f9),
              fontSize: (12).sp,
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
          width: (354).w,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // 친구 요청 리스트
                receivedRequests.isEmpty
                    ? SizedBox(
                      height: 132.h,
                      child: Center(
                        child: Text(
                          friendRequestController.isLoading
                              ? '친구 요청을 불러오는 중...'
                              : '받은 친구 요청이 없습니다',
                          style: TextStyle(
                            color: const Color(0xff666666),
                            fontSize: 14.sp,
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
              ],
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
      padding: EdgeInsets.symmetric(horizontal: (18).w, vertical: (12).h),
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: (22).w,
            backgroundColor: const Color(0xff323232),
            backgroundImage:
                (request.senderProfileImageUrl != null &&
                        request.senderProfileImageUrl!.isNotEmpty &&
                        (request.senderProfileImageUrl!.startsWith('http://') ||
                            request.senderProfileImageUrl!.startsWith(
                              'https://',
                            )))
                    ? NetworkImage(request.senderProfileImageUrl!)
                    : null,
            child:
                (request.senderProfileImageUrl == null ||
                        request.senderProfileImageUrl!.isEmpty)
                    ? Text(
                      request.senderid.isNotEmpty
                          ? request.senderid[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: const Color(0xfff9f9f9),
                        fontSize: (16).sp,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                    : null,
          ),
          SizedBox(width: (12).w),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.senderid.isNotEmpty ? request.senderid : '알 수 없는 사용자',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xffd9d9d9),
                    fontSize: (16).sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                Text(
                  request.message!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xffd9d9d9),
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),

          // 삭제/수락 버튼
          if (isProcessing) ...[
            SizedBox(
              width: (24).w,
              height: (24).h,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xfff9f9f9),
              ),
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 삭제 버튼
                SizedBox(
                  width: 42.w,
                  height: 29.h,
                  child: ElevatedButton(
                    onPressed:
                        () => _rejectFriendRequest(request.id, controller),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff333333),
                      foregroundColor: const Color(0xff999999),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    child: Text(
                      '삭제',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                ),
                SizedBox(width: (8).w),
                // 수락 버튼
                SizedBox(
                  width: 42.w,
                  height: 29.h,
                  child: ElevatedButton(
                    onPressed:
                        () => _acceptFriendRequest(request.id, controller),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xfff9f9f9),
                      foregroundColor: const Color(0xff1c1c1c),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    child: Text(
                      '수락',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
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

  // 사용자가 추가한 친구 목록
  Widget _buildFriendListCard(BuildContext context, double scale) {
    return Consumer<FriendController>(
      builder: (context, friendController, child) {
        final friends = friendController.friends;

        return SizedBox(
          width: 354.w,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                friends.isEmpty
                    ? SizedBox(
                      height: 132.h,
                      child: Center(
                        child: Text(
                          '아직 친구가 없습니다',
                          style: TextStyle(
                            color: const Color(0xff666666),
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 친구들 리스트 (세로 리스트)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,
                                vertical: 8.h,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 프로필 이미지 (고정 크기)
                                  CircleAvatar(
                                    radius: (22),
                                    backgroundColor: const Color(0xff323232),
                                    backgroundImage:
                                        friend.profileImageUrl != null
                                            ? NetworkImage(
                                              friend.profileImageUrl!,
                                            )
                                            : null,
                                    child:
                                        friend.profileImageUrl == null
                                            ? Text(
                                              friend.id.isNotEmpty
                                                  ? friend.id[0]
                                                  : '?',
                                              style: TextStyle(
                                                color: const Color(0xfff9f9f9),
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.w600,
                                                height: 1.1,
                                              ),
                                            )
                                            : null,
                                  ),
                                  SizedBox(width: 9.w),
                                  // 이름 + 서브텍스트 영역
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: const Color(0xffd9d9d9),
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),

                                        Text(
                                          friend.id,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: const Color(0xffd9d9d9),
                                            fontSize: 10.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // 더보기 링크 (친구가 10명 이상일 때)
                        GestureDetector(
                          onTap: () {
                            // 친구 목록 전체 화면으로 이동
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const FriendListScreen(),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: (18).sp),
                                  SizedBox(width: (8).w),
                                  Text(
                                    '더보기',
                                    style: TextStyle(
                                      color: const Color(0xffd9d9d9),
                                      fontSize: (16).sp,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: (12).h),
                            ],
                          ),
                        ),
                      ],
                    ),
          ),
        );
      },
    );
  }

  // 친구 추천
  Widget _buildFriendSuggestCard(BuildContext context, double scale) {
    return Consumer<ContactController>(
      builder: (context, contactController, child) {
        return SizedBox(
          width: 354.w,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24.w,
              height: 24.h,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xfff9f9f9),
              ),
            ),
            SizedBox(height: (16).h),
            Text(
              '연락처에서 친구를 찾는 중...',
              style: TextStyle(color: const Color(0xff666666), fontSize: 14.sp),
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
                      fontSize: (16).sp,
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
                    fontSize: (16).sp,
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
                            fontSize: (14).sp,
                          ),
                        )
                        : null;
                  } catch (e) {
                    // debugPrint('전화번호 접근 오류: $e');
                    return null;
                  }
                }(),
                trailing: SizedBox(
                  height: 29.h,
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
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                    child: Text(
                      '친구 추가',
                      style: TextStyle(
                        color: const Color(0xff1c1c1c),
                        fontSize: 13.sp,
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
      padding: EdgeInsets.all(20),
      child: Center(
        child: Text(
          contactController.contactSyncEnabled
              ? '연락처에서 친구를 찾을 수 없습니다'
              : '연락처 동기화를 활성화해주세요',
          style: TextStyle(color: const Color(0xff666666), fontSize: 14.sp),
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
            // debugPrint('매칭된 사용자 찾음: ${matchedUser.uid}, ${matchedUser.id}');
            final success = await friendRequestController.sendFriendRequest(
              receiverUid: matchedUser.uid,
              message: '받은 친구 요청',
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
            // debugPrint('사용자 정보를 찾을 수 없음');
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
      // debugPrint('친구 추가 실패: $e');
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
      // debugPrint('Contact 정보: ${contact.displayName}');
      // debugPrint('Contact phones 길이: ${contact.phones.length}');

      // Contact의 전화번호 확인
      if (contact.phones.isEmpty) {
        // debugPrint('전화번호가 없는 연락처: ${contact.displayName}');
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

      AuthController authController = AuthController();

      // debugPrint('전화번호: $phoneNumber');

      if (phoneNumber.isEmpty) {
        // debugPrint('빈 전화번호: ${contact.displayName}');
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
      // 스마트 초대 링크 생성 (현재 사용자 정보 포함)
      // TODO: 실제 Firebase Auth에서 현재 사용자 정보 가져오기
      final currentUserName = authController.currentUser?.displayName ?? '사용자';
      final currentUserId = authController.currentUser?.uid;

      final inviteLink =
          'https://soi-sns.web.app/invite.html?'
          'inviter=${Uri.encodeComponent(currentUserName)}'
          '&inviterId=${Uri.encodeComponent(currentUserId!)}'
          '&invitee=${Uri.encodeComponent(contact.displayName)}';

      final message =
          '안녕하세요! $currentUserName님이 SOI 앱에서 친구가 되고 싶어해요! 아래 링크로 SOI를 시작해보세요: $inviteLink';

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
      // debugPrint('SMS 전송 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메시지 전송 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
