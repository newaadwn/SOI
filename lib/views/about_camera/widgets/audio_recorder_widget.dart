import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:provider/provider.dart';

import '../../../controllers/audio_controller.dart';

/// 오디오 녹음을 위한 위젯
///
/// 녹음 시작/중지 기능과 파형 표시 기능을 제공합니다.
/// AudioController을 사용하여 녹음 및 업로드 로직을 처리합니다.
class AudioRecorderWidget extends StatefulWidget {
  // 콜백은 선택 사항 (필요 없을 경우 null 허용)
  final Function(String?)? onRecordingCompleted;

  const AudioRecorderWidget({super.key, this.onRecordingCompleted});

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  // audio관련 기능을 가지고 있는 controller
  late AudioController _audioController;

  /// audio_waveforms 패키지의 녹음 컨트롤러를 설정
  late RecorderController recorderController;

  @override
  void initState() {
    super.initState();
    // audio_waveforms 설정
    recorderController =
        RecorderController()
          ..androidEncoder = AndroidEncoder.aac
          ..androidOutputFormat = AndroidOutputFormat.mpeg4
          ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
          ..sampleRate = 44100;
    recorderController.checkPermission();
    // Provider에서 필요한 Controller 가져오기
    _audioController = Provider.of<AudioController>(context, listen: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider에서 필요한 ViewModel 가져오기
    _audioController = Provider.of<AudioController>(context, listen: false);
  }

  /// 녹음 시작 함수
  Future<void> _startRecording() async {
    // 파형 표시를 위한 녹음 컨트롤러 시작
    try {
      // 파형을 그리는 패키지의 녹음 컨트롤러 시작
      await recorderController.record();
      // AudioController의 녹음 시작 함수 호출
      await _audioController.startRecording();
      setState(() {}); // UI 갱신
    } catch (e) {
      debugPrint('녹음 시작 오류: $e');
    }
  }

  /// 녹음 중지 함수
  Future<void> _stopRecording() async {
    try {
      // 파형 표시를 위한 녹음 컨트롤러 중지
      await recorderController.stop();
      // AudioController의 간단한 녹음 중지 함수 호출
      await _audioController.stopRecordingSimple();

      // 콜백이 있는 경우 녹음 파일 경로 전달
      if (widget.onRecordingCompleted != null) {
        widget.onRecordingCompleted!(_audioController.currentRecordingPath);
      }

      setState(() {}); // UI 갱신
    } catch (e) {
      debugPrint('녹음 중지 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // AudioController 상태 구독
    return Selector<AudioController, ({bool isRecording, String duration})>(
      selector:
          (context, controller) => (
            isRecording: controller.isRecording,
            duration: controller.formattedRecordingDuration,
          ),
      builder: (context, data, child) {
        return GestureDetector(
          onTap: () => data.isRecording ? null : _startRecording(),
          onDoubleTap: () => data.isRecording ? _stopRecording() : null,
          child:
              data.isRecording
                  ? _buildRecordingUI(data.duration)
                  : _buildIdleUI(),
        );
      },
    );
  }

  Widget _buildRecordingUI(String duration) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      width: 376 / 393 * screenWidth,
      height: 52,
      decoration: BoxDecoration(
        color: Color(0xff1c1c1c),
        borderRadius: BorderRadius.circular(14.6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(width: 14),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/trash.png', width: 32, height: 32),
            ),
          ),
          SizedBox(width: 19.5),
          Expanded(
            child: AudioWaveforms(
              size: Size(1, 52),
              recorderController: recorderController,
              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),

          Text(duration, style: TextStyle(color: Colors.white, fontSize: 14)),
          SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildIdleUI() {
    return Image.asset(width: 64, height: 64, 'assets/record_icon.png');
  }

  @override
  void dispose() {
    recorderController.dispose();
    super.dispose();
  }
}
