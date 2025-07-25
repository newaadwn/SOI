import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../models/auth_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthModel? _userInfo;
  String? _profileImageUrl;
  bool _isLoading = true;
  bool _isNotificationEnabled = false; // 알림 설정 상태 추가

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authController = context.read<AuthController>();
    final userId = authController.getUserId;

    if (userId != null) {
      try {
        final userInfo = await authController.getUserInfo(userId);
        final profileImageUrl = await authController
            .getUserProfileImageUrlWithCache(userId);

        setState(() {
          _userInfo = userInfo;
          _profileImageUrl = profileImageUrl;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 프로필 이미지 업데이트 메서드
  Future<void> _updateProfileImage() async {
    final authController = context.read<AuthController>();

    try {
      final success = await authController.updateProfileImage();

      if (success && mounted) {
        // 프로필 이미지 업데이트 성공 시 새로운 이미지 URL 가져오기
        final userId = authController.getUserId;
        if (userId != null) {
          final newProfileImageUrl = await authController
              .getUserProfileImageUrlWithCache(userId);

          setState(() {
            _profileImageUrl = newProfileImageUrl;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('프로필 이미지 업데이트 오류: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final isLargeScreen = screenWidth > 414;

    // 화면 크기에 따른 패딩 조정
    final horizontalPadding =
        isSmallScreen
            ? screenWidth * 0.04
            : isLargeScreen
            ? screenWidth * 0.05
            : 17.0;

    // 화면 크기에 따른 간격 조정
    final sectionSpacing = isSmallScreen ? 28.0 : 36.0;
    final topSpacing = isSmallScreen ? 6.0 : 9.0;
    final bottomSpacing = isSmallScreen ? 20.0 : 30.0;

    final titleFontSize = isSmallScreen ? 18.0 : 20.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: isSmallScreen ? 20.0 : 24.0,
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              '프로필',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: titleFontSize,
                color: const Color(0xFFD9D9D9),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD9D9D9)),
                )
                : SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: topSpacing),
                        _buildProfileHeader(screenWidth, isSmallScreen),
                        _buildAccountSection(screenWidth, isSmallScreen),
                        SizedBox(height: sectionSpacing),
                        _buildAppSettingsSection(screenWidth, isSmallScreen),
                        SizedBox(height: sectionSpacing),
                        _buildUsageGuideSection(screenWidth, isSmallScreen),
                        SizedBox(height: sectionSpacing),
                        _buildOtherSection(screenWidth, isSmallScreen),
                        SizedBox(height: bottomSpacing),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }

  Widget _buildProfileHeader(double screenWidth, bool isSmallScreen) {
    // 화면 크기에 따른 프로필 이미지 크기 조정
    final profileSize =
        isSmallScreen
            ? 80.0
            : screenWidth > 414
            ? 110.0
            : 96.0;
    final cameraButtonSize = isSmallScreen ? 20.0 : 25.41;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _updateProfileImage,
              child: Container(
                width: profileSize,
                height: profileSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD9D9D9),
                ),
                child: Stack(
                  children: [
                    // 프로필 이미지 또는 기본 아이콘
                    _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: _profileImageUrl!,
                            fit: BoxFit.cover,
                            width: profileSize,
                            height: profileSize,
                            errorWidget: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: profileSize * 0.56,
                                color: Colors.white,
                              );
                            },
                          ),
                        )
                        : Center(
                          child: Icon(
                            Icons.person,
                            size: profileSize * 0.56,
                            color: Colors.white,
                          ),
                        ),
                    // 업로딩 중일 때 로딩 표시
                    if (context.watch<AuthController>().isUploading)
                      Container(
                        width: profileSize,
                        height: profileSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 4,
              child: GestureDetector(
                onTap: _updateProfileImage,
                child: Container(
                  width: cameraButtonSize,
                  height: cameraButtonSize,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF323232),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: cameraButtonSize * 0.47,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSection(double screenWidth, bool isSmallScreen) {
    final sectionTitleSize = isSmallScreen ? 18.0 : 20.0;
    final cardSpacing = isSmallScreen ? 8.0 : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 26 / 393 * screenWidth),
            Text(
              '계정',
              style: TextStyle(
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
                fontSize: sectionTitleSize,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAccountCard(
          '아이디',
          _userInfo?.id ?? '',
          screenWidth,
          isSmallScreen,
        ),
        SizedBox(height: cardSpacing),
        _buildAccountCard(
          '이름',
          _userInfo?.name ?? '',
          screenWidth,
          isSmallScreen,
        ),
        SizedBox(height: cardSpacing),
        _buildAccountCard(
          '생일',
          _userInfo?.birthDate ?? '',
          screenWidth,
          isSmallScreen,
        ),
        SizedBox(height: cardSpacing),
        _buildAccountCard(
          '전화번호',
          _userInfo?.phone ?? '',
          screenWidth,
          isSmallScreen,
        ),
      ],
    );
  }

  Widget _buildAccountCard(
    String label,
    String value,
    double screenWidth,
    bool isSmallScreen,
  ) {
    final cardHeight = isSmallScreen ? 55.0 : 62.0;
    final horizontalPadding = isSmallScreen ? 16.0 : 19.0;
    final verticalPadding = isSmallScreen ? 6.0 : 8.0;
    final labelFontSize = isSmallScreen ? 12.0 : 13.0;
    final valueFontSize = isSmallScreen ? 14.0 : 16.0;
    final spaceBetween = isSmallScreen ? 5.0 : 7.0;

    return Container(
      width: double.infinity,
      height: cardHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w400,
              fontSize: labelFontSize,
              color: const Color(0xFFCCCCCC),
            ),
          ),
          SizedBox(height: spaceBetween),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w400,
                  fontSize: valueFontSize,
                  color: const Color(0xFFF9F9F9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection(double screenWidth, bool isSmallScreen) {
    final sectionTitleSize = isSmallScreen ? 18.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 26 / 393 * screenWidth),
            Text(
              '앱 설정',
              style: TextStyle(
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
                fontSize: sectionTitleSize,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                '알림 설정',
                hasToggle: true,
                screenWidth: screenWidth,
                isSmallScreen: isSmallScreen,
              ),
              _buildDivider(),
              _buildSettingsItem(
                '언어',
                value: '한국어',
                screenWidth: screenWidth,
                isSmallScreen: isSmallScreen,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsageGuideSection(double screenWidth, bool isSmallScreen) {
    final sectionTitleSize = isSmallScreen ? 18.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 26 / 393 * screenWidth),
            Text(
              '이용 안내',
              style: TextStyle(
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
                fontSize: sectionTitleSize,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                '개인정보 처리방침',
                screenWidth: screenWidth,
                isSmallScreen: isSmallScreen,
              ),
              _buildDivider(),
              _buildSettingsItem(
                '서비스 이용 약관',
                screenWidth: screenWidth,
                isSmallScreen: isSmallScreen,
              ),
              _buildDivider(),
              _buildSettingsItem(
                '오픈소스 라이선스',
                screenWidth: screenWidth,
                isSmallScreen: isSmallScreen,
              ),
              _buildDivider(),
              _buildSettingsItem(
                '앱 버전',
                value: '3.1',
                screenWidth: screenWidth,
                isSmallScreen: isSmallScreen,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherSection(double screenWidth, bool isSmallScreen) {
    final sectionTitleSize = isSmallScreen ? 18.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 26 / 393 * screenWidth),
            Text(
              '기타',
              style: TextStyle(
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
                fontSize: sectionTitleSize,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                '앱 정보 동의 설정',
                screenWidth: screenWidth,
                isSmallScreen: isSmallScreen,
              ),
              _buildDivider(),
              _buildSettingsItem(
                '차단된 친구',
                screenWidth: screenWidth,
                isSmallScreen: isSmallScreen,
              ),
              _buildDivider(),
              GestureDetector(
                onTap: () {
                  debugPrint('로그아웃 클릭됨');
                },
                child: _buildSettingsItem(
                  '로그아웃',
                  isRed: true,
                  screenWidth: screenWidth,
                  isSmallScreen: isSmallScreen,
                ),
              ),
              _buildDivider(),
              GestureDetector(
                onTap: () {
                  debugPrint('계정 삭제 클릭됨');
                },
                child: _buildSettingsItem(
                  '계정 삭제',
                  isRed: true,
                  screenWidth: screenWidth,
                  isSmallScreen: isSmallScreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
    String title, {
    String? value,
    bool hasToggle = false,
    bool isRed = false,
    required double screenWidth,
    required bool isSmallScreen,
  }) {
    final horizontalPadding = isSmallScreen ? 14.0 : 16.0;
    final verticalPadding = isSmallScreen ? 14.0 : 17.0;
    final fontSize = isSmallScreen ? 14.0 : 16.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w400,

                fontSize: fontSize,
                color:
                    isRed ? const Color(0xFFFF0000) : const Color(0xFFF9F9F9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasToggle)
            Switch(
              value: _isNotificationEnabled,
              onChanged: (value) {
                setState(() {
                  _isNotificationEnabled = value;
                });
              },
              activeColor: Colors.black, // 켜진 상태 스위치 색상
              activeTrackColor: const Color(0xFFf9f9f9), // 켜진 상태 배경색 (iOS 파란색)
              inactiveThumbColor: Colors.black, // 꺼진 상태 스위치 색상
              inactiveTrackColor: const Color(0xFFf9f9f9), // 꺼진 상태 배경색
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              splashRadius: 0, // 터치 효과 제거
            )
          else if (value != null)
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w400,
                  fontSize: fontSize,
                  color: const Color(0xFFF9F9F9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      height: 1,
      color: const Color(0xFF323232),
    );
  }
}
