import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:webrtc_flutter/presentation/providers/user_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../data/datasources/webrtc_datasource.dart';
import '../../data/repositories/call_repository.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/entities/signaling_entity.dart';
import 'call_provider.dart';

// Provider for WebRTC DataSource
final webRTCDataSourceProvider = Provider<WebRTCDataSource>((ref) {
  return WebRTCDataSource();
});

// Call State Enum
enum CallState {
  idle,
  initializing,
  ringing,
  connecting,
  connected,
  ending,
  ended,
  error,
}

// WebRTC Notifier
class WebRTCNotifier extends StateNotifier<CallState> {
  final WebRTCDataSource _webRTCDataSource;
  final CallRepository _callRepository;
  final Ref _ref;

  String? _currentCallId;
  String? _receiverId;
  String? _callType;
  StreamSubscription? _iceCandidateSubscription;
  StreamSubscription? _remoteStreamSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _signalingSubscription;
  StreamSubscription? _answersSubscription;

  WebRTCNotifier(
      this._webRTCDataSource,
      this._callRepository,
      this._ref,
      ) : super(CallState.idle);

  // Initialize call as caller
  Future<Either<String, CallEntity>> initializeCall({
    required String receiverId,
    required String callType,
  }) async {
    try {
      AppLogger.call('Initializing call to $receiverId ($callType)');
      state = CallState.initializing;

      // Get current user
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser == null) {
        return left('User not authenticated');
      }

      // Create call in Firestore
      final callResult = await _callRepository.createCall(
        callerId: currentUser.id,
        receiverId: receiverId,
        callType: callType,
      );

      return await callResult.fold(
            (error) => left(error),
            (call) async {
          _currentCallId = call.callId;
          _receiverId = receiverId;
          _callType = callType;

          // Initialize WebRTC
          await _webRTCDataSource.initializePeerConnection();

          // Get local media stream
          await _webRTCDataSource.getLocalMediaStream(
            audio: true,
            video: callType == AppConstants.callTypeVideo,
          );

          // Create data channel for signaling
          await _webRTCDataSource.createDataChannel('chat');

          // Create offer
          final offer = await _webRTCDataSource.createOffer();

          // Send offer via signaling
          await _callRepository.sendOffer(
            callId: call.callId,
            fromUserId: currentUser.id,
            toUserId: receiverId,
            offer: offer.toMap(),
          );

          // Listen for answers
          _listenForAnswers(call.callId);

          // Listen for ICE candidates
          _listenForIceCandidates(call.callId, receiverId);

          // Send local ICE candidates
          _sendLocalIceCandidates(call.callId, receiverId);

          AppLogger.call('Call initialized successfully: ${call.callId}');
          state = CallState.ringing;

          return right(call);
        },
      );
    } catch (e) {
      AppLogger.error('Failed to initialize call', error: e);
      state = CallState.error;
      return left('Failed to initialize call: ${e.toString()}');
    }
  }

  // Handle incoming call
  Future<Either<String, CallEntity>> handleIncomingCall({
    required SignalingEntity offer,
  }) async {
    try {
      AppLogger.call('Handling incoming call: ${offer.callId}');
      state = CallState.initializing;

      // Get current user
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser == null) {
        return left('User not authenticated');
      }

      // Get call from Firestore
      final callResult = await _callRepository.getCall(offer.callId);

      return await callResult.fold(
            (error) => left(error),
            (call) async {
          _currentCallId = call.callId;
          _receiverId = call.callerId;
          _callType = call.callType;

          // Initialize WebRTC
          await _webRTCDataSource.initializePeerConnection();

          // Get local media stream
          await _webRTCDataSource.getLocalMediaStream(
            audio: true,
            video: call.callType == AppConstants.callTypeVideo,
          );

          // Create data channel
          await _webRTCDataSource.createDataChannel('chat');

          // Set remote description from offer
          final rtcOffer = RTCSessionDescription(
            offer.sdp,
            offer.sdp,
          );
          await _webRTCDataSource.setRemoteDescription(rtcOffer);

          // Create and send answer
          final answer = await _webRTCDataSource.createAnswer();

          await _callRepository.sendAnswer(
            callId: call.callId,
            fromUserId: currentUser.id,
            toUserId: call.callerId,
            answer: answer.toMap(),
          );

          // Listen for ICE candidates
          _listenForIceCandidates(call.callId, call.callerId);

          // Send local ICE candidates
          _sendLocalIceCandidates(call.callId, call.callerId);

          // Start listening for remote stream
          _listenForRemoteStream();

          // Start listening for connection state
          _listenForConnectionState();

          AppLogger.call('Incoming call handled successfully');
          state = CallState.ringing;

          return right(call);
        },
      );
    } catch (e) {
      AppLogger.error('Failed to handle incoming call', error: e);
      state = CallState.error;
      return left('Failed to handle incoming call: ${e.toString()}');
    }
  }

  // Accept incoming call
  Future<Either<String, void>> acceptCall() async {
    try {
      AppLogger.call('Accepting call: $_currentCallId');
      state = CallState.connecting;

      // Update call status
      if (_currentCallId != null) {
        final callResult = await _callRepository.getCall(_currentCallId!);

        await callResult.fold(
              (error) => throw Exception(error),
              (call) async {
            final updatedCall = call.copyWith(
              status: AppConstants.callStatusConnecting,
            );
            await _callRepository.updateCall(updatedCall);
          },
        );
      }

      // Wait for connection
      await Future.delayed(const Duration(seconds: 2));

      state = CallState.connected;
      AppLogger.call('Call accepted successfully');

      return right(null);
    } catch (e) {
      AppLogger.error('Failed to accept call', error: e);
      state = CallState.error;
      return left('Failed to accept call: ${e.toString()}');
    }
  }

  // End current call
  Future<Either<String, void>> endCall() async {
    try {
      AppLogger.call('Ending call: $_currentCallId');
      state = CallState.ending;

      // Update call status in Firestore
      if (_currentCallId != null) {
        await _callRepository.endCall(_currentCallId!, null);
      }

      // Update user status
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser != null) {
        await _callRepository.setUserInCall(currentUser.id, false);
      }

      // Close WebRTC connection
      await _cleanup();

      state = CallState.ended;
      AppLogger.call('Call ended successfully');

      return right(null);
    } catch (e) {
      AppLogger.error('Failed to end call', error: e);
      state = CallState.error;
      return left('Failed to end call: ${e.toString()}');
    }
  }

  // Reject incoming call
  Future<Either<String, void>> rejectCall(String reason) async {
    try {
      AppLogger.call('Rejecting call: $_currentCallId - $reason');

      if (_currentCallId != null) {
        await _callRepository.rejectCall(_currentCallId!, reason);
      }

      await _cleanup();
      state = CallState.ended;

      return right(null);
    } catch (e) {
      AppLogger.error('Failed to reject call', error: e);
      return left('Failed to reject call: ${e.toString()}');
    }
  }

  // Toggle audio mute
  Future<void> toggleAudioMute() async {
    try {
      await _webRTCDataSource.toggleAudioMute();
    } catch (e) {
      AppLogger.error('Failed to toggle audio mute', error: e);
    }
  }

  // Toggle video mute
  Future<void> toggleVideoMute() async {
    try {
      await _webRTCDataSource.toggleVideoMute();
    } catch (e) {
      AppLogger.error('Failed to toggle video mute', error: e);
    }
  }

  // Switch camera
  Future<void> switchCamera() async {
    try {
      await _webRTCDataSource.switchCamera();
    } catch (e) {
      AppLogger.error('Failed to switch camera', error: e);
    }
  }

  // Send message via data channel
  Future<void> sendMessage(String message) async {
    try {
      await _webRTCDataSource.sendDataChannelMessage(message);
    } catch (e) {
      AppLogger.error('Failed to send message', error: e);
    }
  }

  // Getters
  Stream<MediaStream> get remoteStream => _webRTCDataSource.remoteStream;
  MediaStream? get localStream => _webRTCDataSource.localStream;
  bool get isAudioMuted => _webRTCDataSource.isAudioMuted();
  bool get isVideoMuted => _webRTCDataSource.isVideoMuted();
  String? get currentCallId => _currentCallId;
  String? get receiverId => _receiverId;
  String? get callType => _callType;

  // Private methods
  void _listenForAnswers(String callId) {
    _answersSubscription = _callRepository
        .listenForAnswers(callId, _receiverId!)
        .listen((signaling) async {
      if (signaling.isAnswer) {
        AppLogger.call('Received answer for call: $callId');

        final rtcAnswer = RTCSessionDescription(
          signaling.sdp,
          signaling.sdp,
        );

        await _webRTCDataSource.setRemoteDescription(rtcAnswer);

        // Start listening for remote stream
        _listenForRemoteStream();

        // Start listening for connection state
        _listenForConnectionState();
      }
    });
  }

  void _listenForIceCandidates(String callId, String senderId) {
    _signalingSubscription = _callRepository
        .listenForIceCandidates(callId, _ref.read(currentUserProvider)!.id)
        .listen((signaling) async {
      if (signaling.isCandidate) {
        AppLogger.call('Received ICE candidate for call: $callId');
        await _webRTCDataSource.addIceCandidateFromSignaling(signaling);
      }
    });
  }

  void _sendLocalIceCandidates(String callId, String receiverId) {
    _iceCandidateSubscription = _webRTCDataSource.iceCandidates.listen(
          (candidate) async {
        final currentUser = _ref.read(currentUserProvider);
        if (currentUser == null) return;

        await _callRepository.sendIceCandidate(
          callId: callId,
          fromUserId: currentUser.id,
          toUserId: receiverId,
          candidate: candidate.toMap(),
        );
      },
    );
  }

  void _listenForRemoteStream() {
    _remoteStreamSubscription = _webRTCDataSource.remoteStream.listen((stream) {
      AppLogger.call('Remote stream received');
    });
  }

  void _listenForConnectionState() {
    _connectionStateSubscription = _webRTCDataSource.connectionState.listen(
          (state) {
        AppLogger.call('Connection state: $state');

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          //state = CallState.connected;
          CallState.connected;
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          //state = CallState.ended;
          CallState.ended;
          _cleanup();
        }
      },
    );
  }

  Future<void> _cleanup() async {
    AppLogger.call('Cleaning up WebRTC resources');

    // Cancel subscriptions
    await _iceCandidateSubscription?.cancel();
    await _remoteStreamSubscription?.cancel();
    await _connectionStateSubscription?.cancel();
    await _signalingSubscription?.cancel();
    await _answersSubscription?.cancel();

    // Close WebRTC connection
    await _webRTCDataSource.close();

    // Reset state
    _currentCallId = null;
    _receiverId = null;
    _callType = null;

    AppLogger.call('Cleanup completed');
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}

// Provider for WebRTC Notifier
final webRTCNotifierProvider = StateNotifierProvider<WebRTCNotifier, CallState>((ref) {
  final dataSource = ref.read(webRTCDataSourceProvider);
  final callRepository = ref.read(callRepositoryProvider);
  return WebRTCNotifier(dataSource, callRepository, ref);
});

// Active Call Provider
final activeCallProvider = StateProvider<CallEntity?>((ref) => null);

// Call Duration Provider
final callDurationProvider = StreamProvider<Duration>((ref) async* {
  final call = ref.watch(activeCallProvider);
  if (call == null) return;

  final startTime = call.startedAt;

  while (true) {
    await Future.delayed(const Duration(seconds: 1));
    final duration = DateTime.now().difference(startTime);
    yield duration;
  }
});