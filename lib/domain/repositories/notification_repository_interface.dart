import 'package:fpdart/fpdart.dart';

import '../entities/notification_entity.dart';

abstract class NotificationRepositoryInterface {
  // Notification management
  Future<Either<String, void>> sendNotification(NotificationEntity notification);
  Future<Either<String, void>> markAsRead(String notificationId);
  Future<Either<String, void>> markAllAsRead(String userId);
  Future<Either<String, void>> deleteNotification(String notificationId);

  // FCM token
  Future<Either<String, void>> saveFCMToken(String userId, String token);
  Future<Either<String, String?>> getFCMToken(String userId);

  // Notification queries
  Future<Either<String, List<NotificationEntity>>> getNotifications(String userId);
  Future<Either<String, List<NotificationEntity>>> getUnreadNotifications(String userId);

  // Streams
  Stream<List<NotificationEntity>> notificationsStream(String userId);

  // Push notifications
  Future<Either<String, void>> sendPushNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  });
}