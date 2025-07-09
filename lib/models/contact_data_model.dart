import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// 연락처 데이터 모델 (순수 데이터 클래스)
class ContactDataModel {
  final String id;
  final String displayName;
  final String phoneNumber;
  final String? email;
  final List<String> phoneNumbers;
  final List<String> emails;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ContactStatus status;
  final String? thumbnailUrl;
  final bool isFavorite;
  final String? notes;
  final Map<String, dynamic>? metadata;
  final ContactType type;
  final String? organization;
  final String? jobTitle;

  ContactDataModel({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.email,
    this.phoneNumbers = const [],
    this.emails = const [],
    required this.createdAt,
    this.updatedAt,
    this.status = ContactStatus.active,
    this.thumbnailUrl,
    this.isFavorite = false,
    this.notes,
    this.metadata,
    this.type = ContactType.friend,
    this.organization,
    this.jobTitle,
  });

  // Firestore에서 데이터를 가져올 때 사용
  factory ContactDataModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ContactDataModel(
      id: id,
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'],
      phoneNumbers: (data['phoneNumbers'] as List?)?.cast<String>() ?? [],
      emails: (data['emails'] as List?)?.cast<String>() ?? [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      status: ContactStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ContactStatus.active,
      ),
      thumbnailUrl: data['thumbnailUrl'],
      isFavorite: data['isFavorite'] ?? false,
      notes: data['notes'],
      metadata:
          data['metadata'] != null
              ? Map<String, dynamic>.from(data['metadata'])
              : null,
      type: ContactType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ContactType.friend,
      ),
      organization: data['organization'],
      jobTitle: data['jobTitle'],
    );
  }

  // Flutter Contact에서 생성
  factory ContactDataModel.fromFlutterContact(
    Contact contact, {
    String? userId,
  }) {
    // 기본 전화번호
    String mainPhone = '';
    List<String> allPhones = [];

    if (contact.phones.isNotEmpty) {
      mainPhone = contact.phones.first.number;
      allPhones = contact.phones.map((phone) => phone.number).toList();
    }

    // 이메일 정보
    String? mainEmail;
    List<String> allEmails = [];

    if (contact.emails.isNotEmpty) {
      mainEmail = contact.emails.first.address;
      allEmails = contact.emails.map((email) => email.address).toList();
    }

    return ContactDataModel(
      id: '', // Firestore에서 자동 생성
      displayName:
          contact.displayName.isNotEmpty ? contact.displayName : '이름 없음',
      phoneNumber: mainPhone,
      email: mainEmail,
      phoneNumbers: allPhones,
      emails: allEmails,
      createdAt: DateTime.now(),
      organization:
          contact.organizations.isNotEmpty
              ? contact.organizations.first.company
              : null,
      jobTitle:
          contact.organizations.isNotEmpty
              ? contact.organizations.first.title
              : null,
    );
  }

  // 기존 ContactModel과의 호환성을 위한 factory
  factory ContactDataModel.fromContactModel(
    Map<String, dynamic> data,
    String? documentId,
  ) {
    return ContactDataModel(
      id: documentId ?? '',
      displayName: data['displayName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'],
      phoneNumbers: List<String>.from(data['phoneNumbers'] ?? []),
      emails: List<String>.from(data['emails'] ?? []),
      createdAt:
          data['createdAt'] != null
              ? DateTime.parse(data['createdAt'])
              : DateTime.now(),
      thumbnailUrl: data['thumbnailUrl'],
    );
  }

  // Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'email': email,
      'phoneNumbers': phoneNumbers,
      'emails': emails,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'status': status.name,
      'thumbnailUrl': thumbnailUrl,
      'isFavorite': isFavorite,
      'notes': notes,
      'metadata': metadata,
      'type': type.name,
      'organization': organization,
      'jobTitle': jobTitle,
    };
  }

  // 기존 ContactModel 호환을 위한 toMap
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'email': email,
      'phoneNumbers': phoneNumbers,
      'emails': emails,
      'createdAt': createdAt.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
    };
  }

  // 복사본 생성 (일부 필드 업데이트용)
  ContactDataModel copyWith({
    String? id,
    String? displayName,
    String? phoneNumber,
    String? email,
    List<String>? phoneNumbers,
    List<String>? emails,
    DateTime? createdAt,
    DateTime? updatedAt,
    ContactStatus? status,
    String? thumbnailUrl,
    bool? isFavorite,
    String? notes,
    Map<String, dynamic>? metadata,
    ContactType? type,
    String? organization,
    String? jobTitle,
  }) {
    return ContactDataModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      phoneNumbers: phoneNumbers ?? this.phoneNumbers,
      emails: emails ?? this.emails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      type: type ?? this.type,
      organization: organization ?? this.organization,
      jobTitle: jobTitle ?? this.jobTitle,
    );
  }

  // 검색용 키워드 생성
  List<String> get searchKeywords {
    List<String> keywords = [];
    keywords.addAll(displayName.toLowerCase().split(' '));
    keywords.addAll(
      phoneNumbers.map((phone) => phone.replaceAll(RegExp(r'[^\d]'), '')),
    );
    if (email != null) {
      keywords.add(email!.toLowerCase());
    }
    keywords.addAll(emails.map((email) => email.toLowerCase()));
    if (organization != null) {
      keywords.addAll(organization!.toLowerCase().split(' '));
    }
    return keywords.where((keyword) => keyword.isNotEmpty).toList();
  }

  // 이니셜 가져오기
  String get initials {
    if (displayName.isEmpty) return '?';

    List<String> nameParts = displayName.split(' ');
    if (nameParts.length > 1) {
      return nameParts[0][0] + nameParts[1][0];
    } else {
      return displayName[0];
    }
  }

  // 전화번호 포맷팅
  String get formattedPhoneNumber {
    if (phoneNumber.isEmpty) return '번호 없음';

    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 11 && cleaned.startsWith('010')) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    }
    return phoneNumber;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactDataModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ContactDataModel{id: $id, displayName: $displayName, phoneNumber: $phoneNumber}';
  }
}

/// 연락처 상태 열거형
enum ContactStatus {
  active, // 활성 상태
  archived, // 아카이브됨
  blocked, // 차단됨
  deleted, // 삭제됨
}

/// 연락처 타입 열거형
enum ContactType {
  friend, // 친구
  family, // 가족
  work, // 직장
  emergency, // 비상연락처
  other, // 기타
}

/// 연락처 검색 필터
class ContactSearchFilter {
  final String? query;
  final ContactType? type;
  final ContactStatus? status;
  final bool? isFavorite;
  final DateTime? startDate;
  final DateTime? endDate;

  ContactSearchFilter({
    this.query,
    this.type,
    this.status,
    this.isFavorite,
    this.startDate,
    this.endDate,
  });
}

/// 연락처 동기화 결과
class ContactSyncResult {
  final bool isSuccess;
  final int addedCount;
  final int updatedCount;
  final int errorCount;
  final String? error;
  final List<String> errors;

  ContactSyncResult({
    required this.isSuccess,
    this.addedCount = 0,
    this.updatedCount = 0,
    this.errorCount = 0,
    this.error,
    this.errors = const [],
  });

  factory ContactSyncResult.success({
    int addedCount = 0,
    int updatedCount = 0,
  }) {
    return ContactSyncResult(
      isSuccess: true,
      addedCount: addedCount,
      updatedCount: updatedCount,
    );
  }

  factory ContactSyncResult.failure(String error) {
    return ContactSyncResult(isSuccess: false, error: error);
  }
}
