import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

class ShareScreen extends StatelessWidget {
  final String imageUrl;
  final List<double>? waveformData;
  final Duration audioDuration;
  final String categoryName;

  const ShareScreen({
    super.key,
    required this.imageUrl,
    this.waveformData,
    required this.audioDuration,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff000000),
      body: Column(
        children: [
          SizedBox(height: 85.h),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Color(0xff1c1c1c),
                borderRadius: BorderRadius.circular(18.6),
              ),
              child: Column(
                children: [
                  SizedBox(height: 17.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 17.w),
                        child: IconButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: Image.asset(
                            "assets/cancel_icon.png",
                            width: 30.2.w,
                            height: 30.2.h,
                          ),
                        ),
                      ),
                      Text(
                        "공유하기",
                        style: TextStyle(
                          color: Color(0xfff8f8f8),
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: "Pretendard",
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(right: 17.w),
                        child: IconButton(
                          onPressed: () {},
                          icon: Image.asset(
                            "assets/download_icon.png",
                            width: 25.w,
                            height: 25.h,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(color: Color(0xff595959), thickness: 1, height: 1),
                  SizedBox(height: 22.5.h),
                  Container(
                    width: 295.w,
                    height: 504.h,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 16.h),
                        Text(
                          "SOI",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: GoogleFonts.inter().fontFamily,
                          ),
                        ),
                        SizedBox(height: 5.h),
                        Text(
                          "@newdawn.soi",
                          style: TextStyle(
                            color: Color(0xffd9d9d9),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            fontFamily: GoogleFonts.inter().fontFamily,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        // 전달받은 이미지 표시
                        Container(
                          width: 259.w,
                          height: 346.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => Container(
                                    color: Colors.grey[800],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    color: Colors.grey[800],
                                    child: Icon(
                                      Icons.error,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(height: 22.h),
                        // 파형과 시간 표시
                        SizedBox(
                          width: 236.w,
                          height: 39.h,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 파형 표시하는 부분
                              if (waveformData != null &&
                                  waveformData!.isNotEmpty)
                                Expanded(
                                  child: CustomWaveformWidget(
                                    waveformData: waveformData!,
                                    color: Colors.white,
                                    activeColor: Colors.white,
                                    progress: 0.0,
                                  ),
                                ),
                              SizedBox(width: 10.w),
                              // 시간을 표시하는 부분
                              Text(
                                _formatDuration(audioDuration),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: GoogleFonts.inter().fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 시간을 포맷팅하는 메서드
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
