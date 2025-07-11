import 'package:flutter/material.dart';
import 'package:flutter_boxicons/flutter_boxicons.dart';

class ContactManagerScreen extends StatefulWidget {
  const ContactManagerScreen({super.key});

  @override
  State<ContactManagerScreen> createState() => _ContactManagerScreenState();
}

class _ContactManagerScreenState extends State<ContactManagerScreen> {
  bool isContactSyncEnabled = true;

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

  // 카드 높이를 화면 크기에 따라 조정
  /*double _getResponsiveCardHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final baseHeight = 96.0;
    final scaleFactor = screenHeight / 812; // iPhone X 높이 기준
    return baseHeight * scaleFactor.clamp(0.8, 1.3);
  }*/

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
                              value: isContactSyncEnabled,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (value) {
                                setState(() {
                                  isContactSyncEnabled = value;
                                });
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
