import 'package:cloud_firestore/cloud_firestore.dart';

/// 친구 요청 상태
enum FriendRequestStatus {
  pending, // 대기 중
  accepted, // 수락됨
  rejected, // 거절됨
  cancelled, // 취소됨
}

/// 친구 요청 타입
enum FriendRequestType {
  phone, // 전화번호 기반
  search, // ID 검색 기반
  suggestion, // 추천 기반
  invite, // 초대 링크 기반
}

/// 친구 관계 상태
enum FriendshipStatus {
  none, // 관계 없음
  requested, // 요청 보냄
  received, // 요청 받음
  friends, // 친구 관계
  blocked, // 차단됨
}

/// 친구 요청 데이터 모델
class FriendRequestModel {
  final String id;
  final String fromUserId; // 요청 보낸 사용자 ID
  final String fromUserNickname; // 요청 보낸 사용자 닉네임
  final String toUserId; // 요청 받을 사용자 ID
  final String toUserNickname; // 요청 받을 사용자 닉네임
  final FriendRequestStatus status;
  final FriendRequestType type;
  final DateTime createdAt;
  final DateTime? respondedAt; // 응답한 시간
  final String? message; // 요청 메시지 (선택적)
  final Map<String, dynamic>? metadata; // 추가 정보

  FriendRequestModel({
    required this.id,
    required this.fromUserId,
    required this.fromUserNickname,
    required this.toUserId,
    required this.toUserNickname,
    required this.status,
    required this.type,
    required this.createdAt,
    this.respondedAt,
    this.message,
    this.metadata,
  });

  /// Firestore 문서에서 모델 생성
  factory FriendRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FriendRequestModel(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      fromUserNickname: data['fromUserNickname'] ?? '',
      toUserId: data['toUserId'] ?? '',
      toUserNickname: data['toUserNickname'] ?? '',
      status: FriendRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => FriendRequestStatus.pending,
      ),
      type: FriendRequestType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => FriendRequestType.search,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
      message: data['message'],
      metadata: data['metadata'],
    );
  }

  /// Firestore 저장용 Map 변환
  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'fromUserNickname': fromUserNickname,
      'toUserId': toUserId,
      'toUserNickname': toUserNickname,
      'status': status.name,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'message': message,
      'metadata': metadata,
    };
  }

  /// 복사본 생성 (상태 업데이트용)
  FriendRequestModel copyWith({
    String? id,
    String? fromUserId,
    String? fromUserNickname,
    String? toUserId,
    String? toUserNickname,
    FriendRequestStatus? status,
    FriendRequestType? type,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? message,
    Map<String, dynamic>? metadata,
  }) {
    return FriendRequestModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUserNickname: fromUserNickname ?? this.fromUserNickname,
      toUserId: toUserId ?? this.toUserId,
      toUserNickname: toUserNickname ?? this.toUserNickname,
      status: status ?? this.status,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      message: message ?? this.message,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 요청이 만료되었는지 확인 (30일)
  bool get isExpired {
    final expiryDate = createdAt.add(const Duration(days: 30));
    return DateTime.now().isAfter(expiryDate);
  }

  /// 응답 가능한 상태인지 확인
  bool get canRespond {
    return status == FriendRequestStatus.pending && !isExpired;
  }
}

/// 친구 데이터 모델
class FriendModel {
  final String id;
  final String userId; // 친구의 사용자 ID
  final String nickname; // 친구의 닉네임
  final String? profileImageUrl; // 프로필 이미지 URL
  final DateTime becameFriendsAt; // 친구가 된 시간
  final bool isActive; // 활성 상태
  final DateTime? lastInteraction; // 마지막 상호작용 시간
  final Map<String, dynamic>? metadata; // 추가 정보

  FriendModel({
    required this.id,
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
    required this.becameFriendsAt,
    this.isActive = true,
    this.lastInteraction,
    this.metadata,
  });

  /// Firestore 문서에서 모델 생성
  factory FriendModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FriendModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      nickname: data['nickname'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      becameFriendsAt:
          (data['becameFriendsAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      lastInteraction: (data['lastInteraction'] as Timestamp?)?.toDate(),
      metadata: data['metadata'],
    );
  }

  /// Firestore 저장용 Map 변환
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'becameFriendsAt': Timestamp.fromDate(becameFriendsAt),
      'isActive': isActive,
      'lastInteraction':
          lastInteraction != null ? Timestamp.fromDate(lastInteraction!) : null,
      'metadata': metadata,
    };
  }
}

/// 친구 요청 결과
class FriendRequestResult {
  final bool isSuccess;
  final String? error;
  final FriendRequestModel? request;
  final bool isSmsInvitation; // SMS 초대 여부
  final String? actionMessage; // 사용자에게 표시할 액션 메시지

  FriendRequestResult._({
    required this.isSuccess,
    this.error,
    this.request,
    this.isSmsInvitation = false,
    this.actionMessage,
  });

  factory FriendRequestResult.success([FriendRequestModel? request]) {
    return FriendRequestResult._(
      isSuccess: true,
      request: request,
      actionMessage: request != null ? '친구 요청을 보냈습니다.' : null,
    );
  }

  factory FriendRequestResult.failure(String error) {
    return FriendRequestResult._(isSuccess: false, error: error);
  }

  /// SMS 초대 성공 결과
  factory FriendRequestResult.smsInvitationSuccess(String phoneNumber) {
    return FriendRequestResult._(
      isSuccess: true,
      isSmsInvitation: true,
      actionMessage: '앱 설치 링크를 문자로 보냈습니다.',
    );
  }

  /// SMS 초대 실패 결과
  factory FriendRequestResult.smsInvitationFailure(String error) {
    return FriendRequestResult._(
      isSuccess: false,
      error: error,
      isSmsInvitation: true,
    );
  }
}

/// 연락처 아이템 모델 (단순한 연락처 목록 표시용)
class ContactItem {
  final String id;
  final String displayName;
  final String phoneNumber;
  final String? profileImageUrl;
  final bool hasApp; // 앱을 설치했는지 여부
  final String? appUserId; // 앱 사용자인 경우 userId

  ContactItem({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.profileImageUrl,
    this.hasApp = false,
    this.appUserId,
  });

  /// Flutter Contacts에서 ContactItem으로 변환
  factory ContactItem.fromFlutterContact(dynamic contact) {
    final String displayName =
        contact.displayName ?? contact.name?.formattedName ?? '알 수 없음';
    final String phoneNumber =
        contact.phones.isNotEmpty ? contact.phones.first.number ?? '' : '';

    return ContactItem(
      id: contact.id ?? '',
      displayName: displayName,
      phoneNumber: phoneNumber,
      profileImageUrl: contact.thumbnail != null ? 'thumbnail' : null,
    );
  }

  /// JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'hasApp': hasApp,
      'appUserId': appUserId,
    };
  }

  factory ContactItem.fromJson(Map<String, dynamic> json) {
    return ContactItem(
      id: json['id'] ?? '',
      displayName: json['displayName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      profileImageUrl: json['profileImageUrl'],
      hasApp: json['hasApp'] ?? false,
      appUserId: json['appUserId'],
    );
  }

  /// 복사본 생성
  ContactItem copyWith({
    String? id,
    String? displayName,
    String? phoneNumber,
    String? profileImageUrl,
    bool? hasApp,
    String? appUserId,
  }) {
    return ContactItem(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      hasApp: hasApp ?? this.hasApp,
      appUserId: appUserId ?? this.appUserId,
    );
  }
}
