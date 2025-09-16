import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import 'auth_final_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/common/continue_button.dart';
import 'widgets/pages/name_input_page.dart';
import 'widgets/pages/birth_date_page.dart';
import 'widgets/pages/phone_input_page.dart';
import 'widgets/pages/sms_code_page.dart';
import 'widgets/pages/id_input_page.dart';

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

  // 중복 아이디 체크를 위한 변수
  String? idErrorMessage;
  Timer? debounceTimer;

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

    // ID 컨트롤러 리스너 추가
    idController.addListener(() {
      if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        final id = idController.text.trim();
        if (id.isNotEmpty) {
          final isDuplicate = await _authController.checkIdDuplicate(id);
          setState(() {
            idErrorMessage =
                isDuplicate ? '이미 사용 중인 아이디입니다.' : '사용 가능한 아이디입니다.';
          });
        } else {
          setState(() {
            idErrorMessage = null;
          });
        }
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
    debounceTimer?.cancel();
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
              NameInputPage(
                controller: nameController,
                onChanged: (value) {
                  pageReady[0].value = value.isNotEmpty;
                },
              ),
              // 2. 생년월일 입력 페이지
              BirthDatePage(
                monthController: monthController,
                dayController: dayController,
                yearController: yearController,
                onChanged: () {
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
                },
              ),
              // 3. 전화번호 입력 페이지
              PhoneInputPage(
                controller: phoneController,
                onChanged: (value) {
                  pageReady[2].value = value.isNotEmpty;
                },
              ),
              // 인증번호 입력 페이지
              SmsCodePage(
                controller: smsController,
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
                onResendPressed: () {
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
              ),
              // 4. 아이디 입력 페이지
              IdInputPage(
                controller: idController,
                screenHeight: screenHeight,
                errorMessage: idErrorMessage,
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
                    final bool isEnabled =
                        ready &&
                        (currentPage != 4 ||
                            idErrorMessage == null ||
                            idErrorMessage == '사용 가능한 아이디입니다.');

                    return ContinueButton(
                      isEnabled: isEnabled,
                      onPressed:
                          isEnabled
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
                                          duration: Duration(milliseconds: 300),
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
                    );
                  },
                ),
              ),
        ],
      ),
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
