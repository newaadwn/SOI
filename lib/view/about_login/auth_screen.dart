import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../view_model/auth_view_model.dart';
import 'auth_final_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.authViewModel});

  final AuthViewModel? authViewModel;

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final PageController _pageController = PageController();
  late AuthViewModel _authViewModel;

  // 입력 데이터
  String phoneNumber = '';
  String smsCode = '';
  String name = '';
  String birthDate = '';
  String nickName = '';

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
        _authViewModel =
            widget.authViewModel ??
            Provider.of<AuthViewModel>(context, listen: false);
      });
    });

    print('AuthViewModel 초기화 완료');
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보
    final double screenHeight = MediaQuery.of(context).size.height;

    // Provider에서 AuthViewModel을 가져옴
    if (!mounted) return Container(); // 안전 검사

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // 스와이프로 이동 방지
        children: [
          // 1. 이름 입력 페이지
          _buildNamePage(screenHeight),
          // 2. 생년월일 입력 페이지
          _buildBirthDatePage(screenHeight),
          // 3. 전화번호 입력 페이지
          _buildPhoneNumberPage(screenHeight),
          //     인증번호 입력 페이지
          _buildSmsCodePage(screenHeight),
          // 4. 닉네임 입력 페이지
          _buildNickNamePage(screenHeight),
        ],
      ),
    );
  }

  // -------------------------
  // 1. 전화번호 입력 페이지
  // -------------------------
  Widget _buildPhoneNumberPage(double screenHeight) {
    return _buildScrollContainer(
      screenHeight,
      _buildInputPage(
        title: 'SOI 접속을 위해 전화번호를 입력해주세요.',
        hintText: '전화번호',
        keyboardType: TextInputType.phone,
        buttonText: '인증번호 받기',
        icon: Icon(
          SolarIconsOutline.phone,
          color: const Color(0xffC0C0C0),
          size: 24,
        ),
        onNext: (value) {
          phoneNumber = value;
          // 실제 Auth 로직 호출
          _authViewModel.verifyPhoneNumber(
            phoneNumber,
            (verificationId, resendToken) {
              // 성공적으로 인증번호 전송
              _goToNextPage();
            },
            (verificationId) {
              // Auto-retrieval timeout 등
            },
          );
        },
      ),
    );
  }

  // -------------------------
  // 2. 인증번호 입력 페이지
  // -------------------------
  Widget _buildSmsCodePage(double screenHeight) {
    return _buildScrollContainer(
      screenHeight,
      _buildInputPage(
        title: '인증번호를 입력해주세요.',
        hintText: '인증번호',
        keyboardType: TextInputType.number,
        buttonText: '인증하기',
        onNext: (value) {
          smsCode = value;
          // 실제 Auth 로직 호출
          _authViewModel.signInWithSmsCode(smsCode, _goToNextPage);
        },
      ),
    );
  }

  // -------------------------
  // 3. 이름 입력 페이지
  // -------------------------
  Widget _buildNamePage(double screenHeight) {
    return _buildScrollContainer(
      screenHeight,
      _buildInputPage(
        title: '당신의 이름을 알려주세요.',
        hintText: '입력',
        keyboardType: TextInputType.text,
        buttonText: '다음',
        onNext: (value) {
          name = value;
          _goToNextPage();
        },
      ),
    );
  }

  // -------------------------
  // 4. 생년월일 입력 페이지
  // -------------------------
  Widget _buildBirthDatePage(double screenHeight) {
    birthDate = "$selectedYear년 $selectedMonth월 $selectedDay일";
    return _buildScrollContainer(screenHeight, _buildBirthDateContent());
  }

  Widget _buildBirthDateContent() {
    return Column(
      children: [
        Text(
          '생년월일을 입력해주세요.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: GoogleFonts.inter().fontFamily,
            color: AppTheme.lightTheme.colorScheme.onSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 월 선택 Dropdown
            _buildDropdownContainer(
              width: 91,
              selectedValue: selectedMonth,
              hintText: 'MM',
              items: List.generate(12, (index) {
                final month = index + 1;
                return DropdownMenuItem(
                  value: '$month',
                  child: Text('$month월'),
                );
              }),
              onChanged: (value) {
                setState(() {
                  selectedMonth = value;
                });
              },
              iconLeftPadding: 20,
            ),
            SizedBox(width: 22),
            // 일 선택 Dropdown
            _buildDropdownContainer(
              width: 91,
              selectedValue: selectedDay,
              hintText: 'DD',
              items: List.generate(31, (index) {
                final day = index + 1;
                return DropdownMenuItem(value: '$day', child: Text('$day일'));
              }),
              onChanged: (value) {
                setState(() {
                  selectedDay = value;
                });
              },
              iconLeftPadding: 18,
            ),
            SizedBox(width: 22),
            // 년도 선택 Dropdown
            _buildDropdownContainer(
              width: 100,
              selectedValue: selectedYear,
              hintText: 'YYYY',
              items: List.generate(100, (index) {
                final year = DateTime.now().year - index;
                return DropdownMenuItem(value: '$year', child: Text('$year년'));
              }),
              onChanged: (value) {
                setState(() {
                  selectedYear = value;
                });
              },
              iconLeftPadding: 5,
            ),
          ],
        ),
        SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            // 버튼 클릭 시 다음 페이지로 넘어간 뒤,
            // onNext 콜백에 텍스트필드 값을 넘겨줍니다.
            _goToNextPage();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            "다음",
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.lightTheme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------
  // 5. 닉네임 입력 페이지
  // -------------------------
  Widget _buildNickNamePage(double screenHeight) {
    return _buildScrollContainer(
      screenHeight,
      _buildInputPage(
        title: '사용하실 닉네임을 입력해주세요.',
        hintText: '',
        keyboardType: TextInputType.text,
        buttonText: '다음',
        onNext: (value) {
          nickName = value;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AuthFinalScreen(
                    nickname: nickName,
                    name: name,
                    phone: phoneNumber,
                    birthDate: birthDate,
                  ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------
  // 공통으로 사용하는 입력 페이지 위젯
  // -------------------------
  Widget _buildInputPage({
    required String title,
    required String hintText,
    required TextInputType keyboardType,
    required String buttonText,
    required Function(String) onNext,
    Icon? icon,
  }) {
    final controller = TextEditingController();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
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
              if (icon != null) ...[
                const SizedBox(width: 17),
                icon,
                const SizedBox(width: 10),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: const Color(0xffC0C0C0),
                    ),
                    contentPadding: EdgeInsets.only(bottom: 6),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            // 버튼 클릭 시 다음 페이지로 넘어간 뒤,
            // onNext 콜백에 텍스트필드 값을 넘겨줍니다.
            onNext(controller.text);
            //_goToNextPage();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            buttonText,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.lightTheme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------
  // 공통으로 사용하는 Scroll + Container 위젯
  // -------------------------
  Widget _buildScrollContainer(double screenHeight, Widget child) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        constraints: BoxConstraints(minHeight: screenHeight),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  // -------------------------
  // 공통으로 사용하는 Dropdown Container 위젯
  // -------------------------
  Widget _buildDropdownContainer({
    required double width,
    required String? selectedValue,
    required String hintText,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    double iconLeftPadding = 20,
  }) {
    return Container(
      width: width,
      height: 51,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Color(0xffFBFBFB),
      ),
      alignment: Alignment.centerRight,
      child: DropdownButton<String>(
        value: selectedValue,
        underline: Container(),
        hint: Text(
          selectedValue ?? hintText,
          style: TextStyle(
            fontFamily: GoogleFonts.montserrat().fontFamily,
            color: Color(0xffC0C0C0),
            fontWeight: FontWeight.w500,
          ),
        ),
        dropdownColor: Colors.white,
        style: TextStyle(
          fontFamily: GoogleFonts.montserrat().fontFamily,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
        icon: Padding(
          padding: EdgeInsets.only(left: iconLeftPadding),
          child: Icon(
            Icons.keyboard_arrow_down_outlined,
            size: 30,
            color: Color(0xffC0C0C0),
          ),
        ),
        items: items,
        onChanged: onChanged,
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
}
