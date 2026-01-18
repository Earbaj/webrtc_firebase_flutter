import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:webrtc_flutter/presentation/providers/user_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/entities/notification_entity.dart';
import 'call_provider.dart';

// Notification Notifier
class NotificationNotifier extends StateNotifier<AsyncValue<void>> {
  final NotificationRepository _notificationRepository;
  final Ref _ref;

  NotificationNotifier(this._notificationRepository, this._ref)
      : super(const AsyncValue.data(null));

  Future<Either<String, void>> sendCallNotification({
    required String receiverId,
    required String callId,
    required String callType,
    required String callerName,
  }) async {
    try {
      final notification = NotificationEntity(
        id: '',
        userId: receiverId,
        type: AppConstants.notificationTypeCall,
        title: 'Incoming ${callType == AppConstants.callTypeVideo ? 'Video' : 'Audio'} Call',
        body: '$callerName is calling you',
        data: {
          'callId': callId,
          'callType': callType,
          'callerId': _ref.read(currentUserProvider)?.id ?? '',
          'callerName': callerName,
        },
        isRead: false,
        createdAt: DateTime.now(),
      );

      return await _notificationRepository.sendNotification(notification);
    } catch (e) {
      return left('Failed to send notification');
    }
  }

  Future<Either<String, void>> sendMissedCallNotification({
    required String receiverId,
    required String callerName,
    required String callId,
  }) async {
    try {
      final notification = NotificationEntity(
        id: '',
        userId: receiverId,
        type: AppConstants.notificationTypeMissedCall,
        title: 'Missed Call',
        body: 'You missed a call from $callerName',
        data: {
          'callId': callId,
          'callerName': callerName,
          'timestamp': DateTime.now().toIso8601String(),
        },
        isRead: false,
        createdAt: DateTime.now(),
      );

      return await _notificationRepository.sendNotification(notification);
    } catch (e) {
      return left('Failed to send missed call notification');
    }
  }

  Future<Either<String, void>> markAsRead(String notificationId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _notificationRepository.markAsRead(notificationId);
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('Failed to mark notification as read');
    }
  }

  Stream<List<NotificationEntity>> getNotificationsStream() {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _notificationRepository.notificationsStream(currentUser.id);
  }

  Future<Either<String, void>> saveFCMToken(String token) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) {
      return left('User not authenticated');
    }

    return await _notificationRepository.saveFCMToken(currentUser.id, token);
  }
}

final notificationNotifierProvider = StateNotifierProvider<NotificationNotifier, AsyncValue<void>>((ref) {
  final notificationRepository = ref.watch(notificationRepositoryProvider);
  return NotificationNotifier(notificationRepository, ref);
});

// Notifications Stream Provider
final notificationsProvider = StreamProvider<List<NotificationEntity>>((ref) {
  final notifier = ref.watch(notificationNotifierProvider.notifier);
  return notifier.getNotificationsStream();
});

// Unread Notifications Count Provider
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? [];
  return notifications.where((n) => !n.isRead).length;
});