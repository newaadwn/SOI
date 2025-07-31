import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PageController _pageController = PageController();
  late AuthController _authController;

  String phoneNumber = '';
  String smsCode = '';

  // 현재 페이지 인덱스
  int currentPage = 0;

  // 사용자가 존재하는지 여부 및 상태 관리
  bool userExists = false;
  bool isVerified = false;
  bool isCheckingUser = false;

  // 인증번호 입력 상태를 관리하는 ValueNotifier
  final ValueNotifier<bool> hasCode = ValueNotifier<bool>(false);

  // 인증번호 입력 컨트롤러
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Provider에서 AuthController를 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _authController = Provider.of<AuthController>(context, listen: false);
      });
    });
    // debugPrint('AuthController 초기화 완료');
  }

  @override
  void dispose() {
    _pageController.dispose();
    hasCode.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보
    final double screenHeight = MediaQuery.of(context).size.height;
    //final double screenWidth = MediaQuery.of(context).size.width;

    // Provider에서 AuthViewModel을 가져옴
    if (!mounted) return Container(); // 안전 검사

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      resizeToAvoidBottomInset: true, // 키보드에 대응하도록 변경
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
        leading:
            currentPage > 0
                ? IconButton(
                  icon: Icon(Icons.arrow_back_ios),
                  onPressed: _goToPreviousPage,
                )
                : null,
        title: Text(
          'SOI 로그인',
          style: TextStyle(
            color: AppTheme.lightTheme.colorScheme.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(), // 스와이프로 페이지 전환 비활성화
        onPageChanged: (index) {
          setState(() {
            currentPage = index;
          });
        },
        children: [
          // 1. 전화번호 입력 페이지
          _buildPhoneNumberPage(screenHeight),
          // 2. 인증번호 입력 페이지
          _buildSmsCodePage(screenHeight),
        ],
      ),
    );
  }

  // -------------------------
  // 1. 전화번호 입력 페이지
  // -------------------------
  Widget _buildPhoneNumberPage(double screenHeight) {
    final controller = TextEditingController();
    // 전화번호 입력 여부를 확인하는 상태 변수
    final ValueNotifier<bool> hasPhone = ValueNotifier<bool>(false);

    // 키보드 높이 감지
    // 키보드 높이를 감지하여 패딩 조정
    final keyboardHeight = MediaQuery.of(context).viewInsets.top;

    return Container(
      height: screenHeight,
      alignment: Alignment.center,
      padding: EdgeInsets.only(bottom: (keyboardHeight)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'SOI 접속을 위해 전화번호를 입력해주세요.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTheme.colorScheme.onSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Container(
            width: 239,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 17),
                Icon(
                  SolarIconsOutline.phone,
                  color: const Color(0xffC0C0C0),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '전화번호',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: const Color(0xffC0C0C0),
                      ),
                      contentPadding: EdgeInsets.only(bottom: 6),
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
          SizedBox(height: 24),
          // 전화번호가 입력되면 버튼 표시
          ValueListenableBuilder<bool>(
            valueListenable: hasPhone,
            builder: (context, hasPhoneValue, child) {
              return hasPhoneValue
                  ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff323232),
                      minimumSize: Size(239, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                          _goToNextPage();
                        },
                        (verificationId) {
                          // 타임아웃 등 처리
                        },
                      );
                    },
                    child: Text(
                      '인증번호 받기',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  : SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  // -------------------------
  // 2. 인증번호 입력 페이지
  // -------------------------
  Widget _buildSmsCodePage(double screenHeight) {
    final ValueNotifier<bool> hasCode = ValueNotifier<bool>(false);
    final controller = TextEditingController();

    // 키보드 높이 감지
    // 키보드 높이를 감지하여 패딩 조정
    final keyboardHeight = MediaQuery.of(context).viewInsets.top;

    return Container(
      height: screenHeight,
      alignment: Alignment.center,
      padding: EdgeInsets.only(bottom: (keyboardHeight + 20)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '인증번호를 입력해주세요.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightTheme.colorScheme.onSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          Container(
            width: 239,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 17),
                Icon(
                  SolarIconsOutline.key,
                  color: const Color(0xffC0C0C0),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '인증번호',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: const Color(0xffC0C0C0),
                      ),
                      contentPadding: EdgeInsets.only(bottom: 6),
                    ),
                    onChanged: (value) {
                      // 인증번호 입력 여부에 따라 버튼 표시 상태 변경
                      hasCode.value = value.isNotEmpty;
                      // 인증 완료 후 사용자가 인증번호를 변경하면 상태 초기화
                      if (isVerified) {
                        setState(() {
                          isVerified = false;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          ValueListenableBuilder<bool>(
            valueListenable: hasCode,
            builder: (context, hasCodeValue, child) {
              // 인증번호를 입력했을 때만 버튼 표시
              return hasCodeValue
                  ? isCheckingUser
                      // 1. 확인 중일 때는 로딩 표시
                      ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppTheme.lightTheme.colorScheme.primary,
                          minimumSize: Size(239, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: null, // 로딩 중에는 버튼 비활성화
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                      // 2. 인증 완료 후 사용자가 존재하지 않을 때 회원가입 버튼 표시
                      : isVerified && !userExists
                      ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppTheme.lightTheme.colorScheme.primary,
                          minimumSize: Size(239, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // 회원가입 페이지로 이동
                          Navigator.pushNamed(context, '/auth');
                        },
                        child: Text(
                          '회원가입하기',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                      // 3. 그 외에는 인증하기 버튼 표시
                      : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xff323232),
                          minimumSize: Size(239, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          setState(() {
                            isCheckingUser = true;
                          });

                          // SMS 코드 저장
                          smsCode = controller.text;

                          // ✅ 개선된 SMS 코드로 인증 및 상태 저장
                          _authController.signInWithSmsCodeAndSave(
                            smsCode,
                            phoneNumber, // 전화번호도 함께 전달
                            () async {
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
                                  (route) => false, // 모든 이전 페이지 삭제
                                );
                              } else {
                                // 사용자가 존재하지 않을 때 UI 업데이트를 위해 setState 호출
                                setState(() {
                                  // 상태는 이미 위에서 설정했으므로 여기서는 그냥 UI 업데이트를 위해 setState 호출
                                });
                              }
                            },
                          );
                        },
                        child: Text(
                          '인증하기',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                  : SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  // -------------------------
  // 다음 페이지로 이동
  // -------------------------
  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // -------------------------
  // 이전 페이지로 이동
  // -------------------------
  void _goToPreviousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
