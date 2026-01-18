import 'package:flutter/material.dart';
import 'package:webrtc_flutter/presentation/widgets/user/user_avatar.dart';

import '../../../core/themes/colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../domain/entities/user_entity.dart';

class UserListTile extends StatelessWidget {
  final UserEntity user;
  final VoidCallback? onTap;
  final VoidCallback? onVideoCall;
  final VoidCallback? onAudioCall;
  final bool showCallButtons;
  final bool isSelected;
  final bool showLastSeen;

  const UserListTile({
    super.key,
    required this.user,
    this.onTap,
    this.onVideoCall,
    this.onAudioCall,
    this.showCallButtons = true,
    this.isSelected = false,
    this.showLastSeen = true,
  });

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.surfaceLight : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: AppColors.primary, width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with status
                UserAvatar(
                  user: user,
                  size: 56,
                  showStatus: true,
                ),

                const SizedBox(width: 16),

                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyles.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      Text(
                        user.email,
                        style: TextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (showLastSeen && !user.isOnline) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Last seen ${_formatLastSeen(user.lastSeen)}',
                          style: TextStyles.caption,
                        ),
                      ],

                      if (user.isBusy) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.statusBusy,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'In a call',
                              style: TextStyles.caption.copyWith(
                                color: AppColors.statusBusy,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Call buttons
                if (showCallButtons && !user.isBusy) ...[
                  IconButton(
                    onPressed: onAudioCall,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.call,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton(
                    onPressed: onVideoCall,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],

                if (showCallButtons && user.isBusy) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusBusy.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Busy',
                      style: TextStyles.caption.copyWith(
                        color: AppColors.statusBusy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}