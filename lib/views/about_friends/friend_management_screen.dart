import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class FriendManagementScreen extends StatefulWidget {
  const FriendManagementScreen({super.key});

  @override
  State<FriendManagementScreen> createState() => _FriendManagementScreenState();
}

class _FriendManagementScreenState extends State<FriendManagementScreen> {
  bool _contactSyncEnabled = false; // 연락처 동기화 토글 상태 (디폴트: 꺼짐)
  bool _isLoading = false; // 로딩 상태

  @override
  void initState() {
    super.initState();
    _initializeContactPermission(); // 페이지 진입 시 자동으로 권한 요청
  }

  /// 페이지 진입 시 연락처 권한 자동 요청 및 설정 로드
  Future<void> _initializeContactPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 저장된 설정 먼저 로드
      await _loadContactSyncSetting();

      // 2. 자동으로 권한 요청
      final result = await FlutterContacts.requestPermission();

      if (result) {
        // 권한이 허용된 경우 토글을 true로 설정
        setState(() {
          _contactSyncEnabled = true;
        });
        await _saveContactSyncSetting(true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('연락처 동기화가 활성화되었습니다'),
              backgroundColor: Color(0xff404040),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 권한이 거부된 경우
        setState(() {
          _contactSyncEnabled = false;
        });
        await _saveContactSyncSetting(false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('연락처 권한이 거부되었습니다'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('초기화 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// SharedPreferences에서 연락처 동기화 설정 로드
  Future<void> _loadContactSyncSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _contactSyncEnabled = prefs.getBool('contact_sync_enabled') ?? false;
    });
  }

  /// SharedPreferences에 연락처 동기화 설정 저장
  Future<void> _saveContactSyncSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('contact_sync_enabled', value);
  }

  /// 토글 클릭 시 처리 (토글 OFF 시 설정 이동 팝업)
  Future<void> _handleToggleChange() async {
    if (_contactSyncEnabled) {
      // 토글을 끄려고 하는 경우 - 설정 이동 팝업 표시
      _showPermissionSettingsDialog();
    } else {
      // 토글을 켜려고 하는 경우 - 권한 재요청
      await _requestContactPermission();
    }
  }

  /// 연락처 권한 요청
  Future<void> _requestContactPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FlutterContacts.requestPermission();

      if (result) {
        setState(() {
          _contactSyncEnabled = true;
        });
        await _saveContactSyncSetting(true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('연락처 동기화가 활성화되었습니다'),
              backgroundColor: Color(0xff404040),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('연락처 권한이 필요합니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('권한 요청 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
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
        final hasPermission = await FlutterContacts.requestPermission();
        setState(() {
          _contactSyncEnabled = hasPermission;
        });
        await _saveContactSyncSetting(hasPermission);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasPermission ? '연락처 동기화가 활성화되었습니다' : '연락처 동기화가 비활성화되었습니다',
              ),
              backgroundColor: const Color(0xff404040),
            ),
          );
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
      body: SingleChildScrollView(
        // 전체적인 좌우 패딩을 반응형으로 적용
        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 페이지 제목
            Padding(
              padding: EdgeInsets.only(left: 17 * scale, bottom: 11 * scale),
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
            _buildFriendAddOptionsCard(context, scale),

            SizedBox(height: 24 * scale),

            Padding(
              padding: EdgeInsets.only(left: 17 * scale, bottom: 11 * scale),
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
              padding: EdgeInsets.only(left: 17 * scale, bottom: 11 * scale),
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
              padding: EdgeInsets.only(left: 17 * scale, bottom: 11 * scale),
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
              padding: EdgeInsets.only(left: 17 * scale, bottom: 11 * scale),
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
      ),
    );
  }

  /// 친구 추가 옵션 카드 위젯
  Widget _buildFriendAddOptionsCard(BuildContext context, double scale) {
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
                      _isLoading
                          ? SizedBox(
                            width: 24 * scale,
                            height: 24 * scale,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Switch(
                            value: _contactSyncEnabled,
                            onChanged: (value) {
                              _handleToggleChange(); // 새로운 토글 처리 함수 호출
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
          child: Text('친구 요청', style: TextStyle(color: Color(0xfff9f9f9))),
        ),
      ),
    );
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
          child: Text('친구 추천', style: TextStyle(color: Color(0xfff9f9f9))),
        ),
      ),
    );
  }
}
