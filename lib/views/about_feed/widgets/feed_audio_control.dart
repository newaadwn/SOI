import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/audio_controller.dart';
import '../../../models/photo_data_model.dart';
import '../../../utils/format_utils.dart';
import '../../about_archiving/widgets/custom_waveform_widget.dart';
import '../widgets/user_profile_avatar.dart';
import '../managers/feed_data_manager.dart';

/// 🎵 피드 오디오 컨트롤 위젯
/// 사진의 오디오 재생 컨트롤과 파형 표시를 담당합니다.
class FeedAudioControl extends StatelessWidget {
  final PhotoDataModel photo;
  final FeedDataManager dataManager;

  const FeedAudioControl({
    super.key,
    required this.photo,
    required this.dataManager,
  });

  @override
  Widget build(BuildContext context) {
    if (photo.audioUrl.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Positioned(
      bottom: screenHeight * 0.018,
      left: screenWidth * 0.05,
      right: screenWidth * 0.05,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.032,
          vertical: screenHeight * 0.01,
        ),
        decoration: BoxDecoration(
          color: Color(0xff000000).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 왼쪽 프로필 이미지 (작은 버전)
            UserProfileAvatar(
              photo: photo,
              userProfileImages: dataManager.userProfileImages,
              profileLoadingStates: dataManager.profileLoadingStates,
              size: screenWidth * 0.085,
              borderWidth: 1.5,
            ),
            SizedBox(width: screenWidth * 0.032),

            // 가운데 파형 (progress 포함)
            Expanded(
              child: SizedBox(
                height: screenHeight * 0.04,
                child: _buildWaveformWidgetWithProgress(),
              ),
            ),

            SizedBox(width: screenWidth * 0.032),

            // 오른쪽 재생 시간 (실시간 업데이트)
            Consumer<AudioController>(
              builder: (context, audioController, child) {
                // 현재 사진의 오디오가 재생 중인지 확인
                final isCurrentAudio =
                    audioController.isPlaying &&
                    audioController.currentPlayingAudioUrl == photo.audioUrl;

                // 실시간 재생 시간 사용
                Duration displayDuration = Duration.zero;
                if (isCurrentAudio) {
                  displayDuration = audioController.currentPosition;
                }

                return Text(
                  FormatUtils.formatDuration(displayDuration),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth * 0.032,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 커스텀 파형 위젯을 빌드하는 메서드 (실시간 progress 포함)
  Widget _buildWaveformWidgetWithProgress() {
    if (photo.audioUrl.isEmpty ||
        photo.waveformData == null ||
        photo.waveformData!.isEmpty) {
      return Container(
        height: 32,
        alignment: Alignment.center,
        child: const Text(
          '오디오 없음',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      );
    }

    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isCurrentAudio =
            audioController.isPlaying &&
            audioController.currentPlayingAudioUrl == photo.audioUrl;

        double progress = 0.0;
        if (isCurrentAudio &&
            audioController.currentDuration.inMilliseconds > 0) {
          progress = (audioController.currentPosition.inMilliseconds /
                  audioController.currentDuration.inMilliseconds)
              .clamp(0.0, 1.0);
        }

        return GestureDetector(
          onTap: () => _toggleAudio(context),
          child: Container(
            alignment: Alignment.center,
            child: CustomWaveformWidget(
              waveformData: photo.waveformData!,
              color: const Color(0xff5a5a5a),
              activeColor: Colors.white,
              progress: progress,
            ),
          ),
        );
      },
    );
  }

  /// 오디오 재생/일시정지 토글
  Future<void> _toggleAudio(BuildContext context) async {
    if (photo.audioUrl.isEmpty) {
      debugPrint('오디오 URL이 없습니다');
      return;
    }

    try {
      await Provider.of<AudioController>(
        context,
        listen: false,
      ).toggleAudio(photo.audioUrl);
    } catch (e) {
      debugPrint('오디오 재생 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('음성 파일을 재생할 수 없습니다: $e')));
      }
    }
  }
}
