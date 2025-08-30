import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../models/comment_record_model.dart';
import '../../controllers/comment_record_controller.dart';
import '../../controllers/comment_audio_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/format_utils.dart';

/// 재사용 가능한 음성 댓글 리스트 Bottom Sheet
/// feed / archive 모두에서 사용
class VoiceCommentListSheet extends StatelessWidget {
  final String photoId;
  final String title; // 상단 제목 (예: "공감")
  const VoiceCommentListSheet({
    super.key,
    required this.photoId,
    this.title = '공감',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.8),
          topRight: Radius.circular(24.8),
        ),
      ),
      padding: EdgeInsets.only(
        top: 18.h,
        bottom: 18.h,
        left: 27.w,
        right: 27.w,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              fontFamily: 'Pretendard',
            ),
          ),
          SizedBox(height: 20.h),
          Consumer<CommentRecordController>(
            builder: (context, recordController, _) {
              return StreamBuilder<List<CommentRecordModel>>(
                stream: recordController.getCommentRecordsStream(photoId),
                builder: (context, snapshot) {
                  final state = snapshot.connectionState;
                  if (state == ConnectionState.waiting) {
                    return SizedBox(
                      height: 100.h,
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 100.h,
                      child: Center(
                        child: Text(
                          '불러오기 실패',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    );
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return SizedBox(
                      height: 100.h,
                      child: Center(
                        child: Text(
                          '댓글이 없습니다',
                          style: TextStyle(
                            color: const Color(0xFF9E9E9E),
                            fontSize: 16.sp,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }
                  return Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => SizedBox(height: 18.h),
                      itemBuilder: (context, index) {
                        final comment = list[index];
                        return _VoiceCommentRow(comment: comment);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VoiceCommentRow extends StatelessWidget {
  final CommentRecordModel comment;
  const _VoiceCommentRow({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Consumer2<CommentAudioController, CommentRecordController>(
      builder: (context, audioController, recordController, child) {
        final isPlaying = audioController.isCommentPlaying(comment.id);
        final progress = audioController.getCommentProgress(comment.id);
        final position = audioController.getCommentPosition(comment.id);
        final duration = audioController.getCommentDuration(comment.id);
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // 프로필 이미지
                ClipOval(
                  child:
                      comment.profileImageUrl.isNotEmpty
                          ? CachedNetworkImage(
                            imageUrl: comment.profileImageUrl,
                            width: 38.w,
                            height: 38.w,
                            fit: BoxFit.cover,
                          )
                          : Container(
                            width: 38.w,
                            height: 38.w,
                            color: const Color(0xFF4E4E4E),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ),
                          ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _UserDisplayName(userId: comment.recorderUser),
                      SizedBox(height: 6.h),
                      _WaveformPlaybackBar(
                        isPlaying: isPlaying,
                        progress: progress,
                        onPlayPause: () async {
                          if (isPlaying) {
                            await audioController.pauseComment(comment.id);
                          } else {
                            await audioController.playComment(
                              comment.id,
                              comment.audioUrl,
                            );
                          }
                        },
                        position: position,
                        duration: duration,
                        waveformData: comment.waveformData, // 실제 파형 데이터 전달
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Spacer(),
                Text(
                  FormatUtils.formatRelativeTime(comment.createdAt),
                  style: TextStyle(
                    color: const Color(0xFFB5B5B5),
                    fontSize: 12.sp,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(width: 12.w),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WaveformPlaybackBar extends StatelessWidget {
  final bool isPlaying;
  final double progress; // 0~1
  final Future<void> Function() onPlayPause;
  final Duration position;
  final Duration duration;
  final List<double> waveformData; // 실제 파형 데이터 추가
  const _WaveformPlaybackBar({
    required this.isPlaying,
    required this.progress,
    required this.onPlayPause,
    required this.position,
    required this.duration,
    required this.waveformData, // 필수 파라미터로 추가
  });

  @override
  Widget build(BuildContext context) {
    final totalMs =
        duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds; // div 0 방지
    final playedMs = position.inMilliseconds;
    final barProgress = (playedMs / totalMs).clamp(0.0, 1.0);

    return Container(
      height: 56.h,
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPlayPause,
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 25.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 회색 배경 파형 (기본 흰색이지만 재생 시 회색으로)
                _buildWaveformBase(
                  color: isPlaying ? const Color(0xFF4A4A4A) : Colors.white,
                ),
                // 흰색 진행 파형 (재생 중에만 표시)
                if (isPlaying)
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: barProgress,
                      child: _buildWaveformBase(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformBase({required Color color}) {
    // 실제 waveformData 기반 파형 표현
    if (waveformData.isEmpty) {
      // 데이터가 없으면 기본 패턴 사용
      return Row(
        mainAxisSize: MainAxisSize.max,
        children: List.generate(30, (i) {
          final h = (i % 5 + 4) * 3.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.2),
            child: Container(
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      );
    }

    // 실제 waveformData 사용
    const maxBars = 30; // 최대 막대 수
    const minHeight = 4.0;
    const maxHeight = 20.0;

    // 데이터 샘플링 (너무 많으면 일정 간격으로 추출)
    final sampledData = _sampleWaveformData(waveformData, maxBars);

    return Row(
      mainAxisSize: MainAxisSize.max,
      children:
          sampledData.asMap().entries.map((entry) {
            final value = entry.value;
            // 0~1 범위의 값을 minHeight~maxHeight로 매핑
            final barHeight = minHeight + (value * (maxHeight - minHeight));

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.2),
              child: Container(
                width: 3,
                height: barHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }).toList(),
    );
  }

  /// waveformData를 지정된 수만큼 샘플링
  List<double> _sampleWaveformData(List<double> data, int targetCount) {
    if (data.length <= targetCount) {
      return data; // 이미 적거나 같으면 그대로 반환
    }

    final step = data.length / targetCount;
    final sampled = <double>[];

    for (int i = 0; i < targetCount; i++) {
      final index = (i * step).floor();
      if (index < data.length) {
        // 절댓값 사용하여 양수로 변환 (음성 데이터는 음수도 포함)
        sampled.add(data[index].abs().clamp(0.0, 1.0));
      }
    }

    return sampled;
  }
}

/// 사용자 이름 표시 위젯 - AuthController의 getUserInfo를 통해 실제 name 필드 조회
class _UserDisplayName extends StatelessWidget {
  final String userId;
  const _UserDisplayName({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        return FutureBuilder<String>(
          future: _getUserDisplayId(authController, userId),
          builder: (context, snapshot) {
            final displayName = snapshot.data ?? userId; // fallback to userId
            return Text(
              displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard',
              ),
            );
          },
        );
      },
    );
  }

  /// AuthController를 통해 실제 사용자 name 조회
  Future<String> _getUserDisplayId(
    AuthController authController,
    String userId,
  ) async {
    try {
      final userInfo = await authController.getUserInfo(userId);
      if (userInfo != null && userInfo.name.isNotEmpty) {
        return userInfo.id;
      }

      return userId; // 최종 fallback
    } catch (e) {
      return userId; // 에러 시 userId 그대로 반환
    }
  }
}
