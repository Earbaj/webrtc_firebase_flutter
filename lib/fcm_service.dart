import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMHandlerService {
  // Singleton pattern ensure only one instance of this service exists.
  static final FCMHandlerService _instance = FCMHandlerService._internal();
  factory FCMHandlerService() => _instance;
  FCMHandlerService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Reference to the main navigator key for routing without context.
  GlobalKey<NavigatorState>? navigatorKey;

  /// Entry point to initialize FCM and local notification settings.
  void initialize({GlobalKey<NavigatorState>? navKey}) {
    navigatorKey = navKey;
    _setupFCM();
    setupCallEventListeners();
  }

  /// Sets up FCM permissions and listeners for different app states.
  Future<void> _setupFCM() async {
    // Request notification permissions from the user.
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('User declined or has not accepted permission');
      return;
    }

    // Prepare local notifications for when the app is in the foreground.
    _initializeLocalNotifications();

    // Listener 1: Foreground Messages (app is open and active).
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listener 2: Background Messages Tap (app is in background and user taps notification).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Listener 3: App Start via Notification (app was completely terminated).
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Set up the top-level handler for messages received when the app is in the background.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Initializes the local notification plugin with platform-specific settings.
  void _initializeLocalNotifications() {
    // Android-specific icon for notifications.
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS initialization settings.
    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // This callback triggers when a local notification (created by the app) is tapped.
        if (response.payload != null) {
          final data = jsonDecode(response.payload!);
          _navigateToIncomingCall(data);
        }
      },
    );

    // Create a specific notification channel for calls on Android.
    _createNotificationChannel();
  }

  /// Creates a high-priority notification channel for incoming calls on Android.
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'calls_channel', // Same ID as used in _showLocalNotification
      'Incoming Calls',
      description: 'Channel for incoming call notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Colors.red,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Handler for messages received while the app is in the foreground.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message received: ${message.data}');

    // If it's a 'call' type message, show CallKit screen directly
    if (message.data['type'] == 'call') {
      print('📞 Call received in foreground - showing CallKit screen');

      // Show CallKit screen directly without local notification
      await showNativeIncomingCall(
        callId: message.data['callId']!,
        callerName: message.data['callerName']!,
        callerId: message.data['callerId']!,
        isVideo: message.data['callType'] == 'video',
        roomId: message.data['roomId']!,
        callerEmail: message.data['callerEmail']!,
      );
    } else {
      // Show regular notification for non-call messages
      await _showRegularNotification(message);
    }
  }

  /// Show regular notification for non-call messages
  Future<void> _showRegularNotification(RemoteMessage message) async {
    if (message.notification == null) return;

    await _localNotifications.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'regular_channel',
          'Regular Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Handler for when the user taps on a notification to open the app.
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('Message opened app: ${message.data}');

    if (message.data['type'] == 'call') {
      _navigateToIncomingCall(message.data);
    }
  }

  /// Navigates to the video call screen with the correct parameters.
  void _navigateToIncomingCall(Map<String, dynamic> data) {
    if (navigatorKey?.currentState != null) {
      navigatorKey!.currentState!.pushNamed(
        '/video_call',
        arguments: {
          'roomId': data['roomId'],
          'isVideo': data['callType'] == 'video',
          'isJoining': true,
          'callerId': data['callerId'],
          'callerName': data['callerName'],
          'callerEmail': data['callerEmail'],
        },
      );
    }
  }

  static Future<void> showNativeIncomingCall({
    required String callId,
    required String callerName,
    required String callerId,
    required bool isVideo,
    required String roomId,
    required String callerEmail,
  }) async {
    print('📞 Showing native incoming call screen');
    print('Call ID: $callId');
    print('Caller: $callerName');
    print('Type: ${isVideo ? "video" : "audio"}');

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'WebRTC Flutter',
      handle: callerId,
      type: isVideo ? 1 : 0, // 0 = audio, 1 = video
      textAccept: 'Accept',
      textDecline: 'Decline',
      duration: 30000,
      extra: <String, dynamic>{
        'roomId': roomId,
        'callerEmail': callerEmail,
        'callType': isVideo ? 'video' : 'audio',
        'callerId': callerId,
      },
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: 'Incoming Calls',
      ),
      ios: IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  void setupCallEventListeners() {
    // Listen for events from CallKit
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;

      print('📱 Call Event: ${event.event.name} - ${event.body}');

      // Extract the simple event name from the full string
      final eventName = event.event.name.split('.').last;
      print('📱 Simplified event name: $eventName');

      switch (eventName) {
        case 'ACTION_CALL_INCOMING':
          print('📞 Incoming call received');
          break;

        case 'ACTION_CALL_START':
          print('📞 Call started');
          break;

        case 'ACTION_CALL_ACCEPT':
          print('✅ Call accepted by user');

          // Safely convert the event body to a Map<String, dynamic>
          final callData = _convertToMap(event.body);
          if (callData != null) {
            print('✅ Call data: $callData');

            // Safely extract extra data
            Map<String, dynamic>? extra;
            if (callData['extra'] != null) {
              extra = _convertToMap(callData['extra']);
            }
            print('✅ Extra data: $extra');

            // Log navigator state
            print('✅ navigatorKey exists: ${_instance.navigatorKey != null}');
            print('✅ currentState exists: ${_instance.navigatorKey?.currentState != null}');

            // Check if we have all required data
            final roomId = extra?['roomId']?.toString() ?? '';
            final callType = extra?['callType']?.toString() ?? 'audio';
            final callerId = callData['id']?.toString() ?? '';
            final callerName = callData['nameCaller']?.toString() ?? '';
            final callerEmail = extra?['callerEmail']?.toString() ?? '';

            print('✅ Navigation params:');
            print('  - roomId: $roomId');
            print('  - callType: $callType');
            print('  - callerId: $callerId');
            print('  - callerName: $callerName');
            print('  - callerEmail: $callerEmail');

            // End the CallKit UI first
            FlutterCallkitIncoming.endAllCalls();

            // Navigate to call screen with a small delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_instance.navigatorKey?.currentState != null) {
                print('✅ Navigating to video call screen');
                try {
                  _instance.navigatorKey!.currentState!.pushNamed(
                    '/video_call',
                    arguments: {
                      'roomId': roomId,
                      'isVideo': callType == 'video',
                      'isJoining': true,
                      'callerId': callerId,
                      'callerName': callerName,
                      'callerEmail': callerEmail,
                    },
                  );
                  print('✅ Navigation successful');
                } catch (e) {
                  print('❌ Navigation error: $e');
                }
              } else {
                print('❌ navigatorKey.currentState is null');
              }
            });
          }
          break;

        case 'ACTION_CALL_DECLINE':
          print('❌ Call declined by user');

          final callData = _convertToMap(event.body);
          if (callData != null) {
            final callId = callData['id']?.toString() ?? '';
            print('❌ Declined call ID: $callId');

            // End the CallKit UI
            if (callId.isNotEmpty) {
              FlutterCallkitIncoming.endCall(callId);
            }

            // Update call status in Firestore
            if (callId.isNotEmpty) {
              FirebaseFirestore.instance
                  .collection('calls')
                  .doc(callId)
                  .update({'status': 'declined'});
            }
          }
          break;

        case 'ACTION_CALL_ENDED':
          print('📞 Call ended');

          final callData = _convertToMap(event.body);
          if (callData != null) {
            final callId = callData['id']?.toString() ?? '';
            if (callId.isNotEmpty) {
              FirebaseFirestore.instance
                  .collection('calls')
                  .doc(callId)
                  .update({'status': 'ended'});
            }
          }
          break;

        case 'ACTION_CALL_TIMEOUT':
          print('⏰ Call timeout');

          final callData = _convertToMap(event.body);
          if (callData != null) {
            final callId = callData['id']?.toString() ?? '';
            if (callId.isNotEmpty) {
              FirebaseFirestore.instance
                  .collection('calls')
                  .doc(callId)
                  .update({'status': 'missed'});
            }
          }
          break;

        default:
          print('❓ Unknown event: $eventName');
          break;
      }
    });
  }

// Helper method to safely convert dynamic to Map<String, dynamic>
  Map<String, dynamic>? _convertToMap(dynamic value) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      return value;
    } else if (value is Map) {
      // Convert Map<Object?, Object?> to Map<String, dynamic>
      return value.map((key, val) => MapEntry(key.toString(), val));
    }

    return null;
  }

  // Method to end an active call
  static Future<void> endCall(String callId) async {
    await FlutterCallkitIncoming.endCall(callId);
  }

  // Method to check if there's an active call
  static Future<bool> hasActiveCall() async {
    final calls = await FlutterCallkitIncoming.activeCalls();
    return calls?.isNotEmpty ?? false;
  }
}

/// A top-level function that handles FCM messages when the app is in the background or killed.
/// It must be top-level (not part of a class) to be used by the background isolation.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background processing.
  await Firebase.initializeApp();

  print('Background message: ${message.data}');

  if (message.data['type'] == 'call') {
    print('📞 Background call received - showing native CallKit screen');

    // Only show CallKit screen, no local notification
    await FCMHandlerService.showNativeIncomingCall(
      callId: message.data['callId']!,
      callerName: message.data['callerName']!,
      callerId: message.data['callerId']!,
      isVideo: message.data['callType'] == 'video',
      roomId: message.data['roomId']!,
      callerEmail: message.data['callerEmail']!,
    );
  }
}
