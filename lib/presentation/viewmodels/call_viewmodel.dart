import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/entities/signaling_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../providers/webrtc_provider.dart';

class CallViewModel {
  final Ref ref;

  CallViewModel(this.ref);

  // Initialize outgoing call
  Future<Either<String, CallEntity>> initiateCall({
    required UserEntity receiver,
    required String callType,
  }) async {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);

    final result = await webRTCNotifier.initializeCall(
      receiverId: receiver.id,
      callType: callType,
    );

    result.fold(
          (error) => AppLogger.error('Call initiation failed: $error'),
          (call) {
        // Set active call
        ref.read(activeCallProvider.notifier).state = call;

        // Send notification to receiver
        _sendCallNotification(receiver, call);
      },
    );

    return result;
  }

  // Handle incoming call
  Future<Either<String, CallEntity>> handleIncomingCall(
      Map<String, dynamic> data,
      ) async {
    // Parse incoming call data
    final callId = data['callId'] as String?;
    final callerId = data['callerId'] as String?;
    final callType = data['callType'] as String?;

    if (callId == null || callerId == null || callType == null) {
      return left('Invalid call data');
    }

    // Create signaling entity
    final signaling = SignalingEntity(
      type: 'offer',
      fromUserId: callerId,
      toUserId: ref.read(currentUserProvider)!.id,
      callId: callId,
      timestamp: DateTime.now(),
      sdp: data['sdp'],
    );

    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);

    final result = await webRTCNotifier.handleIncomingCall(
      offer: signaling,
    );

    result.fold(
          (error) => AppLogger.error('Incoming call handling failed: $error'),
          (call) {
        // Set active call
        ref.read(activeCallProvider.notifier).state = call;
      },
    );

    return result;
  }

  // Accept incoming call
  Future<Either<String, void>> acceptCall() async {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    final call = ref.read(activeCallProvider);

    if (call == null) {
      return left('No active call to accept');
    }

    final result = await webRTCNotifier.acceptCall();

    result.fold(
          (error) => AppLogger.error('Call acceptance failed: $error'),
          (_) {
        // Update call status
        final updatedCall = call.copyWith(
          status: AppConstants.callStatusConnected,
        );
        ref.read(activeCallProvider.notifier).state = updatedCall;
      },
    );

    return result;
  }

  // End current call
  Future<Either<String, void>> endCall() async {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    final call = ref.read(activeCallProvider);

    if (call == null) {
      return left('No active call to end');
    }

    final result = await webRTCNotifier.endCall();

    result.fold(
          (error) => AppLogger.error('Call ending failed: $error'),
          (_) {
        // Clear active call
        ref.read(activeCallProvider.notifier).state = null;
      },
    );

    return result;
  }

  // Reject incoming call
  Future<Either<String, void>> rejectCall(String reason) async {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    final result = await webRTCNotifier.rejectCall(reason);

    result.fold(
          (error) => AppLogger.error('Call rejection failed: $error'),
          (_) {
        // Clear active call
        ref.read(activeCallProvider.notifier).state = null;
      },
    );

    return result;
  }

  // Toggle audio mute
  Future<void> toggleAudioMute() async {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    await webRTCNotifier.toggleAudioMute();
  }

  // Toggle video mute
  Future<void> toggleVideoMute() async {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    await webRTCNotifier.toggleVideoMute();
  }

  // Switch camera
  Future<void> switchCamera() async {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    await webRTCNotifier.switchCamera();
  }

  // Send message during call
  Future<void> sendMessage(String message) async {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    await webRTCNotifier.sendMessage(message);
  }

  // Get call state
  CallState get callState => ref.read(webRTCNotifierProvider);

  // Get remote stream
  Stream<MediaStream> get remoteStream {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    return webRTCNotifier.remoteStream;
  }

  // Get local stream
  MediaStream? get localStream {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    return webRTCNotifier.localStream;
  }

  // Check if audio is muted
  bool get isAudioMuted {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    return webRTCNotifier.isAudioMuted;
  }

  // Check if video is muted
  bool get isVideoMuted {
    final webRTCNotifier = ref.read(webRTCNotifierProvider.notifier);
    return webRTCNotifier.isVideoMuted;
  }

  // Get current call
  CallEntity? get currentCall => ref.read(activeCallProvider);

  // Get call duration
  Stream<Duration> get callDuration => ref.watch(callDurationProvider.stream);

  // Get receiver info
  Future<UserEntity?> getReceiverInfo() async {
    final call = ref.read(activeCallProvider);
    if (call == null) return null;

    final currentUser = ref.read(currentUserProvider);
    final receiverId = call.callerId == currentUser?.id
        ? call.receiverId
        : call.callerId;

    final userRepository = ref.read(userRepositoryProvider);
    final result = await userRepository.getUser(receiverId);

    return result.fold(
          (error) => null,
          (user) => user,
    );
  }

  // Private method to send call notification
  void _sendCallNotification(UserEntity receiver, CallEntity call) {
    final notificationNotifier = ref.read(notificationNotifierProvider.notifier);
    final currentUser = ref.read(currentUserProvider);

    if (currentUser == null) return;

    notificationNotifier.sendCallNotification(
      receiverId: receiver.id,
      callId: call.callId,
      callType: call.callType,
      callerName: currentUser.displayName,
    );
  }
}

// Provider for CallViewModel
final callViewModelProvider = Provider<CallViewModel>((ref) {
  return CallViewModel(ref);
});