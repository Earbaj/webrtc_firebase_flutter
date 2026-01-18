import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:webrtc_flutter/presentation/providers/user_provider.dart';

import '../../data/repositories/call_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/entities/signaling_entity.dart';
import 'auth_provider.dart';

// Providers for repositories
final callRepositoryProvider = Provider<CallRepository>((ref) {
  final dataSource = ref.watch(firebaseDataSourceProvider);
  return CallRepository(dataSource);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dataSource = ref.watch(firebaseDataSourceProvider);
  return NotificationRepository(dataSource);
});

// Call Notifier
class CallNotifier extends StateNotifier<AsyncValue<void>> {
  final CallRepository _callRepository;
  final Ref _ref;

  CallNotifier(this._callRepository, this._ref) : super(const AsyncValue.data(null));

  Future<Either<String, CallEntity>> initiateCall({
    required String receiverId,
    required String callType,
  }) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser == null) {
        return left('User not authenticated');
      }

      // Check if receiver is busy
      final isBusyResult = await _callRepository.isUserBusy(receiverId);
      return await isBusyResult.fold(
            (error) => left(error),
            (isBusy) async {
          if (isBusy) {
            return left('User is currently in another call');
          }

          final result = await _callRepository.createCall(
            callerId: currentUser.id,
            receiverId: receiverId,
            callType: callType,
          );

          state = const AsyncValue.data(null);
          return result;
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('Failed to initiate call');
    }
  }

  Future<Either<String, void>> endCall(String callId, Duration? duration) async {
    state = const AsyncValue.loading();
    try {
      final result = await _callRepository.endCall(callId, duration);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('Failed to end call');
    }
  }

  Future<Either<String, void>> rejectCall(String callId, String reason) async {
    state = const AsyncValue.loading();
    try {
      final result = await _callRepository.rejectCall(callId, reason);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('Failed to reject call');
    }
  }

  Future<Either<String, void>> markCallAsMissed(String callId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _callRepository.markCallAsMissed(callId);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('Failed to mark call as missed');
    }
  }

  // Signaling methods
  Future<Either<String, void>> sendOffer({
    required String callId,
    required String toUserId,
    required Map<String, dynamic> offer,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      return left('User not authenticated');
    }

    return await _callRepository.sendOffer(
      callId: callId,
      fromUserId: currentUser.id,
      toUserId: toUserId,
      offer: offer,
    );
  }

  Stream<SignalingEntity> listenForIncomingCalls() {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _callRepository.listenForOffers(currentUser.id);
  }

  Stream<SignalingEntity> listenForAnswers(String callId) {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _callRepository.listenForAnswers(callId, currentUser.id);
  }

  Stream<CallEntity> listenForCallUpdates(String callId) {
    return _callRepository.listenForCallUpdates(callId);
  }
}

final callNotifierProvider = StateNotifierProvider<CallNotifier, AsyncValue<void>>((ref) {
  final callRepository = ref.watch(callRepositoryProvider);
  return CallNotifier(callRepository, ref);
});

// Active Call Provider
final activeCallProvider = StateProvider<CallEntity?>((ref) => null);

// Incoming Call Provider
final incomingCallProvider = StateProvider<SignalingEntity?>((ref) => null);