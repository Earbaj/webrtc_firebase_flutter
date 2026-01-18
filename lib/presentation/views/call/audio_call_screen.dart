import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../domain/entities/call_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/webrtc_provider.dart';
import '../../viewmodels/call_viewmodel.dart';
import '../../widgets/call/call_controls.dart';
import '../../widgets/call/call_timer.dart';
import '../../widgets/user/user_avatar.dart';

class AudioCallScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;

  const AudioCallScreen({super.key, this.extra});

  @override
  ConsumerState<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends ConsumerState<AudioCallScreen> {
  late CallEntity _call;
  late UserEntity _receiver;
  bool _isSpeakerOn = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  StreamSubscription? _callStateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCall();
    _startControlsTimer();
  }

  void _initializeCall() {
    if (widget.extra != null) {
      _call = widget.extra!['call'] as CallEntity;
      _receiver = widget.extra!['receiver'] as UserEntity;
    }
  }

  void _startControlsTimer() {
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    setState(() {
      _showControls = true;
    });
    _startControlsTimer();
  }

  Future<void> _toggleAudio() async {
    final callViewModel = ref.read(callViewModelProvider);
    await callViewModel.toggleAudioMute();
    _resetControlsTimer();
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
      // TODO: Implement speaker toggle logic
    });
    _resetControlsTimer();
  }

  void _showChat() {
    // TODO: Implement chat during call
    _resetControlsTimer();
  }

  Future<void> _endCall() async {
    final callViewModel = ref.read(callViewModelProvider);
    final result = await callViewModel.endCall();

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
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _callStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callViewModel = ref.watch(callViewModelProvider);
    final callState = callViewModel.callState;
    final isAudioMuted = callViewModel.isAudioMuted;
    final callDuration = ref.watch(callDurationProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: GestureDetector(
          onTap: _resetControlsTimer,
          child: Stack(
            children: [
              // Background with gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.background,
                    ],
                  ),
                ),
              ),

              // Main Content
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // User Avatar
                    UserAvatar(
                      user: _receiver,
                      size: 120,
                      showStatus: false,
                    ),

                    const SizedBox(height: 32),

                    // User Name
                    Text(
                      _receiver.displayName,
                      style: TextStyles.h2,
                    ),

                    const SizedBox(height: 8),

                    // Call Status
                    if (callState == CallState.connected)
                      callDuration.when(
                        data: (duration) => CallTimer(
                          duration: duration,
                          status: 'Connected',
                        ),
                        loading: () => Text(
                          '00:00',
                          style: TextStyles.bodyMedium,
                        ),
                        error: (error, _) => Text(
                          'Error',
                          style: TextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      )
                    else
                      Text(
                        _getStatusText(callState),
                        style: TextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),

                    const SizedBox(height: 48),

                    // Audio Wave Animation (placeholder)
                    if (callState == CallState.connected)
                      _buildAudioWaveAnimation(),

                    // Connection Status
                    if (callState == CallState.ringing ||
                        callState == CallState.connecting)
                      _buildConnectionStatus(callState),
                  ],
                ),
              ),

              // Top Bar
              if (_showControls)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: _buildTopBar(callState),
                ),

              // Call Controls
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildCallControls(
                    isAudioMuted: isAudioMuted,
                    callState: callState,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioWaveAnimation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
            (index) => Container(
          width: 6,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(CallState callState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: _endCall,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),

          const Spacer(),

          // Network indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallControls({
    required bool isAudioMuted,
    required CallState callState,
  }) {
    if (callState == CallState.ringing || callState == CallState.connecting) {
      return _buildIncomingCallControls();
    }

    return CallControls(
      isVideoCall: false,
      onEndCall: _endCall,
      onToggleAudio: _toggleAudio,
      onToggleSpeaker: _toggleSpeaker,
      onShowChat: _showChat,
      isAudioMuted: isAudioMuted,
      isSpeakerOn: _isSpeakerOn,
    );
  }

  Widget _buildIncomingCallControls() {
    final callViewModel = ref.read(callViewModelProvider);

    return IncomingCallControls(
      isVideoCall: false,
      onAccept: () async {
        final result = await callViewModel.acceptCall();
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
            // Call accepted
          },
        );
      },
      onReject: () async {
        final result = await callViewModel.rejectCall('User rejected');
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
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Widget _buildConnectionStatus(CallState callState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (callState == CallState.ringing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Ringing...',
              style: TextStyles.h3.copyWith(color: Colors.white),
            ),
          ] else if (callState == CallState.connecting) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Connecting...',
              style: TextStyles.h3.copyWith(color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusText(CallState state) {
    switch (state) {
      case CallState.ringing:
        return 'Ringing';
      case CallState.connecting:
        return 'Connecting';
      case CallState.connected:
        return 'Connected';
      case CallState.ending:
        return 'Ending';
      case CallState.ended:
        return 'Ended';
      case CallState.error:
        return 'Error';
      default:
        return '';
    }
  }
}