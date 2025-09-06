import 'package:flutter/material.dart';

/// 음성 댓글 프로필 이미지 위치를 절대 좌표와 상대 좌표 간 변환하는 유틸리티
class PositionConverter {
  /// 절대 좌표를 상대 좌표(0.0 ~ 1.0)로 변환
  ///
  /// [absolutePosition]: 절대 좌표 (픽셀 단위)
  /// [containerSize]: 컨테이너(이미지) 크기
  ///
  /// Returns: 상대 좌표 (0.0 ~ 1.0 범위)
  static Offset toRelativePosition(
    Offset absolutePosition,
    Size containerSize,
  ) {
    if (containerSize.width == 0 || containerSize.height == 0) {
      return Offset.zero;
    }

    return Offset(
      (absolutePosition.dx / containerSize.width).clamp(0.0, 1.0),
      (absolutePosition.dy / containerSize.height).clamp(0.0, 1.0),
    );
  }

  /// 상대 좌표를 절대 좌표(픽셀 단위)로 변환
  ///
  /// [relativePosition]: 상대 좌표 (0.0 ~ 1.0 범위)
  /// [containerSize]: 컨테이너(이미지) 크기
  ///
  /// Returns: 절대 좌표 (픽셀 단위)
  static Offset toAbsolutePosition(
    Offset relativePosition,
    Size containerSize,
  ) {
    return Offset(
      relativePosition.dx * containerSize.width,
      relativePosition.dy * containerSize.height,
    );
  }

  /// Map 형태로 상대 좌표 저장
  ///
  /// [relativePosition]: 상대 좌표
  ///
  /// Returns: Firestore에 저장할 Map 형태
  static Map<String, double> relativePositionToMap(Offset relativePosition) {
    return {'x': relativePosition.dx, 'y': relativePosition.dy};
  }

  /// Map에서 상대 좌표 복원
  ///
  /// [positionMap]: Firestore에서 읽어온 Map 데이터
  ///
  /// Returns: 상대 좌표 Offset
  static Offset mapToRelativePosition(Map<String, dynamic>? positionMap) {
    if (positionMap == null) return Offset.zero;

    final x = (positionMap['x'] as num?)?.toDouble() ?? 0.0;
    final y = (positionMap['y'] as num?)?.toDouble() ?? 0.0;

    return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

  /// 프로필 이미지가 화면을 벗어나지 않도록 위치 조정
  ///
  /// [position]: 조정할 위치
  /// [containerSize]: 컨테이너 크기
  /// [profileSize]: 프로필 이미지 크기 (기본 27px)
  ///
  /// Returns: 조정된 위치
  static Offset clampPosition(
    Offset position,
    Size containerSize, {
    double profileSize = 27.0,
  }) {
    final halfProfile = profileSize / 2;

    return Offset(
      position.dx.clamp(halfProfile, containerSize.width - halfProfile),
      position.dy.clamp(halfProfile, containerSize.height - halfProfile),
    );
  }
}
