import 'dart:developer';

import 'package:flutter/foundation.dart';

class AppLogger {
  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      log('🔵 DEBUG: $message');
      if (error != null) log('Error: $error');
      if (stackTrace != null) log('Stack: $stackTrace');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      log('🟢 INFO: $message');
    }
  }

  static void warning(String message, {Object? error}) {
    if (kDebugMode) {
      log('🟡 WARNING: $message');
      if (error != null) log('Error: $error');
    }
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      log('🔴 ERROR: $message');
      if (error != null) log('Error: $error');
      if (stackTrace != null) log('Stack: $stackTrace');
    }
  }

  // WebRTC specific logging
  static void webrtc(String message) {
    if (kDebugMode) {
      log('📡 WEBRTC: $message');
    }
  }

  // Firebase specific logging
  static void firebase(String message) {
    if (kDebugMode) {
      log('🔥 FIREBASE: $message');
    }
  }

  // Call specific logging
  static void call(String message) {
    if (kDebugMode) {
      log('📞 CALL: $message');
    }
  }
}