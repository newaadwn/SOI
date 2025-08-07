import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/theme.dart';
import '../../controllers/auth_controller.dart';
import 'auth_final_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AuthScreen extends StatefulWidget {
  AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final PageController _pageController = PageController();
  late AuthController _authViewModel;

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
        _authViewModel = Provider.of<AuthController>(context, listen: false);
      });
    });

    // debugPrint('AuthViewModel 초기화 완료');
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보
    final double screenHeight = MediaQuery.of(context).size.height;

    // Provider에서 AuthViewModel을 가져옴
    if (!mounted) return Container(); // 안전 검사

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
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
        actions: [
          // 다음 버튼을 상단 우측에 배치
          if (currentPage < 4 && currentPage != 2) // 마지막 페이지가 아닐 때만 다음 버튼 표시
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: TextButton(
                onPressed: () {
                  _handleNextButtonPressed();
                },
                child: Row(
                  children: [
                    Text(
                      "다음",
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white),
                  ],
                ),
              ),
            ),
        ],
        // 상단 중앙에 단계 표시 점들 배치
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return Container(
              width: 8.w,
              height: 8.h,
              margin: EdgeInsets.symmetric(horizontal: 3.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    index == currentPage
                        ? Color(0xff323232)
                        : Color(0xffd9d9d9),
              ),
            );
          }),
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        physics:
            (currentPage != 2)
                ? ScrollPhysics()
                : NeverScrollableScrollPhysics(),
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
          _buildPhoneNumberPage(screenHeight),
          //     인증번호 입력 페이지
          _buildSmsCodePage(screenHeight),
          // 4. 닉네임 입력 페이지
          _buildIdPage(screenHeight),
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

    return _buildScrollContainer(
      screenHeight,
      Column(
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
          SizedBox(height: 24.h),
          Container(
            width: 239.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(width: 17.w),
                Icon(
                  SolarIconsOutline.phone,
                  color: Color(0xffC0C0C0),
                  size: 24.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '전화번호',
                      hintStyle: TextStyle(
                        fontSize: 16.sp,
                        color: Color(0xffC0C0C0),
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
                      _authViewModel.verifyPhoneNumber(
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
    return _buildScrollContainer(
      screenHeight,
      Column(
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
                SizedBox(width: 17),
                Icon(SolarIconsOutline.key, color: Color(0xffC0C0C0), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '인증번호',
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: Color(0xffC0C0C0),
                      ),
                      contentPadding: EdgeInsets.only(bottom: 6),
                    ),
                    onChanged: (value) {
                      // 인증번호 입력 여부에 따라 버튼 표시 상태 변경
                      hasCode.value = value.isNotEmpty;
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
              return hasCodeValue
                  ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff323232),
                      minimumSize: Size(239, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // ✅ 회원가입 시에도 로그인 상태 저장
                      _authViewModel.signInWithSmsCodeAndSave(
                        controller.text,
                        phoneNumber, // 전화번호도 함께 전달
                        () {
                          // 인증 완료 후 다음 페이지로
                          _goToNextPage();
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
      ],
    );
  }

  // -------------------------
  // 5. 닉네임 입력 페이지
  // -------------------------
  Widget _buildIdPage(double screenHeight) {
    return _buildScrollContainer(
      screenHeight,
      _buildInputPage(
        title: '사용하실 아이디를 입력해주세요.',
        hintText: '',
        keyboardType: TextInputType.text,
        buttonText: '다음',
        onNext: (value) {
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
                SizedBox(width: 17),
                icon,
                SizedBox(width: 10),
              ],
              SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontSize: 16,
                      color: Color(0xffC0C0C0),
                    ),
                    contentPadding: EdgeInsets.only(bottom: 6),
                  ),
                  onSubmitted: (value) {
                    // 텍스트 입력 완료 시 onNext 콜백 호출
                    if (value.isNotEmpty) {
                      onNext(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // 하단 다음 버튼 제거 - 상단 우측의 다음 버튼으로 대체됨
      ],
    );
  }

  // -------------------------
  // 공통으로 사용하는 Scroll + Container 위젯
  // -------------------------
  Widget _buildScrollContainer(double screenHeight, Widget child) {
    return SingleChildScrollView(
      child: Container(
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
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // -------------------------
  // 이전 페이지로 이동
  // -------------------------
  void _goToPreviousPage() {
    _pageController.previousPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // -------------------------
  // 다음 버튼 클릭 시 처리
  // -------------------------
  void _handleNextButtonPressed() {
    switch (currentPage) {
      case 0:
        _goToNextPage();
        break;
      case 1:
        _goToNextPage();
        break;
      case 2:
        _goToNextPage();
        break;
      case 3:
        _goToNextPage();
        break;
      case 4:
        // 마지막 페이지에서는 다음 버튼이 표시되지 않으므로 이 코드는 실행되지 않음
        break;
    }
  }
}
