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

  const AudioRecorderWidget({Key? key, this.onRecordingCompleted})
    : super(key: key);

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget> {
  late AudioController _audioController;
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
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // AudioController 상태 구독
    return Consumer<AudioController>(
      builder: (context, controller, child) {
        final bool isRecording = controller.isRecording;

        return GestureDetector(
          onLongPressStart: (details) {
            if (!isRecording) {
              _startRecording();
            }
          },
          onLongPressEnd: (details) {
            if (isRecording) {
              _stopRecording();
            }
          },

          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRecording)
                  GestureDetector(
                    onTap: _stopRecording,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                if (isRecording) SizedBox(width: 12 / 393 * screenWidth),
                isRecording
                    ? AudioWaveforms(
                      size: Size(
                        160 / 393 * screenWidth,
                        50 / 852 * screenHeight,
                      ),
                      recorderController: recorderController,
                      waveStyle: const WaveStyle(
                        waveColor: Colors.white,
                        extendWaveform: true,
                        showMiddleLine: false,
                      ),
                    )
                    : const Icon(Icons.mic, color: Colors.white, size: 45),
                if (isRecording) SizedBox(width: 12 / 393 * screenWidth),
                if (isRecording)
                  Text(
                    controller.formattedRecordingDuration,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14 / 393 * screenWidth,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    recorderController.dispose();
    super.dispose();
  }
}
