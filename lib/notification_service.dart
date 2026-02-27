import 'dart:convert';
import 'dart:developer';
import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import 'api_server_key.dart';

/// A service class to handle notification permissions, token retrieval,
/// and sending push notifications to other users.
class NotificationService {
  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;

  /// Requests all necessary notification permissions from the user.
  /// If the user declines, it can optionally open the app settings.
  void requestNotificationPermission() async {
    NotificationSettings settings = await firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log("User granted permission");
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      log("User granted provisional permission");
    } else {
      log("User declined or has not accepted permission");
      // Optionally lead the user to settings after a short delay if they declined.
      Future.delayed(const Duration(seconds: 3), () {
        AppSettings.openAppSettings(type: AppSettingsType.notification);
      });
    }
  }

  /// Sends a push notification to a specific device using the FCM HTTP v1 API.
  /// This is used to signal an incoming call to the receiver.
  Future<void> sendCallNotification({
    required String receiverToken,
    required String callerName,
    required String callType,
    required String roomId,
    required String callId,
    required String callerId,
    required String callerEmail,
  }) async {
    try {
      // 1. Get the OAuth2 server key needed for FCM HTTP v1.
      GetApiServerKeyFCM serverKey = GetApiServerKeyFCM();
      String fcmApiServerKey = await serverKey.getServerKey();

      // 2. Construct the FCM message body.
      // We include both a 'notification' (for OS display) and 'data' (for app logic).
      final body = {
        "message": {
          "token": receiverToken,
          "data": {
            "type": "call",
            "callId": callId,
            "roomId": roomId,
            "callerName": callerName,
            "callerEmail": callerEmail,
            "callerId": callerId,
            "callType": callType,
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
          },
          "notification": {
            "title": "Incoming ${callType == 'video' ? 'Video' : 'Audio'} Call",
            "body": "$callerName is calling you.",
          }
        }
      };

      // 3. Send the HTTP POST request to the FCM endpoint.
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/flutterwebrtc-2dc24/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $fcmApiServerKey',
        },
        body: jsonEncode(body),
      );

      log('FCM response status: ${response.statusCode}');
      log('FCM response body: ${response.body}');

    } catch (e) {
      log('Error sending FCM notification: $e');
    }
  }

  /// Retrieves the unique FCM token for the current device.
  /// This token is used by others to send notifications to this device.
  Future<String> getDeviceToken() async {
    // Ensure permission is granted before getting the token.
    await firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true
    );
    
    String? token = await firebaseMessaging.getToken();
    log("Device Token: $token");
    return token ?? "";
  }
}
