import 'package:flutter/material.dart';

/// SOI 개인정보 처리방침 – Flutter 전용 화면
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  // ---------- 색상 팔레트 ---------- //
  static const _primary = Color(0xFF202A44);
  static const _accent = Color(0xFF0066FF);
  static const _bg = Colors.black; // 배경색을 검정색으로 변경
  static const _border = Color(0xFF3A3A3A); // 테두리 색상 어둡게 변경
  static const _textColor = Colors.white; // 텍스트 색상을 흰색으로 변경

  // ---------- 공통 스타일/헬퍼 ---------- //
  Text _title(String text, {double size = 22}) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: Colors.white, // 타이틀 색상을 흰색으로 변경
      height: 1.3,
    ),
  );

  Table _twoColumnTable(List<List<Widget>> rows) => Table(
    border: TableBorder.all(color: _border),
    columnWidths: const {0: FractionColumnWidth(.28)},
    children:
        rows
            .map(
              (cells) => TableRow(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A1A),
                ), // 테이블 셀 배경색 어둡게 변경
                children:
                    cells
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: c,
                          ),
                        )
                        .toList(),
              ),
            )
            .toList(),
  );

  TableRow _row(List<String> texts) => TableRow(
    children:
        texts
            .map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                child: Text(
                  t,
                  style: const TextStyle(
                    color: Colors.white,
                  ), // 테이블 행 텍스트 색상 변경
                ),
              ),
            )
            .toList(),
  );

  TableRow _rowBold(List<String> texts) => TableRow(
    decoration: const BoxDecoration(
      color: Color(0xFF2A2A2A),
    ), // 굵은 텍스트 행 배경색 변경
    children:
        texts
            .map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                child: Text(
                  t,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ), // 텍스트 색상 추가
                ),
              ),
            )
            .toList(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('개인정보 처리방침'),
        backgroundColor: Colors.black, // 앱바 배경색 검정으로 변경
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.6,
                color: _textColor, // 기본 텍스트 스타일에서 이미 흰색으로 변경됨
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ────────────────── 1. 서문 ────────────────── //
                  _title('SOI 개인정보 처리방침', size: 26),
                  const SizedBox(height: 8),
                  const Text(
                    'SOI(이하 “회사”)는 「개인정보 보호법」 제30조에 따라 이용자의 개인정보와 권익을 '
                    '보호하고 관련 고충을 신속히 처리하기 위하여 본 처리방침을 수립·공개합니다.',
                  ),

                  // ────────────────── 2. 처리 목적 ────────────────── //
                  const SizedBox(height: 32),
                  _title('2. 개인정보의 처리 목적'),
                  const SizedBox(height: 12),
                  _twoColumnTable([
                    [
                      const Text(
                        '회원가입·관리',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('본인 확인, 부정 이용 방지, 계정 탈퇴 처리 등'),
                    ],
                    [
                      const Text(
                        '콘텐츠 업로드·공유',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('사진·음성 기록 저장, 비공개 SNS 피드 제공'),
                    ],
                    [
                      const Text(
                        '맞춤 서비스',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('활동 통계, 알림 PUSH'),
                    ],
                    [
                      const Text(
                        '결제(선택)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('구독 결제 및 환불 처리'),
                    ],
                    [
                      const Text(
                        '서비스 개선',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Firebase Crashlytics·Analytics를 통한 오류·이용 패턴 분석',
                      ),
                    ],
                  ]),

                  // ────────────────── 3. 처리 항목 ────────────────── //
                  const SizedBox(height: 28),
                  _title('3. 처리하는 개인정보 항목'),
                  const SizedBox(height: 8),
                  const _BulletList(
                    items: [
                      '필수: 이메일, 암호화된 비밀번호, 닉네임, 기기 ID, 로그(접속 IP, 브라우저·OS 정보, 이용기록)',
                      '선택: 프로필 사진, 생년월일, 성별',
                      '콘텐츠: 사용자가 업로드한 사진·음성·텍스트',
                      '자동 수집: Firebase Analytics User‑ID, 이벤트 로그, 광고 ID',
                    ],
                  ),

                  // ────────────────── 4. 14세 미만 ────────────────── //
                  const SizedBox(height: 28),
                  _title('4. 14세 미만 아동의 개인정보 처리'),
                  const SizedBox(height: 8),
                  const Text(
                    '회사는 만 14세 미만 아동의 회원가입을 허용하지 않습니다. '
                    '부득이하게 수집할 경우 법정대리인의 동의를 얻으며, 동의 절차·확인 방법은 별도 고지합니다.',
                  ),

                  // ────────────────── 5. 보유 기간 ────────────────── //
                  const SizedBox(height: 28),
                  _title('5. 개인정보의 보유 및 이용 기간'),
                  const SizedBox(height: 12),
                  Table(
                    border: TableBorder.all(color: _border),
                    columnWidths: const {
                      0: FractionColumnWidth(.26),
                      1: FractionColumnWidth(.27),
                      2: FlexColumnWidth(),
                    },
                    children: [
                      _rowBold(['구분', '법적 근거', '보유 기간']),
                      _row([
                        '회원정보',
                        '이용계약 이행(제15조 ① 4호)',
                        '회원 탈퇴 시까지\n※ 1년간 미이용 시 휴면 → 3년 후 파기',
                      ]),
                      _row(['전자상거래 결제 기록', '전자상거래법 시행령 §6', '5년']),
                      _row(['로그 기록', '통신비밀보호법 §15‑2 ②', '3개월']),
                    ],
                  ),

                  // ────────────────── 6. 파기 절차 ────────────────── //
                  const SizedBox(height: 28),
                  _title('6. 개인정보의 파기 절차 및 방법'),
                  const SizedBox(height: 8),
                  const Text(
                    '만료된 데이터는 주 1회 배치 스케줄러로 선별 후, 개인정보 보호책임자 승인 절차를 '
                    '거쳐 즉시 삭제합니다. 전자 파일은 복구 불가 방식으로 영구 삭제하며, 출력물은 '
                    '분쇄·소각 처리합니다.',
                  ),

                  // ────────────────── 7. 제3자 제공 ────────────────── //
                  const SizedBox(height: 28),
                  _title('7. 개인정보의 제3자 제공'),
                  const SizedBox(height: 8),
                  const Text(
                    '회사는 이용자의 개인정보를 제3자에게 제공하지 않습니다. '
                    '제공이 필요할 경우 별도 동의를 받아 고지합니다.',
                  ),

                  // ────────────────── 8. 추가 이용 ────────────────── //
                  const SizedBox(height: 28),
                  _title('8. 추가적인 이용·제공의 판단 기준'),
                  const SizedBox(height: 8),
                  const Text(
                    '수집 목적과의 관련성, 이용자의 예측 가능성, 이익 침해 여부, '
                    '안전성 확보 조치 등을 종합 고려합니다.',
                  ),

                  // ────────────────── 9. 위탁 ────────────────── //
                  const SizedBox(height: 28),
                  _title('9. 개인정보 처리업무의 위탁'),
                  const SizedBox(height: 12),
                  _twoColumnTable([
                    [
                      const Text(
                        'Google Cloud Platform',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('Firestore·Cloud Storage·서버 호스팅'),
                    ],
                  ]),

                  // ────────────────── 10. 국외 이전 ────────────────── //
                  const SizedBox(height: 28),
                  _title('10. 개인정보의 국외 이전'),
                  const SizedBox(height: 12),
                  _twoColumnTable([
                    [
                      const Text(
                        '법적 근거',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('계약 이행을 위한 국외 보관(§28‑8 ① 3호)'),
                    ],
                    [
                      const Text(
                        '이전 국가·설비',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        '미국(us‑central1), 싱가포르(asia‑southeast1) 등 Google Cloud Regions',
                      ),
                    ],
                    [
                      const Text(
                        '시기·방법',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('콘텐츠 업로드 또는 서비스 접속 시 TLS 암호화 전송'),
                    ],
                    [
                      const Text(
                        '이전받는 자',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('Google LLC (privacy@google.com)'),
                    ],
                    [
                      const Text(
                        '목적·보유 기간',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('클라우드 호스팅·백업 / 계정 삭제 또는 보유 기간 만료 시까지'),
                    ],
                    [
                      const Text(
                        '거부 권리',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text('국외 이전을 거부할 수 있으나, 이 경우 서비스 이용이 제한될 수 있습니다.'),
                    ],
                  ]),

                  // ────────────────── 11. 안전조치 ────────────────── //
                  const SizedBox(height: 28),
                  _title('11. 개인정보의 안전성 확보조치'),
                  const SizedBox(height: 8),
                  const _BulletList(
                    items: [
                      '관리적 : 내부 관리계획 수립·시행, 연 2회 직원 교육',
                      '기술적 : 전송·저장 구간 AES‑256/TLS 암호화, 접근 제어(IAM)',
                      '물리적 : 데이터센터·사무실 출입 통제',
                    ],
                  ),

                  // ────────────────── 12. 민감정보 ────────────────── //
                  const SizedBox(height: 28),
                  _title('12. 민감정보 공개 가능성 및 비공개 선택 방법'),
                  const SizedBox(height: 8),
                  const Text(
                    '서비스 사용 과정에서 건강 정보 등 민감정보가 노출될 수 있습니다. '
                    '설정 > 개인정보 메뉴에서 공개 범위를 “나만 보기”로 변경할 수 있습니다.',
                  ),

                  // ────────────────── 13. 가명정보 ────────────────── //
                  const SizedBox(height: 28),
                  _title('13. 가명정보 처리'),
                  const SizedBox(height: 8),
                  const Text('통계·연구 목적에 한해 가명처리 후 별도 보관하며, 추가 정보를 분리 관리합니다.'),

                  // ────────────────── 14. 쿠키/SDK ────────────────── //
                  const SizedBox(height: 28),
                  _title('14. 개인정보 자동 수집 장치의 설치‧운영 및 거부'),
                  const SizedBox(height: 8),
                  const Text(
                    '회사는 쿠키 및 Firebase Analytics SDK를 사용하여 이용 행태를 분석합니다. '
                    '이용자는 브라우저 설정 또는 모바일 OS 광고 ID 재설정을 통해 저장을 거부·삭제할 수 있습니다.',
                  ),

                  // ────────────────── 15. 정보주체 권리 ────────────────── //
                  const SizedBox(height: 28),
                  _title('15. 정보주체와 법정대리인의 권리·의무 및 행사방법'),
                  const SizedBox(height: 8),
                  const Text(
                    '이용자는 ‘설정 > 개인정보 > 내 정보’ 화면에서 개인정보 열람·정정·삭제·동의 철회를 직접 수행할 수 있습니다. '
                    '또한 서면, 이메일(pia@soi.app), 전화(02‑0000‑0000)를 통해서도 요청이 가능합니다.',
                  ),

                  // ────────────────── 16. 자동화된 결정 ────────────────── //
                  const SizedBox(height: 28),
                  _title('16. 자동화된 결정에 대한 정보'),
                  const SizedBox(height: 8),
                  const Text(
                    'AI 추천 알고리즘 관련 설명 요구 및 거부 기능을 제공할 예정입니다 '
                    '(설정 > AI 추천 관리).',
                  ),

                  // ────────────────── 17. PIC ────────────────── //
                  const SizedBox(height: 28),
                  _title('17. 개인정보 보호책임자 및 담당 부서'),
                  const SizedBox(height: 12),
                  Table(
                    border: TableBorder.all(color: _border),
                    columnWidths: const {
                      0: FractionColumnWidth(.28),
                      1: FractionColumnWidth(.24),
                      2: FlexColumnWidth(),
                    },
                    children: [
                      _rowBold(['구분', '성명', '연락처']),
                      _row([
                        '개인정보 보호책임자',
                        '박OO CTO',
                        'privacy@soi.app\n02‑0000‑1111',
                      ]),
                      _row(['고충처리 부서', '서비스운영팀', 'help@soi.app\n02‑0000‑2222']),
                    ],
                  ),

                  // ────────────────── 18. 국내대리인 ────────────────── //
                  const SizedBox(height: 28),
                  _title('18. 국내대리인'),
                  const SizedBox(height: 8),
                  const Text('해당 없음'),

                  // ────────────────── 19. 권익침해 구제 ────────────────── //
                  const SizedBox(height: 28),
                  _title('19. 권익침해 구제 방법'),
                  const SizedBox(height: 8),
                  const Text(
                    '개인정보 침해로 인한 신고·상담은 개인정보분쟁조정위원회(☎ 1833‑6972) 등을 통해 가능합니다.',
                  ),

                  // ────────────────── 20. 영상정보처리기기 ────────────────── //
                  const SizedBox(height: 28),
                  _title('20. 영상정보처리기기 운영·관리'),
                  const SizedBox(height: 8),
                  const Text('해당 없음'),

                  // ────────────────── 21. 변경 이력 ────────────────── //
                  const SizedBox(height: 28),
                  _title('21. 처리방침 변경 이력'),
                  const SizedBox(height: 8),
                  const _BulletList(
                    items: ['2025‑05‑06 제1.0 버전 제정', '※ 변경 시 최소 7일 전에 공지합니다.'],
                  ),

                  // ────────────────── Footer ────────────────── //
                  const SizedBox(height: 36),
                  Center(
                    child: Text(
                      '© 2025 SOI. All rights reserved.',
                      style: TextStyle(fontSize: 13, color: _accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 점(•) 목록 전용 위젯 - 텍스트 색상이 이미 상위 DefaultTextStyle에서 흰색으로 설정됨
class _BulletList extends StatelessWidget {
  final List<String> items;
  const _BulletList({required this.items});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children:
        items
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(height: 1.55)),
                    Expanded(child: Text(e)),
                  ],
                ),
              ),
            )
            .toList(),
  );
}
