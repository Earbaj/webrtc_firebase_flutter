import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/themes/colors.dart';
import '../../../domain/entities/user_entity.dart';

class UserAvatar extends StatelessWidget {
  final UserEntity user;
  final double size;
  final bool showStatus;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.user,
    this.size = 40,
    this.showStatus = true,
    this.onTap,
  });

  Color _getStatusColor() {
    if (!user.isOnline) return AppColors.statusOffline;
    if (user.isBusy) return AppColors.statusBusy;
    return AppColors.statusOnline;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.borderLight,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: user.profileImage != null && user.profileImage!.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: user.profileImage!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceLight,
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: size * 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surfaceLight,
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: size * 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
                  : Container(
                color: AppColors.surfaceLight,
                child: Center(
                  child: Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (showStatus)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.background,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}