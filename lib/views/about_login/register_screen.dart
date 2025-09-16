import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../controllers/auth_controller.dart';
import 'auth_final_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final PageController _pageController = PageController();
  late AuthController _authController;

  // 자동 인증을 위한 Timer
  Timer? _autoVerifyTimer;

  // 사용자가 존재하는지 여부 및 상태 관리
  bool userExists = false;
  bool isVerified = false;
  bool isCheckingUser = false;

  // 입력 데이터
  String phoneNumber = '';
  String smsCode = '';
  String name = '';
  String birthDate = '';
  String id = '';

  // 현재 페이지 인덱스
  int currentPage = 0;

  // 드롭다운에서 선택된 값
  String? selectedYear;
  String? selectedMonth;
  String? selectedDay;

  // 페이지별 입력 완료 여부
  late List<ValueNotifier<bool>> pageReady;
  // 공통 컨트롤러
  late TextEditingController nameController;
  late TextEditingController monthController;
  late TextEditingController dayController;
  late TextEditingController yearController;
  late TextEditingController phoneController;
  late TextEditingController smsController;
  late TextEditingController idController;

  // Note: Continue button visibility is controlled by currentPage (hide on SMS page)

  @override
  void initState() {
    super.initState();
    // 컨트롤러 및 상태 초기화
    nameController = TextEditingController();
    monthController = TextEditingController();
    dayController = TextEditingController();
    yearController = TextEditingController();
    phoneController = TextEditingController();
    smsController = TextEditingController();
    idController = TextEditingController();
    pageReady = List.generate(5, (_) => ValueNotifier<bool>(false));

    // Provider에서 AuthViewModel을 가져오거나 widget에서 전달된 것을 사용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _authController = Provider.of<AuthController>(context, listen: false);
      });
    });
  }

  @override
  void dispose() {
    // Dispose controllers and notifiers
    nameController.dispose();
    monthController.dispose();
    dayController.dispose();
    yearController.dispose();
    phoneController.dispose();
    smsController.dispose();
    idController.dispose();
    for (var notifier in pageReady) {
      notifier.dispose();
    }
    _autoVerifyTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,

      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                currentPage = index;
              });
            },
            children: [
              // 1. 이름 입력 페이지
              _buildNamePage(screenHeight),
              // 2. 생년월일 입력 페이지
              _buildBirthDatePage(screenHeight),
              // 3. 전화번호 입력 페이지
              _buildPhoneNumberPage(),
              // 인증번호 입력 페이지
              _buildSmsCodePage(),
              // 4. 닉네임 입력 페이지
              _buildIdPage(screenHeight),
            ],
          ),

          // 공통 Continue 버튼
          // Hide the common Continue button only when we're on the SMS code page
          (currentPage == 3)
              ? SizedBox()
              : Positioned(
                bottom:
                    MediaQuery.of(context).viewInsets.bottom > 0
                        ? MediaQuery.of(context).viewInsets.bottom + 20.h
                        : 50.h,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: pageReady[currentPage],
                  builder: (context, ready, child) {
                    return Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26.9),
                          ),
                        ),
                        onPressed:
                            ready
                                ? () {
                                  FocusScope.of(context).unfocus();
                                  switch (currentPage) {
                                    case 0: // 이름
                                      name = nameController.text;
                                      _pageController.nextPage(
                                        duration: Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                      break;
                                    case 1: // 생년월일
                                      _pageController.nextPage(
                                        duration: Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                      break;
                                    case 2: // 전화번호
                                      phoneNumber = phoneController.text;
                                      _authController.verifyPhoneNumber(
                                        phoneNumber,
                                        (verificationId, token) {
                                          // Navigate to SMS page when code sent
                                          _pageController.nextPage(
                                            duration: Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                        (verificationId) {},
                                      );
                                      break;
                                    case 3: // 인증코드
                                      smsCode = smsController.text;
                                      _performAutoVerification(smsCode);
                                      break;
                                    case 4: // 아이디
                                      id = idController.text;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => AuthFinalScreen(
                                                id: id,
                                                name: name,
                                                phone: phoneNumber,
                                                birthDate: birthDate,
                                              ),
                                        ),
                                      );
                                      break;
                                  }
                                }
                                : null,
                        child: Container(
                          width: 349.w,
                          height: 59.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ready ? Colors.white : Color(0xff323232),
                            borderRadius: BorderRadius.circular(26.9),
                          ),
                          child: Text(
                            '계속하기',
                            style: TextStyle(
                              color: ready ? Colors.black : Colors.grey,
                              fontSize: 20.sp,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  // -------------------------
  // 1. 전화번호 입력 페이지
  // -------------------------
  Widget _buildPhoneNumberPage() {
    return Stack(
      children: [
        // 입력 필드들을 화면 중앙에 고정
        Positioned(
          top: 0.35.sh,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                'SOI 접속을 위해 전화번호를 입력해주세요.',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 18,
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Container(
                width: 239.w,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(0xff323232),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(width: 17.w),
                    Icon(
                      SolarIconsOutline.phone,
                      color: const Color(0xffC0C0C0),
                      size: 24.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        textAlign: TextAlign.start,
                        cursorHeight: 16.h,
                        cursorColor: const Color(0xFFF8F8F8),
                        style: TextStyle(
                          color: const Color(0xFFF8F8F8),
                          fontSize: 16,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.08,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '전화번호',
                          hintStyle: TextStyle(
                            color: const Color(0xFFC0C0C0),
                            fontSize: 16.sp,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w400,
                          ),
                          contentPadding: EdgeInsets.only(
                            left: 15.w,
                            bottom: 5.h,
                          ),
                        ),
                        onChanged: (value) {
                          pageReady[2].value = value.isNotEmpty;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------
  // 3. 이름 입력 페이지
  // -------------------------
  Widget _buildNamePage(double screenHeight) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '당신의 이름을 알려주세요.',
          style: TextStyle(
            color: const Color(0xFFF8F8F8),
            fontSize: 18,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24.h),
        Container(
          width: 239.w,
          height: 44,
          decoration: BoxDecoration(
            color: Color(0xff323232),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: nameController,
            keyboardType: TextInputType.text,
            textAlign: TextAlign.center,
            cursorHeight: 16.h,
            cursorColor: const Color(0xFFF8F8F8),
            style: TextStyle(
              color: const Color(0xFFF8F8F8),
              fontSize: 16,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              letterSpacing: -0.08,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '이름',
              hintStyle: TextStyle(
                color: const Color(0xFFC0C0C0),
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
              ),
              contentPadding: EdgeInsets.only(bottom: 5.h),
            ),
            onChanged: (value) {
              pageReady[0].value = value.isNotEmpty;
            },
          ),
        ),
        SizedBox(height: 100.h),
      ],
    );
  }

  // -------------------------
  // 4. 생년월일 입력 페이지 (직접 타이핑)
  // -------------------------
  Widget _buildBirthDatePage(double screenHeight) {
    // 입력값 상태 동기화
    void updateBirthDate() {
      setState(() {
        selectedMonth = monthController.text;
        selectedDay = dayController.text;
        selectedYear = yearController.text;
        birthDate =
            "${selectedYear ?? ''}년 ${selectedMonth ?? ''}월 ${selectedDay ?? ''}일";

        // 모든 필드가 채워졌는지 확인
        bool isComplete =
            monthController.text.isNotEmpty &&
            dayController.text.isNotEmpty &&
            yearController.text.isNotEmpty;
        pageReady[1].value = isComplete;
      });
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '생년월일을 입력해주세요.',
          style: TextStyle(
            color: const Color(0xFFF8F8F8),
            fontSize: 18.sp,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24.h),
        Container(
          width: 320.w,
          height: 51,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Color(0xff323232),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: monthController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 2,
                  cursorColor: Color(0xFFF8F8F8),
                  style: TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 16.sp,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'MM',
                    hintStyle: TextStyle(
                      color: const Color(0xFFCBCBCB),
                      fontSize: 16,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  onChanged: (v) {
                    if (v.length <= 2) updateBirthDate();
                  },
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              Text(
                '/',
                style: TextStyle(color: Color(0xFFC0C0C0), fontSize: 18),
              ),
              Expanded(
                child: TextField(
                  controller: dayController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 2,
                  cursorColor: Color(0xFFF8F8F8),
                  style: TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 16.sp,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'DD',
                    hintStyle: TextStyle(
                      color: const Color(0xFFCBCBCB),
                      fontSize: 16,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  onChanged: (v) {
                    if (v.length <= 2) updateBirthDate();
                  },
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              Text(
                '/',
                style: TextStyle(color: Color(0xFFC0C0C0), fontSize: 18),
              ),
              Expanded(
                child: TextField(
                  controller: yearController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  cursorColor: Color(0xFFF8F8F8),
                  style: TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 16.sp,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'YYYY',
                    hintStyle: TextStyle(
                      color: const Color(0xFFCBCBCB),
                      fontSize: 16,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  onChanged: (v) {
                    if (v.length <= 4) updateBirthDate();
                  },
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  // -------------------------
  // 5. 닉네임 입력 페이지
  // -------------------------
  Widget _buildIdPage(double screenHeight) {
    return SingleChildScrollView(
      child: Container(
        constraints: BoxConstraints(minHeight: screenHeight),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '사용하실 아이디를 입력해주세요.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.lightTheme.colorScheme.onSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Container(
              width: 239.w,
              height: 44,
              decoration: BoxDecoration(
                color: Color(0xFF323232),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: idController,
                keyboardType: TextInputType.text,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '아이디 입력',
                  hintStyle: TextStyle(
                    color: const Color(0xFFCBCBCB),
                    fontSize: 16,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w400,
                  ),
                  contentPadding: EdgeInsets.only(bottom: 5.h),
                ),
                onChanged: (value) {
                  pageReady[4].value = value.isNotEmpty;
                },
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    id = value;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AuthFinalScreen(
                              id: id,
                              name: name,
                              phone: phoneNumber,
                              birthDate: birthDate,
                            ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 공통 입력 위젯 삭제됨 (요청에 따라 인라인 처리)

  // -------------------------
  // 공통으로 사용하는 Dropdown Container 위젯
  // -------------------------

  Widget _buildSmsCodePage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '인증번호를 입력해주세요.',
          style: TextStyle(
            color: const Color(0xFFF8F8F8),
            fontSize: 18,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24.h),
        Container(
          width: 239.w,
          height: 44,
          decoration: BoxDecoration(
            color: Color(0xff323232),
            borderRadius: BorderRadius.circular(16.5),
          ),
          padding: EdgeInsets.only(bottom: 7.h),
          child: TextField(
            controller: smsController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            cursorColor: const Color(0xFFF8F8F8),
            style: TextStyle(
              color: const Color(0xFFF8F8F8),
              fontSize: 16,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              letterSpacing: -0.08,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '인증번호',
              hintStyle: TextStyle(
                color: const Color(0xFFCBCBCB),
                fontSize: 16,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
              ),
            ),
            onChanged: (value) {
              // 인증번호 입력 여부에 따라 상태 변경
              pageReady[3].value = value.isNotEmpty;

              // 인증 완료 후, 사용자가 인증번호를 변경하면 상태 초기화
              if (isVerified) {
                setState(() {
                  isVerified = false;
                });
              }

              // 기존 타이머 취소
              _autoVerifyTimer?.cancel();

              // 인증번호가 입력되면 2초 후 자동 인증 시작
              if (value.isNotEmpty && value.length >= 6) {
                _autoVerifyTimer = Timer(Duration(seconds: 2), () {
                  _performAutoVerification(value);
                });
              }
            },
          ),
        ),
        TextButton(
          onPressed: () {
            // 인증번호 재전송 로직
            _authController.verifyPhoneNumber(phoneNumber, (
              verificationId,
              resendToken,
            ) {
              // 재전송 성공 시 처리
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('인증번호가 재전송되었습니다.')));
            }, (verificationId) {});
          },
          child: RichText(
            text: TextSpan(
              text: '인증번호 다시 받기',
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 12,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 자동 인증 수행 함수
  void _performAutoVerification(String code) async {
    if (isCheckingUser) return;

    setState(() {
      isCheckingUser = true;
    });

    // SMS 코드 저장
    smsCode = code;

    // SMS 코드로 인증 및 상태 저장
    _authController.signInWithSmsCodeAndSave(smsCode, phoneNumber, () async {
      setState(() {
        isCheckingUser = false;
        isVerified = true;
      });

      // 기존 사용자 상관없이 다음 페이지로 넘어가기
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }
}
