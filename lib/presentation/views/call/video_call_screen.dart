import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/themes/colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../domain/entities/call_entity.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/webrtc_provider.dart';
import '../../viewmodels/call_viewmodel.dart';
import '../../widgets/call/call_controls.dart';
import '../../widgets/call/call_timer.dart';
import '../../widgets/call/video_renderer.dart';
import '../../widgets/user/user_avatar.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;

  const VideoCallScreen({super.key, this.extra});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  late CallEntity _call;
  late UserEntity _receiver;
  bool _isExpanded = true;
  bool _isSpeakerOn = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  StreamSubscription? _callStateSubscription;
  StreamSubscription? _remoteStreamSubscription;

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

  Future<void> _setupCallListeners() async {
    final callViewModel = ref.read(callViewModelProvider);

    // Listen for call state changes
    _callStateSubscription = ref
        .watch(webRTCNotifierProvider.notifier)
        .remoteStream
        .listen((stream) {
      // Remote stream connected
    });

    // Listen for call duration
    // Duration is already provided via stream
  }

  Future<void> _toggleAudio() async {
    final callViewModel = ref.read(callViewModelProvider);
    await callViewModel.toggleAudioMute();
    _resetControlsTimer();
  }

  Future<void> _toggleVideo() async {
    final callViewModel = ref.read(callViewModelProvider);
    await callViewModel.toggleVideoMute();
    _resetControlsTimer();
  }

  Future<void> _switchCamera() async {
    final callViewModel = ref.read(callViewModelProvider);
    await callViewModel.switchCamera();
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

  Future<void> _togglePiP() async {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _resetControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _callStateSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callViewModel = ref.watch(callViewModelProvider);
    final callState = callViewModel.callState;
    final localStream = callViewModel.localStream;
    final remoteStream = callViewModel.remoteStream;
    final isAudioMuted = callViewModel.isAudioMuted;
    final isVideoMuted = callViewModel.isVideoMuted;
    final callDuration = ref.watch(callDurationProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _resetControlsTimer,
          child: Stack(
            children: [
              // Background with blur effect
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),

              // Video Views
              Positioned.fill(
                child: _buildVideoViews(
                  localStream: localStream,
                  remoteStream: remoteStream,
                  isVideoMuted: isVideoMuted,
                  callState: callState,
                ),
              ),

              // Top Bar
              if (_showControls)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: _buildTopBar(callState, callDuration),
                ),

              // Call Controls
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildCallControls(
                    isAudioMuted: isAudioMuted,
                    isVideoMuted: isVideoMuted,
                    callState: callState,
                  ),
                ),

              // Connection Status
              if (callState == CallState.connecting ||
                  callState == CallState.ringing)
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.4,
                  left: 0,
                  right: 0,
                  child: _buildConnectionStatus(callState),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoViews({
    required MediaStream? localStream,
    required Stream<MediaStream> remoteStream,
    required bool isVideoMuted,
    required CallState callState,
  }) {
    return StreamBuilder<MediaStream>(
      stream: remoteStream,
      builder: (context, snapshot) {
        final remoteStreamValue = snapshot.data;

        return Stack(
          children: [
            // Remote Video (full screen)
            if (remoteStreamValue != null && !isVideoMuted)
              Positioned.fill(
                child: VideoRendererr(
                  stream: remoteStreamValue,
                  fit: BoxFit.cover,
                ),
              )
            else if (callState == CallState.connected)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      UserAvatar(
                        user: _receiver,
                        size: 120,
                        showStatus: false,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _receiver.displayName,
                        style: TextStyles.h2.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Video is off',
                        style: TextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Local Video (PiP)
            if (localStream != null && !isVideoMuted)
              Positioned(
                top: MediaQuery.of(context).padding.top + 80,
                right: 16,
                child: GestureDetector(
                  onTap: _togglePiP,
                  child: Container(
                    width: _isExpanded ? 120 : 80,
                    height: _isExpanded ? 160 : 100,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: VideoRendererr(
                      stream: localStream,
                      isLocal: true,
                      isMirrored: true,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(CallState callState, AsyncValue<Duration> callDuration) {
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

          // Call info
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _receiver.displayName,
                style: TextStyles.h3.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              if (callState == CallState.connected)
                callDuration.when(
                  data: (duration) => CallTimer(
                    duration: duration,
                    status: 'Connected',
                  ),
                  loading: () => Text(
                    '00:00',
                    style: TextStyles.bodyMedium.copyWith(color: Colors.white),
                  ),
                  error: (error, _) => Text(
                    'Error',
                    style: TextStyles.bodyMedium.copyWith(color: AppColors.error),
                  ),
                )
              else
                Text(
                  _getStatusText(callState),
                  style: TextStyles.bodyMedium.copyWith(color: Colors.white),
                ),
            ],
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
    required bool isVideoMuted,
    required CallState callState,
  }) {
    if (callState == CallState.ringing || callState == CallState.connecting) {
      return _buildIncomingCallControls();
    }

    return CallControls(
      isVideoCall: true,
      onEndCall: _endCall,
      onToggleAudio: _toggleAudio,
      onToggleVideo: _toggleVideo,
      onSwitchCamera: _switchCamera,
      onToggleSpeaker: _toggleSpeaker,
      onShowChat: _showChat,
      isAudioMuted: isAudioMuted,
      isVideoMuted: isVideoMuted,
      isSpeakerOn: _isSpeakerOn,
    );
  }

  Widget _buildIncomingCallControls() {
    final callViewModel = ref.read(callViewModelProvider);

    return IncomingCallControls(
      isVideoCall: true,
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