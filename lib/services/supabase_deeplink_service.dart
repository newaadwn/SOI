import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/photo_data_model.dart';
import '../models/category_data_model.dart';
import '../models/user_search_model.dart';

/// Supabase 딥링크 서비스
/// Firebase 기존 구조와 함께 사용하는 딥링크 전용 서비스
class SupabaseDeeplinkService {
  static const supabaseUrl = 'https://bobyanticgtadhimszzi.supabase.co';
  static const supabaseKey = String.fromEnvironment(
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJvYnlhbnRpY2d0YWRoaW1zenppIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjY4OTczMSwiZXhwIjoyMDcyMjY1NzMxfQ.OX6W_GY2ZFE5z9HMrB9Xf1-MCAsJuWBHUh_EFw6JSIM',
  );

  /// 사진 공유 링크 생성
  static Future<String?> createPhotoShareLink({
    required PhotoDataModel photo,
    required String categoryName,
    String? userDisplayName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/handle-deeplink'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
          'apikey': supabaseKey,
        },
        body: jsonEncode({
          'type': 'photo',
          'targetId': photo.id,
          'metadata': {
            'title': 'SOI 사진 - $categoryName',
            'description': 'SOI에서 공유된 소중한 순간 ✨',
            'image_url': photo.imageUrl,
            'photo_id': photo.id,
            'category_id': photo.categoryId,
            'category_name': categoryName,
            'audio_url': photo.audioUrl,
            'user_id': photo.userID,
            'user_name': userDisplayName ?? '사용자',
            'created_at': photo.createdAt.toIso8601String(),
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final shareUrl = data['url'] as String;
        debugPrint('✅ Photo share link created: $shareUrl');
        return shareUrl;
      } else {
        debugPrint(
          '❌ Failed to create photo share link: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ Photo share link error: $e');
      return null;
    }
  }

  /// 카테고리(앨범) 공유 링크 생성
  static Future<String?> createCategoryShareLink({
    required CategoryDataModel category,
    required String userId,
    required int photoCount,
    String? representativeImageUrl,
  }) async {
    try {
      final displayName = category.getDisplayName(userId);

      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/handle-deeplink'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
          'apikey': supabaseKey,
        },
        body: jsonEncode({
          'type': 'category',
          'targetId': category.id,
          'metadata': {
            'title': '$displayName 앨범 - SOI',
            'description': '$photoCount장의 추억이 담긴 특별한 앨범',
            'image_url': representativeImageUrl ?? '',
            'category_id': category.id,
            'category_name': category.name,
            'display_name': displayName,
            'photo_count': photoCount,
            'user_id': userId,
            'representative_image': representativeImageUrl,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final shareUrl = data['url'] as String;
        debugPrint('✅ Category share link created: $shareUrl');
        return shareUrl;
      } else {
        debugPrint(
          '❌ Failed to create category share link: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ Category share link error: $e');
      return null;
    }
  }

  /// 프로필 공유 링크 생성
  static Future<String?> createProfileShareLink({
    required UserSearchModel user,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/handle-deeplink'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
          'apikey': supabaseKey,
        },
        body: jsonEncode({
          'type': 'profile',
          'targetId': user.uid,
          'metadata': {
            'title': '${user.name}님의 SOI 프로필',
            'description': 'SOI에서 ${user.name}님과 함께해요! 🌟',
            'image_url': user.profileImageUrl ?? '',
            'user_id': user.uid,
            'user_name': user.name,
            'user_id_display': user.id,
            'profile_image': user.profileImageUrl,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final shareUrl = data['url'] as String;
        debugPrint('✅ Profile share link created: $shareUrl');
        return shareUrl;
      } else {
        debugPrint(
          '❌ Failed to create profile share link: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('❌ Profile share link error: $e');
      return null;
    }
  }

  /// 친구 초대 링크 생성
  static Future<String?> createFriendInviteLink({
    required String inviterName,
    required String inviterId,
    required String inviteeName,
    String? inviterProfileImage,
  }) async {
    try {
      debugPrint('🔗 Creating friend invite link...');
      debugPrint('- Inviter: $inviterName ($inviterId)');
      debugPrint('- Invitee: $inviteeName');
      debugPrint('- URL: $supabaseUrl/functions/v1/handle-deeplink');

      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/handle-deeplink'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
          'apikey': supabaseKey,
        },
        body: jsonEncode({
          'type': 'friend_invite',
          'targetId': inviterId,
          'metadata': {
            'title': 'SOI 친구 초대',
            'description': '$inviterName님이 SOI에서 친구가 되고 싶어해요!',
            'image_url':
                inviterProfileImage ??
                'https://soi-sns.web.app/assets/SOI_logo.png',
            'inviter_name': inviterName,
            'inviter_id': inviterId,
            'invitee_name': inviteeName,
            'inviter_profile_image': inviterProfileImage,
          },
        }),
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final shareUrl = data['url'] as String;
        debugPrint('✅ Friend invite link created: $shareUrl');
        return shareUrl;
      } else {
        debugPrint(
          '❌ Failed to create friend invite link: ${response.statusCode}',
        );
        debugPrint('❌ Response: ${response.body}');
        return null; // 폴백 없이 null 반환
      }
    } catch (e) {
      debugPrint('❌ Friend invite link error: $e');
      return null; // 폴백 없이 null 반환
    }
  }

  /// 딥링크 데이터 조회 (앱에서 링크 클릭 시 호출)
  static Future<Map<String, dynamic>?> resolveDeepLink(String linkId) async {
    try {
      final response = await http.get(
        Uri.parse('$supabaseUrl/functions/v1/handle-deeplink'),
        headers: {
          'Authorization': 'Bearer $supabaseKey',
          'apikey': supabaseKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Deep link resolved: $data');
        return data;
      } else {
        debugPrint('❌ Failed to resolve deep link: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Deep link resolve error: $e');
      return null;
    }
  }

  /// 링크 클릭 추적
  static Future<void> trackLinkClick(String linkId) async {
    try {
      await http.post(
        Uri.parse('$supabaseUrl/functions/v1/track-click'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseKey',
        },
        body: jsonEncode({
          'link_id': linkId,
          'clicked_at': DateTime.now().toIso8601String(),
        }),
      );
      debugPrint('✅ Link click tracked: $linkId');
    } catch (e) {
      debugPrint('❌ Track click error: $e');
    }
  }
}
