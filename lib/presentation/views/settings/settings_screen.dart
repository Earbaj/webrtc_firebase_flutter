import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/themes/colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _videoQuality = 'Auto';
  bool _lowDataMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyles.h2,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Settings
            Text(
              'Account',
              style: TextStyles.h3,
            ),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.person,
                    title: 'Edit Profile',
                    onTap: () {
                      // TODO: Implement edit profile
                    },
                  ),

                  _buildSettingsItem(
                    icon: Icons.security,
                    title: 'Privacy & Security',
                    onTap: () {
                      // TODO: Implement privacy settings
                    },
                  ),

                  _buildSettingsItem(
                    icon: Icons.language,
                    title: 'Language',
                    trailing: Text(
                      'English',
                      style: TextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      // TODO: Implement language selection
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Call Settings
            Text(
              'Call Settings',
              style: TextStyles.h3,
            ),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.video_settings,
                    title: 'Video Quality',
                    trailing: DropdownButton<String>(
                      value: _videoQuality,
                      onChanged: (value) {
                        setState(() {
                          _videoQuality = value!;
                        });
                      },
                      items: ['Auto', 'High', 'Medium', 'Low']
                          .map((quality) => DropdownMenuItem(
                        value: quality,
                        child: Text(quality),
                      ))
                          .toList(),
                      underline: Container(),
                      icon: const Icon(Icons.arrow_drop_down),
                    ), onTap: () {  },
                  ),

                  _buildSwitchItem(
                    icon: Icons.data_saver_off,
                    title: 'Low Data Mode',
                    value: _lowDataMode,
                    onChanged: (value) {
                      setState(() {
                        _lowDataMode = value;
                      });
                    },
                  ),

                  _buildSettingsItem(
                    icon: Icons.mic,
                    title: 'Microphone Settings',
                    onTap: () {
                      // TODO: Implement microphone settings
                    },
                  ),

                  _buildSettingsItem(
                    icon: Icons.speaker,
                    title: 'Speaker Settings',
                    onTap: () {
                      // TODO: Implement speaker settings
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Notification Settings
            Text(
              'Notifications',
              style: TextStyles.h3,
            ),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSwitchItem(
                    icon: Icons.notifications,
                    title: 'Enable Notifications',
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),

                  _buildSwitchItem(
                    icon: Icons.volume_up,
                    title: 'Sound',
                    value: _soundEnabled,
                    onChanged: (value) {
                      setState(() {
                        _soundEnabled = value;
                      });
                    },
                  ),

                  _buildSwitchItem(
                    icon: Icons.vibration,
                    title: 'Vibration',
                    value: _vibrationEnabled,
                    onChanged: (value) {
                      setState(() {
                        _vibrationEnabled = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // App Settings
            Text(
              'App Settings',
              style: TextStyles.h3,
            ),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingsItem(
                    icon: Icons.storage,
                    title: 'Storage Usage',
                    onTap: () {
                      // TODO: Implement storage settings
                    },
                  ),

                  _buildSettingsItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    onTap: () {
                      // TODO: Implement help center
                    },
                  ),

                  _buildSettingsItem(
                    icon: Icons.info,
                    title: 'About',
                    onTap: () {
                      // TODO: Implement about screen
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Sign Out Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error.withOpacity(0.1),
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Sign Out'),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    Widget? trailing,
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
                child: Text(
                  title,
                  style: TextStyles.bodyLarge,
                ),
              ),

              if (trailing != null) trailing,

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
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
            child: Text(
              title,
              style: TextStyles.bodyLarge,
            ),
          ),

          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}