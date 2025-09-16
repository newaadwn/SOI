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

  @override
  void initState() {
    super.initState();
    // Provider에서 AuthViewModel을 가져오거나 widget에서 전달된 것을 사용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _authController = Provider.of<AuthController>(context, listen: false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,

      body: PageView(
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
          //. 인증번호 입력 페이지
          _buildSmsCodePage(),
          // 4. 닉네임 입력 페이지
          _buildIdPage(screenHeight),
        ],
      ),
    );
  }

  // -------------------------
  // 1. 전화번호 입력 페이지
  // -------------------------
  Widget _buildPhoneNumberPage() {
    final controller = TextEditingController();
    // 전화번호 입력 여부를 확인하는 상태 변수
    final ValueNotifier<bool> hasPhone = ValueNotifier<bool>(false);

    // 키보드 높이는 버튼 위치에만 사용
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

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
                        controller: controller,
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
                          // 전화번호 입력 여부에 따라 버튼 표시 상태 변경
                          hasPhone.value = value.isNotEmpty;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 버튼을 하단에 위치 (키보드 높이에 따라 조정)
        Positioned(
          bottom: keyboardHeight > 0 ? keyboardHeight + 20.h : 50.h,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: hasPhone,
            builder: (context, hasPhoneValue, child) {
              return Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xffffffff),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.9),
                    ),
                  ),
                  onPressed: () {
                    // 전화번호 저장
                    phoneNumber = controller.text;
                    // 인증번호 받기 로직 실행
                    _authController.verifyPhoneNumber(
                      phoneNumber,
                      (verificationId, resendToken) {
                        // 성공적으로 인증번호 전송되면 다음 페이지로
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      (verificationId) {
                        // 타임아웃 등 처리
                      },
                    );
                  },
                  child: Container(
                    width: 349.w,
                    height: 59.h,
                    alignment: Alignment.center,
                    child: Text(
                      '계속하기',
                      style: TextStyle(
                        color: Colors.black,
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
    );
  }

  // -------------------------
  // 3. 이름 입력 페이지
  // -------------------------
  Widget _buildNamePage(double screenHeight) {
    final TextEditingController nameController = TextEditingController();
    final ValueNotifier<bool> hasName = ValueNotifier<bool>(false);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        Positioned(
          top: 0.35.sh,
          left: 0,
          right: 0,
          child: Column(
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
                    // 이름 입력 여부에 따라 버튼 표시 상태 변경
                    hasName.value = value.isNotEmpty;
                  },
                ),
              ),
            ],
          ),
        ),

        // 버튼을 하단에 위치 (키보드 높이에 따라 조정)
        Positioned(
          bottom: keyboardHeight > 0 ? keyboardHeight + 20.h : 50.h,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: hasName,
            builder: (context, hasNameValue, child) {
              return Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.9),
                    ),
                  ),
                  onPressed:
                      hasNameValue
                          ? () {
                            // 이름 저장
                            name = nameController.text;
                            // 다음 페이지로 이동
                            _pageController.nextPage(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                          : null,
                  child: Container(
                    width: 349.w,
                    height: 59,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hasNameValue ? Colors.white : Color(0xff323232),
                      borderRadius: BorderRadius.circular(26.9),
                    ),
                    child: Text(
                      '계속하기',
                      style: TextStyle(
                        color: hasNameValue ? Colors.black : Colors.grey,
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
    );
  }

  // -------------------------
  // 4. 생년월일 입력 페이지 (직접 타이핑)
  // -------------------------
  Widget _buildBirthDatePage(double screenHeight) {
    final monthController = TextEditingController(text: selectedMonth ?? '');
    final dayController = TextEditingController(text: selectedDay ?? '');
    final yearController = TextEditingController(text: selectedYear ?? '');

    // 입력값 상태 동기화
    void updateBirthDate() {
      setState(() {
        selectedMonth = monthController.text;
        selectedDay = dayController.text;
        selectedYear = yearController.text;
        birthDate =
            "${selectedYear ?? ''}년 ${selectedMonth ?? ''}월 ${selectedDay ?? ''}일";
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
        SizedBox(height: 24),
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
                  inputFormatters: [
                    // 숫자만 입력
                    FilteringTextInputFormatter.digitsOnly,
                  ],
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
        SizedBox(height: 24),
      ],
    );
  }

  // -------------------------
  // 5. 닉네임 입력 페이지
  // -------------------------
  Widget _buildIdPage(double screenHeight) {
    final TextEditingController idController = TextEditingController();
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
              child: Row(
                children: [
                  SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: idController,
                      keyboardType: TextInputType.text,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '',
                        hintStyle: TextStyle(
                          fontSize: 16,
                          color: Color(0xffC0C0C0),
                        ),
                      ),
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
    final ValueNotifier<bool> hasCode = ValueNotifier<bool>(false);
    final controller = TextEditingController();

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
            controller: controller,
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
              hasCode.value = value.isNotEmpty;

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

        // Updated the TextButton to use a custom underline implementation
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
      // 인증 성공 후, 사용자가 이미 존재하는지 확인
      final userId = _authController.getUserId;
      final userExists = userId != null;

      setState(() {
        isCheckingUser = false;
        isVerified = true;
        this.userExists = userExists;
      });

      if (userExists) {
        // 사용자가 존재하면 홈 화면으로 이동
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home_navigation_screen',
          (route) => false,
        );
      } else {
        setState(() {});
      }
    });
  }
}
