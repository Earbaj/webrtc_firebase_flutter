import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/themes/colors.dart';
import '../../../core/themes/text_styles.dart';


class CallControls extends ConsumerWidget {
  final bool isVideoCall;
  final VoidCallback? onEndCall;
  final VoidCallback? onToggleAudio;
  final VoidCallback? onToggleVideo;
  final VoidCallback? onSwitchCamera;
  final VoidCallback? onToggleSpeaker;
  final VoidCallback? onShowChat;
  final bool isAudioMuted;
  final bool isVideoMuted;
  final bool isSpeakerOn;

  const CallControls({
    super.key,
    required this.isVideoCall,
    this.onEndCall,
    this.onToggleAudio,
    this.onToggleVideo,
    this.onSwitchCamera,
    this.onToggleSpeaker,
    this.onShowChat,
    this.isAudioMuted = false,
    this.isVideoMuted = false,
    this.isSpeakerOn = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.8),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Call duration and status (would be implemented separately)
          const SizedBox(height: 16),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Audio Mute Button
              _buildControlButton(
                icon: isAudioMuted ? Icons.mic_off : Icons.mic,
                label: isAudioMuted ? 'Unmute' : 'Mute',
                backgroundColor: isAudioMuted
                    ? AppColors.error
                    : AppColors.surfaceLight,
                iconColor: isAudioMuted ? Colors.white : AppColors.textPrimary,
                onPressed: onToggleAudio,
              ),

              // Video Mute Button (only for video calls)
              if (isVideoCall)
                _buildControlButton(
                  icon: isVideoMuted ? Icons.videocam_off : Icons.videocam,
                  label: isVideoMuted ? 'Camera On' : 'Camera Off',
                  backgroundColor: isVideoMuted
                      ? AppColors.error
                      : AppColors.surfaceLight,
                  iconColor: isVideoMuted ? Colors.white : AppColors.textPrimary,
                  onPressed: onToggleVideo,
                ),

              // Speaker Button
              _buildControlButton(
                icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                label: isSpeakerOn ? 'Speaker' : 'Earpiece',
                backgroundColor: AppColors.surfaceLight,
                iconColor: AppColors.textPrimary,
                onPressed: onToggleSpeaker,
              ),

              // Switch Camera Button (only for video calls)
              if (isVideoCall)
                _buildControlButton(
                  icon: Icons.cameraswitch,
                  label: 'Switch',
                  backgroundColor: AppColors.surfaceLight,
                  iconColor: AppColors.textPrimary,
                  onPressed: onSwitchCamera,
                ),

              // Chat Button
              _buildControlButton(
                icon: Icons.chat,
                label: 'Chat',
                backgroundColor: AppColors.surfaceLight,
                iconColor: AppColors.textPrimary,
                onPressed: onShowChat,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // End Call Button
          SizedBox(
            width: 70,
            height: 70,
            child: FloatingActionButton(
              onPressed: onEndCall,
              backgroundColor: AppColors.error,
              child: const Icon(
                Icons.call_end,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color iconColor,
    VoidCallback? onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyles.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// Incoming Call Controls
class IncomingCallControls extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool isVideoCall;

  const IncomingCallControls({
    super.key,
    required this.onAccept,
    required this.onReject,
    required this.isVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isVideoCall ? 'Incoming Video Call' : 'Incoming Audio Call',
            style: TextStyles.h3,
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Reject Button
              Column(
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: FloatingActionButton(
                      onPressed: onReject,
                      backgroundColor: AppColors.error,
                      child: const Icon(
                        Icons.call_end,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Decline',
                    style: TextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Accept Button
              Column(
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: FloatingActionButton(
                      onPressed: onAccept,
                      backgroundColor: AppColors.success,
                      child: Icon(
                        isVideoCall ? Icons.videocam : Icons.call,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isVideoCall ? 'Video' : 'Audio',
                    style: TextStyles.bodyMedium.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}