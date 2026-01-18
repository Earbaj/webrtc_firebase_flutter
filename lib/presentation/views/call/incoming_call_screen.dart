import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../domain/entities/user_entity.dart';
import '../../viewmodels/call_viewmodel.dart';
import '../../widgets/user/user_avatar.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> callData;

  const IncomingCallScreen({super.key, required this.callData});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  late UserEntity _caller;
  late String _callId;
  late String _callType;
  bool _isVideoCall = false;

  @override
  void initState() {
    super.initState();
    _parseCallData();
  }

  void _parseCallData() {
    final data = widget.callData;
    _callId = data['callId'] as String;
    _callType = data['callType'] as String;
    _isVideoCall = _callType == AppConstants.callTypeVideo;

    // In a real app, you would fetch caller info from database
    _caller = UserEntity(
      id: data['callerId'] as String,
      email: data['callerEmail'] as String? ?? 'unknown@example.com',
      name: data['callerName'] as String? ?? 'Unknown Caller',
      profileImage: data['callerImage'] as String?,
      status: AppConstants.userStatusOnline,
      lastSeen: DateTime.now(),
      isOnline: true,
    );
  }

  Future<void> _acceptCall() async {
    final callViewModel = ref.read(callViewModelProvider);
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
        // Navigate to call screen
        Navigator.of(context).pop();
        if (_isVideoCall) {
          // Navigate to video call screen
        } else {
          // Navigate to audio call screen
        }
      },
    );
  }

  Future<void> _rejectCall() async {
    final callViewModel = ref.read(callViewModelProvider);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _rejectCall,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    'Incoming Call',
                    style: TextStyles.h3.copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // For balance
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Caller Avatar
                  UserAvatar(
                    user: _caller,
                    size: 120,
                    showStatus: false,
                  ),

                  const SizedBox(height: 32),

                  // Caller Name
                  Text(
                    _caller.displayName,
                    style: TextStyles.h2.copyWith(color: Colors.white),
                  ),

                  const SizedBox(height: 8),

                  // Call Type
                  Text(
                    _isVideoCall ? 'Video Call' : 'Audio Call',
                    style: TextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Ringing Animation
                  _buildRingingAnimation(),

                  const SizedBox(height: 64),
                ],
              ),
            ),

            // Call Controls
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject Button
                  Column(
                    children: [
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: FloatingActionButton(
                          onPressed: _rejectCall,
                          backgroundColor: AppColors.error,
                          child: const Icon(
                            Icons.call_end,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                          onPressed: _acceptCall,
                          backgroundColor: AppColors.success,
                          child: Icon(
                            _isVideoCall ? Icons.videocam : Icons.call,
                            size: 30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isVideoCall ? 'Video' : 'Audio',
                        style: TextStyles.bodyMedium.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingingAnimation() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ring
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
        ),

        // Middle ring
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withOpacity(0.5),
              width: 2,
            ),
          ),
        ),

        // Inner ring
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withOpacity(0.8),
              width: 2,
            ),
          ),
        ),

        // Center icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isVideoCall ? Icons.videocam : Icons.call,
            size: 40,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}