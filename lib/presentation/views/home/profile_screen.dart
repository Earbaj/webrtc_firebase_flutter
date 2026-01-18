import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/themes/colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../../router/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      // appBar: AppBar(
      //   title: Text(
      //     'Profile',
      //     style: TextStyles.h2,
      //   ),
      //   actions: [
      //     IconButton(
      //       onPressed: () {
      //         // TODO: Implement profile edit
      //       },
      //       icon: const Icon(Icons.edit),
      //     ),
      //   ],
      // ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.surfaceLight,
                    child: currentUser.profileImage != null
                        ? ClipOval(
                      child: Image.network(
                        currentUser.profileImage!,
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Icon(
                      Icons.person,
                      size: 60,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    currentUser.displayName,
                    style: TextStyles.h2,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    currentUser.email,
                    style: TextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: currentUser.isOnline
                          ? AppColors.statusOnline.withOpacity(0.1)
                          : AppColors.statusOffline.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: currentUser.isOnline
                            ? AppColors.statusOnline
                            : AppColors.statusOffline,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: currentUser.isOnline
                                ? AppColors.statusOnline
                                : AppColors.statusOffline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          currentUser.isOnline ? 'Online' : 'Offline',
                          style: TextStyles.bodyMedium.copyWith(
                            color: currentUser.isOnline
                                ? AppColors.statusOnline
                                : AppColors.statusOffline,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Profile Information
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildInfoItem(
                    icon: Icons.phone,
                    title: 'Phone Number',
                    value: currentUser.phoneNumber ?? 'Not set',
                  ),

                  _buildInfoItem(
                    icon: Icons.calendar_today,
                    title: 'Joined',
                    value: currentUser.createdAt != null
                        ? '${currentUser.createdAt!.day}/${currentUser.createdAt!.month}/${currentUser.createdAt!.year}'
                        : 'Unknown',
                  ),

                  _buildInfoItem(
                    icon: Icons.update,
                    title: 'Last Active',
                    value: '${currentUser.lastSeen.day}/${currentUser.lastSeen.month}/${currentUser.lastSeen.year} ${currentUser.lastSeen.hour}:${currentUser.lastSeen.minute}',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Actions
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildActionItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      context.push(RouteNames.settings);
                    },
                  ),

                  _buildActionItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    badgeCount: ref.watch(unreadNotificationsCountProvider),
                    onTap: () {
                      // TODO: Navigate to notifications
                    },
                  ),

                  _buildActionItem(
                    icon: Icons.privacy_tip,
                    title: 'Privacy & Security',
                    onTap: () {
                      // TODO: Navigate to privacy settings
                    },
                  ),

                  _buildActionItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    onTap: () {
                      // TODO: Navigate to help
                    },
                  ),

                  _buildActionItem(
                    icon: Icons.logout,
                    title: 'Sign Out',
                    color: AppColors.error,
                    onTap: () async {
                      final authViewModel = ref.read(authViewModelProvider);
                      final result = await authViewModel.signOut();

                      result.fold(
                            (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        },
                            (_) {
                          // Sign out successful
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyles.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    int badgeCount = 0,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (color ?? AppColors.primary).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color ?? AppColors.primary,
                  size: 20,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Text(
                  title,
                  style: TextStyles.bodyLarge,
                ),
              ),

              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: TextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}