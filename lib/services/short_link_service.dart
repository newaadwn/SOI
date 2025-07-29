import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for creating and managing short links
class ShortLinkService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Create a short link for friend invitation
  ///
  /// Returns a short URL that can be shared via messaging apps
  /// The short URL will redirect to a personalized invite page
  Future<String> createInviteLink({
    required String userId,
    String? userDisplayName,
    String? socialTitle,
    String? socialDesc,
    String? socialImg,
    String? lang,
    String? platform,
    bool generateCustomImage =
        true, // New parameter for custom image generation
  }) async {
    try {
      // Get current user info
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Generate custom image if requested and no socialImg provided
      String? finalSocialImg = socialImg;
      if (generateCustomImage && socialImg == null) {
        try {
          final imageResult = await _generateCustomImage(
            userId: currentUser.uid,
            userDisplayName: userDisplayName ?? currentUser.displayName,
          );
          finalSocialImg = imageResult;
        } catch (e) {
          print('Failed to generate custom image: $e');
          // Fall back to default logo
          finalSocialImg = 'https://soi-sns.web.app/SOI_logo.png';
        }
      }

      // Build the full invite URL with rich preview parameters
      final Map<String, String> queryParams = {};

      if (socialTitle != null) queryParams['social_title'] = socialTitle;
      if (socialDesc != null) queryParams['social_desc'] = socialDesc;
      if (finalSocialImg != null) queryParams['social_img'] = finalSocialImg;
      if (lang != null) queryParams['lang'] = lang;
      if (platform != null) queryParams['type'] = platform;

      final queryString = queryParams.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');

      final longUrl =
          'https://soi-sns.web.app/invites/$userId${queryString.isNotEmpty ? '?$queryString' : ''}';

      // Call Cloud Function to create short link
      final callable = _functions.httpsCallable('createShortLink');
      final result = await callable.call({
        'longUrl': longUrl,
        'userId': currentUser.uid,
        'userDisplayName':
            userDisplayName ?? currentUser.displayName ?? 'SOI User',
        'generateCustomImage': false, // We already generated it above
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        return data['shortUrl'] as String;
      } else {
        throw Exception('Failed to create short link');
      }
    } catch (e) {
      throw Exception('Error creating invite link: $e');
    }
  }

  /// Generate a custom invite image
  ///
  /// Creates a personalized image with user profile and SOI branding
  Future<String> _generateCustomImage({
    required String userId,
    String? userDisplayName,
    String? customMessage,
  }) async {
    final callable = _functions.httpsCallable('generateInviteImage');
    final result = await callable.call({
      'userId': userId,
      'userDisplayName': userDisplayName,
      'customMessage': customMessage,
    });

    final data = result.data as Map<String, dynamic>;

    if (data['success'] == true) {
      return data['imageUrl'] as String;
    } else {
      throw Exception('Failed to generate custom image');
    }
  }

  /// Generate a custom invite image (public method for testing)
  ///
  /// This can be used to preview how the generated image looks
  Future<String> generatePreviewImage({String? customMessage}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    return _generateCustomImage(
      userId: currentUser.uid,
      userDisplayName: currentUser.displayName,
      customMessage: customMessage,
    );
  }

  /// Create a personalized invite link for a specific platform
  ///
  /// This mimics Locket Camera's approach with platform-specific optimization
  Future<String> createPlatformSpecificInviteLink({
    required String platform, // 'KakaoTalk', 'Line', 'Telegram', etc.
    String? customMessage,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    final userName = currentUser.displayName ?? 'SOI 친구';

    // Platform-specific messages and settings
    String socialTitle;
    String socialDesc;
    String lang = 'ko';

    switch (platform.toLowerCase()) {
      case 'kakaotalk':
        socialTitle = '$userName님이 SOI에 초대했어요 💛';
        socialDesc = customMessage ?? 'SOI에서 함께 소통해요!';
        break;
      case 'line':
        socialTitle = 'Add me on SOI 💛';
        socialDesc = customMessage ?? 'Let\'s connect on SOI!';
        lang = 'en';
        break;
      case 'telegram':
        socialTitle = 'Join me on SOI';
        socialDesc = customMessage ?? 'Connect with me on SOI app';
        lang = 'en';
        break;
      default:
        socialTitle = 'Join SOI';
        socialDesc = customMessage ?? 'Connect with friends on SOI';
    }

    return createInviteLink(
      userId: currentUser.uid,
      userDisplayName: userName,
      socialTitle: socialTitle,
      socialDesc: socialDesc,
      socialImg: 'https://soi-sns.web.app/SOI_logo.png', // Default logo
      lang: lang,
      platform: platform,
    );
  }

  /// Generate a Locket Camera style invite message with short link
  ///
  /// Returns both the message text and short URL
  Future<Map<String, String>> generateInviteMessage({
    String? customMessage,
    String platform = 'default',
  }) async {
    final shortUrl = await createPlatformSpecificInviteLink(
      platform: platform,
      customMessage: customMessage,
    );

    // Create a message similar to Locket Camera's style
    final message = customMessage ?? 'SOI에서 함께해요!';

    return {
      'message': message,
      'url': shortUrl,
      'fullText': '$message $shortUrl',
    };
  }
}
