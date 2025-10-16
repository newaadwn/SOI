import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

/// 약관 동의 페이지
class AgreementPage extends StatelessWidget {
  final String name;
  final bool agreeAll;
  final bool agreeServiceTerms;
  final bool agreePrivacyTerms;
  final bool agreeMarketingInfo;
  final ValueChanged<bool> onToggleAll;
  final ValueChanged<bool> onToggleServiceTerms;
  final ValueChanged<bool> onTogglePrivacyTerms;
  final ValueChanged<bool> onToggleMarketingInfo;
  final PageController? pageController;

  const AgreementPage({
    super.key,
    required this.name,
    required this.agreeAll,
    required this.agreeServiceTerms,
    required this.agreePrivacyTerms,
    required this.agreeMarketingInfo,
    required this.onToggleAll,
    required this.onToggleServiceTerms,
    required this.onTogglePrivacyTerms,
    required this.onToggleMarketingInfo,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    final String displayName = name.isNotEmpty ? name : '회원';

    return Stack(
      children: [
        Positioned(
          top: 60.h,
          left: 20.w,
          child: IconButton(
            onPressed: () {
              pageController?.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: (320).h),
                Text(
                  '$displayName님, 환영합니다.',
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 20,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  '선택하신 정보를 기반으로 개인화된\n서비스를 제공해드릴게요.',
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 16,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w600,
                    height: 1.61,
                    letterSpacing: 0.32,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: (136.1).h),
                _AgreementOption(
                  label: '약관 전체 동의',
                  value: agreeAll,
                  onChanged: onToggleAll,
                  onTap: () {},
                ),
                SizedBox(height: 24.h),
                _AgreementOption(
                  label: '이용약관 동의(필수)',
                  value: agreeServiceTerms,
                  onChanged: onToggleServiceTerms,
                  showArrow: true,
                  onTap: () {},
                ),
                SizedBox(height: (10.2).h),
                _AgreementOption(
                  label: '개인정보 수집 및 이용동의(필수)',
                  value: agreePrivacyTerms,
                  onChanged: onTogglePrivacyTerms,
                  showArrow: true,
                  onTap: () async {
                    final url = Uri.parse(
                      "https://firebasestorage.googleapis.com/v0/b/soi-privacy.firebasestorage.app/o/index.html?alt=media&token=a34771bf-ec02-4fe0-9d48-0f272068908e",
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      debugPrint('Could not launch $url');
                    }
                  },
                ),
                SizedBox(height: (10.2).h),
                _AgreementOption(
                  label: 'E-mail 및 SMS 광고성 정보 수신동의(선택)',
                  value: agreeMarketingInfo,
                  onChanged: onToggleMarketingInfo,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AgreementOption extends StatelessWidget {
  final String label;
  final bool value;
  final bool showArrow;
  final ValueChanged<bool> onChanged;
  final Function onTap;

  const _AgreementOption({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onTap,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => onChanged(!value),
            child: Row(
              children: [
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: Checkbox(
                    value: value,
                    onChanged: (checked) => onChanged(checked ?? false),
                    shape: CircleBorder(),
                    side: BorderSide(color: Color(0xFFffffff), width: 1.4),
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return Colors.transparent;
                    }),
                    checkColor: Colors.black,
                    splashRadius: 0,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showArrow)
          InkWell(
            onTap: () => onTap(),
            child: Icon(
              Icons.arrow_forward_ios_sharp,
              color: Colors.white,
              size: 20.w,
            ),
          ),
      ],
    );
  }
}
