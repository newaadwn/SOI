import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../controllers/auth_controller.dart';
import '../../../models/photo_data_model.dart';

class UserProfileAvatar extends StatelessWidget {
  final PhotoDataModel photo;
  final Map<String, String> userProfileImages;
  final Map<String, bool> profileLoadingStates;
  final double? size;
  final double borderWidth;
  final Color borderColor;
  final bool showBorder;

  const UserProfileAvatar({
    super.key,
    required this.photo,
    required this.userProfileImages,
    required this.profileLoadingStates,
    this.size,
    this.borderWidth = 2.0,
    this.borderColor = Colors.white,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final userId = photo.userID;
    final screenWidth = MediaQuery.of(context).size.width;
    final profileSize = size ?? screenWidth * 0.085;

    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final isLoading = profileLoadingStates[userId] ?? false;
        final profileImageUrl = userProfileImages[userId] ?? '';

        return Container(
          width: profileSize,
          height: profileSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                showBorder
                    ? Border.all(color: borderColor, width: borderWidth)
                    : null,
          ),
          child:
              isLoading
                  ? CircleAvatar(
                    radius: profileSize / 2 - (showBorder ? borderWidth : 0),
                    backgroundColor: Colors.grey[700],
                    child: SizedBox(
                      width: profileSize * 0.4,
                      height: profileSize * 0.4,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                  : ClipOval(
                    child:
                        profileImageUrl.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: profileImageUrl,
                              width:
                                  profileSize -
                                  (showBorder ? borderWidth * 2 : 0),
                              height:
                                  profileSize -
                                  (showBorder ? borderWidth * 2 : 0),
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) =>
                                      _buildPlaceholder(profileSize),
                              errorWidget:
                                  (context, url, error) =>
                                      _buildPlaceholder(profileSize),
                            )
                            : _buildPlaceholder(profileSize),
                  ),
        );
      },
    );
  }

  /// 플레이스홀더 아바타 빌드
  Widget _buildPlaceholder(double profileSize) {
    return Container(
      width: profileSize - (showBorder ? borderWidth * 2 : 0),
      height: profileSize - (showBorder ? borderWidth * 2 : 0),
      color: Colors.grey[700],
      child: Icon(Icons.person, color: Colors.white, size: profileSize * 0.4),
    );
  }
}
