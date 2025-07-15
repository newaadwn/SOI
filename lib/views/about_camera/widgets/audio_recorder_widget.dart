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
  // 콜백 함수 시그니처 변경: 파일 경로와 파형 데이터 함께 전달
  final Function(String?, List<double>?)? onRecordingCompleted;

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
    // This line might be redundant if _audioController is already initialized in initState
    // unless there's a specific reason to re-fetch it here (e.g., if the provider changes).
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
      debugPrint('🎤 녹음 중지 시작...');

      // 파형 표시를 위한 녹음 컨트롤러 중지
      final path = await recorderController.stop();
      debugPrint('📁 RecorderController 중지 완료, 경로: $path');

      // AudioController의 간단한 녹음 중지 함수 호출
      await _audioController.stopRecordingSimple();
      debugPrint('✅ AudioController 중지 완료');

      // 파형 데이터 추출 (더 안정적인 방법)
      List<double>? waveformData;

      // 1차: 즉시 파형 데이터 확인
      try {
        waveformData = recorderController.waveData;
        debugPrint('🌊 1차 파형 데이터 추출: ${waveformData.length} samples');

        if (waveformData.isNotEmpty) {
          debugPrint('✅ 실시간 파형 데이터 추출 성공');
          debugPrint('📊 첫 5개 샘플: ${waveformData.take(5).toList()}');
          debugPrint(
            '📊 마지막 5개 샘플: ${waveformData.length > 5 ? waveformData.sublist(waveformData.length - 5) : waveformData}',
          );
        } else {
          debugPrint('⚠️ 1차 파형 데이터 추출 실패 - 재시도 시작');

          // 2차: 짧은 지연 후 재시도 (RecorderController 안정화 대기)
          await Future.delayed(const Duration(milliseconds: 100));
          waveformData = recorderController.waveData;
          debugPrint('🌊 2차 파형 데이터 추출: ${waveformData.length} samples');

          if (waveformData.isEmpty) {
            debugPrint('❌ 2차 파형 데이터 추출도 실패');
          } else {
            debugPrint('✅ 2차 파형 데이터 추출 성공');
            debugPrint('📊 첫 5개 샘플: ${waveformData.take(5).toList()}');
          }
        }
      } catch (e) {
        debugPrint('❌ 파형 데이터 추출 오류: $e');
        waveformData = null;
      }

      // 최종 결과 출력
      if (waveformData != null && waveformData.isNotEmpty) {
        debugPrint('🎯 최종 파형 데이터: ${waveformData.length} samples 추출 완료');
        debugPrint(
          '📊 데이터 범위: ${waveformData.reduce((a, b) => a < b ? a : b)} ~ ${waveformData.reduce((a, b) => a > b ? a : b)}',
        );
      } else {
        debugPrint('💀 최종 파형 데이터 추출 실패 - null 전달');
      }

      // 콜백이 있는 경우 녹음 파일 경로와 파형 데이터 함께 전달
      if (widget.onRecordingCompleted != null) {
        debugPrint('📞 콜백 함수 호출 중...');
        debugPrint('  - audioPath: ${_audioController.currentRecordingPath}');
        debugPrint('  - waveformData 길이: ${waveformData?.length}');

        widget.onRecordingCompleted!(
          _audioController.currentRecordingPath,
          waveformData,
        );

        debugPrint('✅ 콜백 함수 호출 완료');
      }

      setState(() {}); // UI 갱신
    } catch (e) {
      debugPrint('❌ 녹음 중지 전체 오류: $e');

      // 에러 발생 시에도 콜백 호출 (파형 데이터는 null)
      if (widget.onRecordingCompleted != null) {
        debugPrint('📞 에러 상황 콜백 호출');
        widget.onRecordingCompleted!(
          _audioController.currentRecordingPath,
          null,
        );
      }
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
        color: const Color(0xff1c1c1c),
        borderRadius: BorderRadius.circular(14.6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const SizedBox(width: 14),
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
          const SizedBox(width: 19.5),
          Expanded(
            child: AudioWaveforms(
              size: const Size(
                1,
                52,
              ), // Adjust size as needed, 1 here is likely a placeholder
              recorderController: recorderController,
              waveStyle: const WaveStyle(
                waveColor: Colors.white,
                extendWaveform: true,
                showMiddleLine: false,
              ),
            ),
          ),
          Text(
            duration,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildIdleUI() {
    return Image.asset('assets/record_icon.png', width: 64, height: 64);
  }

  @override
  void dispose() {
    recorderController.dispose();
    super.dispose();
  }
}
