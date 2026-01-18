import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  // Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  // Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  // Request notification permission
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  // Check if all call permissions are granted
  static Future<bool> checkCallPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    return cameraStatus.isGranted && microphoneStatus.isGranted;
  }

  // Request all call permissions
  static Future<bool> requestCallPermissions() async {
    final cameraGranted = await requestCameraPermission();
    final microphoneGranted = await requestMicrophonePermission();

    return cameraGranted && microphoneGranted;
  }

  // Check if permissions are permanently denied
  static Future<bool> arePermissionsPermanentlyDenied() async {
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    return cameraStatus.isPermanentlyDenied ||
        microphoneStatus.isPermanentlyDenied;
  }

  // Open app settings
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}