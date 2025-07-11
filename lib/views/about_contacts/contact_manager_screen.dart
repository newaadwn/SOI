import 'package:flutter/material.dart';
import 'package:flutter_boxicons/flutter_boxicons.dart';
import 'package:provider/provider.dart';

import '../../controllers/contact_controller.dart';

class ContactManagerScreen extends StatefulWidget {
  const ContactManagerScreen({super.key});

  @override
  State<ContactManagerScreen> createState() => _ContactManagerScreenState();
}

class _ContactManagerScreenState extends State<ContactManagerScreen> {
  bool isContactSyncEnabled = true;
  late ContactController _contactController;

  @override
  void initState() {
    super.initState();
    _contactController = Provider.of<ContactController>(context, listen: false);
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
    try {
      // 로딩 상태 표시
      _showLoadingDialog('연락처 동기화를 활성화하는 중...');

      // 1. 권한 요청
      await _contactController.requestContactPermission();

      if (_contactController.permissionDenied) {
        _hideLoadingDialog();
        _showPermissionDialog();
        return;
      }

      // 2. 디바이스 연락처 로드
      await _contactController.loadDeviceContacts();

      // 3. 연락처 동기화 (선택적)
      final shouldSync = await _showSyncConfirmDialog();
      if (shouldSync) {
        await _contactController.syncContactsFromDevice(
          skipDuplicates: true,
          maxCount: 100, // 최대 100개까지
        );
      }

      _hideLoadingDialog();

      if (_contactController.error != null) {
        _showErrorSnackBar(_contactController.error!);
      } else {
        _showSuccessSnackBar('연락처 동기화가 활성화되었습니다.');
      }
    } catch (e) {
      _hideLoadingDialog();
      _showErrorSnackBar('연락처 동기화 활성화 중 오류가 발생했습니다.');
    }
  }

  /// 연락처 동기화 비활성화
  Future<void> _disableContactSync() async {
    try {
      final shouldDisable = await _showDisableConfirmDialog();
      if (!shouldDisable) return;

      _showLoadingDialog('연락처 동기화를 비활성화하는 중...');

      // ContactController에는 비활성화 메서드가 없으므로,
      // 로컬 상태만 초기화하거나 필요에 따라 Service에 메서드 추가
      _contactController.clearSearch();

      _hideLoadingDialog();
      _showSuccessSnackBar('연락처 동기화가 비활성화되었습니다.');
    } catch (e) {
      _hideLoadingDialog();
      _showErrorSnackBar('연락처 동기화 비활성화 중 오류가 발생했습니다.');
    }
  }

  /// 로딩 다이얼로그 표시
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1C),
            content: Row(
              children: [
                const CircularProgressIndicator(color: Color(0xFFF8F8F8)),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Color(0xFFF8F8F8)),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  /// 로딩 다이얼로그 숨기기
  void _hideLoadingDialog() {
    Navigator.of(context).pop();
  }

  /// 권한 요청 다이얼로그
  void _showPermissionDialog() {
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
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '취소',
                  style: TextStyle(color: Color(0xFFc1c1c1)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
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

  /// 동기화 확인 다이얼로그
  Future<bool> _showSyncConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF1C1C1C),
                title: const Text(
                  '연락처 동기화',
                  style: TextStyle(color: Color(0xFFF8F8F8)),
                ),
                content: const Text(
                  '디바이스의 연락처를 앱으로 가져오시겠습니까?\n(중복된 연락처는 건너뜁니다)',
                  style: TextStyle(color: Color(0xFFF8F8F8)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      '나중에',
                      style: TextStyle(color: Color(0xFFc1c1c1)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      '동기화',
                      style: TextStyle(color: Color(0xFFF8F8F8)),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  /// 비활성화 확인 다이얼로그
  Future<bool> _showDisableConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF1C1C1C),
                title: const Text(
                  '연락처 동기화 비활성화',
                  style: TextStyle(color: Color(0xFFF8F8F8)),
                ),
                content: const Text(
                  '연락처 동기화를 비활성화하시겠습니까?\n(기존 데이터는 유지됩니다)',
                  style: TextStyle(color: Color(0xFFF8F8F8)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: Color(0xFFc1c1c1)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      '비활성화',
                      style: TextStyle(color: Color(0xFFF8F8F8)),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  /// 성공 스낵바
  void _showSuccessSnackBar(String message) {
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
                                      .hasDeviceContacts,
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
                color: const Color(0xFFD9D9D9),
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
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
                color: const Color(0xFFD9D9D9),
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
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
                color: const Color(0xFFD9D9D9),
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
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
                color: const Color(0xFFD9D9D9),
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
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
          ],
        ),
      ),
    );
  }
}
