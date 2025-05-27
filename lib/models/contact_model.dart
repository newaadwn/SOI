import 'package:contacts_service/contacts_service.dart';

/// 연락처 정보를 저장하기 위한 모델 클래스
class ContactModel {
  final String? id;
  final String displayName;
  final String phoneNumber;
  final String? email;
  final List<String> phoneNumbers;
  final List<String> emails;
  final DateTime? createdAt;
  final String? thumbnailUrl;

  ContactModel({
    this.id,
    required this.displayName,
    required this.phoneNumber,
    this.email,
    this.phoneNumbers = const [],
    this.emails = const [],
    this.createdAt,
    this.thumbnailUrl,
  });

  /// Contact 객체로부터 ContactModel 객체 생성
  factory ContactModel.fromContact(Contact contact) {
    // 기본 전화번호
    String mainPhone = '';
    List<String> allPhones = [];

    if (contact.phones != null && contact.phones!.isNotEmpty) {
      mainPhone = contact.phones!.first.value ?? '';

      for (var phone in contact.phones!) {
        if (phone.value != null && phone.value!.isNotEmpty) {
          allPhones.add(phone.value!);
        }
      }
    }

    // 이메일 정보
    String? mainEmail;
    List<String> allEmails = [];

    if (contact.emails != null && contact.emails!.isNotEmpty) {
      mainEmail = contact.emails!.first.value;

      for (var email in contact.emails!) {
        if (email.value != null && email.value!.isNotEmpty) {
          allEmails.add(email.value!);
        }
      }
    }

    return ContactModel(
      displayName: contact.displayName ?? '이름 없음',
      phoneNumber: mainPhone,
      email: mainEmail,
      phoneNumbers: allPhones,
      emails: allEmails,
      createdAt: DateTime.now(),
    );
  }

  /// Map 객체로 변환 (Firebase 저장용)
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'email': email,
      'phoneNumbers': phoneNumbers,
      'emails': emails,
      'createdAt': createdAt?.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
    };
  }

  /// Map 객체로부터 ContactModel 객체 생성 (Firebase에서 불러올 때)
  factory ContactModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ContactModel(
      id: documentId,
      displayName: map['displayName'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'],
      phoneNumbers: List<String>.from(map['phoneNumbers'] ?? []),
      emails: List<String>.from(map['emails'] ?? []),
      createdAt:
          map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      thumbnailUrl: map['thumbnailUrl'],
    );
  }
}
