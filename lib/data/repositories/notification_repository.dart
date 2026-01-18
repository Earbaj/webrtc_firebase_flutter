import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fpdart/fpdart.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notification_repository_interface.dart';
import '../datasources/firebase_datasource.dart';
import '../models/notification_model.dart';

class NotificationRepository implements NotificationRepositoryInterface {
  final FirebaseDataSource _dataSource;

  NotificationRepository(this._dataSource);

  @override
  Future<Either<String, void>> sendNotification(NotificationEntity notification) async {
    AppLogger.info('Sending notification: ${notification.title}');
    final notificationModel = NotificationModel.fromEntity(notification);

    try {
      await _dataSource.firestore
          .collection(AppConstants.notificationsCollection)
          .add(notificationModel.toFirestore());
      return right(null);
    } catch (e) {
      AppLogger.error('Send notification failed', error: e);
      return left('Failed to send notification');
    }
  }

  @override
  Future<Either<String, void>> markAsRead(String notificationId) async {
    AppLogger.info('Marking notification as read: $notificationId');
    try {
      await _dataSource.firestore
          .collection(AppConstants.notificationsCollection)
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      return right(null);
    } catch (e) {
      AppLogger.error('Mark notification as read failed', error: e);
      return left('Failed to mark notification as read');
    }
  }

  @override
  Future<Either<String, void>> markAllAsRead(String userId) async {
    AppLogger.info('Marking all notifications as read for: $userId');
    try {
      final snapshot = await _dataSource.firestore
          .collection(AppConstants.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _dataSource.firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return right(null);
    } catch (e) {
      AppLogger.error('Mark all notifications as read failed', error: e);
      return left('Failed to mark all notifications as read');
    }
  }

  @override
  Future<Either<String, void>> deleteNotification(String notificationId) async {
    AppLogger.info('Deleting notification: $notificationId');
    try {
      await _dataSource.firestore
          .collection(AppConstants.notificationsCollection)
          .doc(notificationId)
          .delete();
      return right(null);
    } catch (e) {
      AppLogger.error('Delete notification failed', error: e);
      return left('Failed to delete notification');
    }
  }

  @override
  Future<Either<String, void>> saveFCMToken(String userId, String token) async {
    AppLogger.info('Saving FCM token for: $userId');
    try {
      await _dataSource.firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return right(null);
    } catch (e) {
      AppLogger.error('Save FCM token failed', error: e);
      return left('Failed to save FCM token');
    }
  }

  @override
  Future<Either<String, String?>> getFCMToken(String userId) async {
    AppLogger.info('Getting FCM token for: $userId');
    try {
      final doc = await _dataSource.firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) {
        return left('User not found');
      }

      final token = doc.data()!['fcmToken'] as String?;
      return right(token);
    } catch (e) {
      AppLogger.error('Get FCM token failed', error: e);
      return left('Failed to get FCM token');
    }
  }

  @override
  Future<Either<String, List<NotificationEntity>>> getNotifications(
      String userId,
      ) async {
    AppLogger.info('Getting notifications for: $userId');
    try {
      final snapshot = await _dataSource.firestore
          .collection(AppConstants.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc).toEntity())
          .toList();

      return right(notifications);
    } catch (e) {
      AppLogger.error('Get notifications failed', error: e);
      return left('Failed to get notifications');
    }
  }

  @override
  Future<Either<String, List<NotificationEntity>>> getUnreadNotifications(
      String userId,
      ) async {
    AppLogger.info('Getting unread notifications for: $userId');
    try {
      final snapshot = await _dataSource.firestore
          .collection(AppConstants.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc).toEntity())
          .toList();

      return right(notifications);
    } catch (e) {
      AppLogger.error('Get unread notifications failed', error: e);
      return left('Failed to get unread notifications');
    }
  }

  @override
  Stream<List<NotificationEntity>> notificationsStream(String userId) {
    return _dataSource.notificationsStream(userId)
        .map((notificationModels) => notificationModels
        .map((model) => model.toEntity())
        .toList());
  }

  @override
  Future<Either<String, void>> sendPushNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    AppLogger.info('Sending push notification to token: $token');
    // Note: This would typically call a Cloud Function or backend service
    // For now, we'll just log it
    AppLogger.info('Push notification: $title - $body');
    return right(null);
  }
}