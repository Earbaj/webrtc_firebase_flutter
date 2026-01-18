class AppConstants {
  static const String appName = 'WebRTC Call';
  static const String appVersion = '1.0.0';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String callsCollection = 'calls';
  static const String callLogsCollection = 'call_logs';
  static const String notificationsCollection = 'notifications';

  // Storage paths
  static const String profileImagesPath = 'profile_images';

  // Call types
  static const String callTypeVideo = 'video';
  static const String callTypeAudio = 'audio';

  // Call status
  static const String callStatusInitiated = 'initiated';
  static const String callStatusRinging = 'ringing';
  static const String callStatusConnecting = 'connecting';
  static const String callStatusConnected = 'connected';
  static const String callStatusEnded = 'ended';
  static const String callStatusMissed = 'missed';
  static const String callStatusRejected = 'rejected';
  static const String callStatusBusy = 'busy';
  static const String callStatusFailed = 'failed';

  // User status
  static const String userStatusOnline = 'online';
  static const String userStatusOffline = 'offline';
  static const String userStatusBusy = 'busy';

  // Notification types
  static const String notificationTypeCall = 'call';
  static const String notificationTypeMissedCall = 'missed_call';
  static const String notificationTypeMessage = 'message';

  // Timeouts
  static const int callTimeoutSeconds = 45;
  static const int iceConnectionTimeoutSeconds = 30;

  // ICE Servers (you can add your own TURN/STUN servers)
  static const Map<String, dynamic> iceServers = {
    'iceServers': [
      {'url': 'stun:stun.l.google.com:19302'},
      {'url': 'stun:stun1.l.google.com:19302'},
      {'url': 'stun:stun2.l.google.com:19302'},
      // Add your TURN servers here for production
      // {
      //   'url': 'turn:your-turn-server.com:3478',
      //   'username': 'username',
      //   'credential': 'password'
      // }
    ]
  };

}