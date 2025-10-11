// socket_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  late IO.Socket _socket;

  final String serverUrl = 'https://sfu-server-nodejs.onrender.com';
  bool _isConnected = false;
  String? _currentUserId;

  // Event callbacks
  Function(Map<String, dynamic>)? onCallIncoming;
  Function(Map<String, dynamic>)? onCallAccepted;
  Function(Map<String, dynamic>)? onCallRejected;
  Function(Map<String, dynamic>)? onCallEnded;

  Function(Map<String, dynamic>)? onCallInitiated;
  Function(Map<String, dynamic>)? onCallBusy;
  Function(Map<String, dynamic>)? onCallFailed;

  Function()? onConnected;
  Function(String)? onError;

  // Add WebRTC event callbacks
  Function(Map<String, dynamic>)? onWebRtcOffer;
  Function(Map<String, dynamic>)? onWebRtcAnswer;
  Function(Map<String, dynamic>)? onWebRtcIceCandidate;
  Function(Map<String, dynamic>)? onWebRtcRequestOffer;

  factory SocketService() => _instance;

  SocketService._internal();

  IO.Socket get socket => _socket;
  bool get isConnected => _isConnected;

  void connect(String userId, String userName, String email) {
    print('🔗 Connecting to SFU server: $serverUrl');

    _currentUserId = userId;

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setQuery({'userId': userId})
          .build(),
    );

    _setupEventListeners(userId, userName, email);
  }

  void _setupEventListeners(String userId, String userName, String email) {
    _socket.on('connect', (_) {
      print('✅ Connected to SFU server');
      _isConnected = true;

      // Register with server
      _socket.emit('register', {
        'userId': userId,
        'name': userName,
        'email': email,
      });

      onConnected?.call();
    });

    _socket.on('disconnect', (_) {
      print('❌ Disconnected from SFU server');
      _isConnected = false;
    });

    _socket.on('connect_error', (error) {
      print('🔴 Connection error: $error');
      onError?.call('Connection failed: $error');
    });

    _socket.on('register:success', (data) {
      print('✅ Registered successfully: $data');
    });

    // ============================================
    // CALL EVENTS (FIXED - No duplicates)
    // ============================================

    _socket.on('call:incoming', (data) {
      print('📞 Incoming call: $data');
      onCallIncoming?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('call:accepted', (data) {
      print('✅ Call accepted: $data');
      onCallAccepted?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('call:rejected', (data) {
      print('❌ Call rejected: $data');
      onCallRejected?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('call:ended', (data) {
      print('📞 Call ended: $data');
      onCallEnded?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('call:initiated', (data) {
      print('✅ Call initiated: $data');
      onCallInitiated?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('call:failed', (data) {
      print('❌ Call failed: ${data['reason']}');
      onCallFailed?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('call:busy', (data) {
      print('⏳ User busy: ${data['reason']}');
      onCallBusy?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('call:missed', (data) {
      print('⏰ Call missed: ${data['reason']}');
      // Add this callback if needed
      // onCallMissed?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('call:timeout', (data) {
      print('⏰ Call timeout');
      // Add this callback if needed
      // onCallTimeout?.call(Map<String, dynamic>.from(data));
    });

    // ============================================
    // WEBRTC SIGNALING EVENTS
    // ============================================

    _socket.on('webrtc:offer', (data) {
      print('📥 Received WebRTC offer: $data');
      onWebRtcOffer?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('webrtc:answer', (data) {
      print('📥 Received WebRTC answer: $data');
      onWebRtcAnswer?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('webrtc:ice-candidate', (data) {
      print('🧊 Received ICE candidate: $data');
      onWebRtcIceCandidate?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('webrtc:request-offer', (data) {
      print('🔄 Requesting offer resend: $data');
      onWebRtcRequestOffer?.call(Map<String, dynamic>.from(data));
    });

    // ============================================
    // WEBRTC ERROR EVENTS (ADD THIS)
    // ============================================

    _socket.on('webrtc:error', (data) {
      print('❌ WebRTC error: $data');
      onError?.call('WebRTC error: ${data['message']}');
    });

    // ============================================
    // QUEUE EVENTS (ADD THESE IF USING CALL QUEUE)
    // ============================================

    _socket.on('queue:updated', (data) {
      print('📋 Call queue updated: $data');
      // Add this callback if needed
      // onQueueUpdated?.call(Map<String, dynamic>.from(data));
    });

    _socket.on('queue:nextCaller', (data) {
      print('📞 Next caller in queue: $data');
      // Add this callback if needed
      // onQueueNextCaller?.call(Map<String, dynamic>.from(data));
    });
  }

  // WebRTC Signaling Methods
  void sendWebRtcOffer({
    required String roomId,
    required Map<String, dynamic> offer,
    required String callerId,
    required String receiverId,
  }) {
    if (!_isConnected) return;

    print('📤 Sending WebRTC offer for room: $roomId');
    _socket.emit('webrtc:offer', {
      'roomId': roomId,
      'offer': offer,
      'callerId': callerId,
      'receiverId': receiverId,
    });
  }

  void sendWebRtcAnswer({
    required String roomId,
    required Map<String, dynamic> answer,
    required String receiverId,
    required String callerId,
  }) {
    if (!_isConnected) return;

    print('📤 Sending WebRTC answer for room: $roomId');
    _socket.emit('webrtc:answer', {
      'roomId': roomId,
      'answer': answer,
      'receiverId': receiverId,
      'callerId': callerId,
    });
  }

  void sendIceCandidate({
    required String roomId,
    required Map<String, dynamic> candidate,
    required String senderId,
  }) {
    if (!_isConnected) return;

    _socket.emit('webrtc:ice-candidate', {
      'roomId': roomId,
      'candidate': candidate,
      'senderId': senderId,
    });
  }

  void requestOffer({
    required String roomId,
    required String receiverId,
  }) {
    if (!_isConnected) return;

    _socket.emit('webrtc:request-offer', {
      'roomId': roomId,
      'receiverId': receiverId,
    });
  }

  void initiateCall({
    required String callerId,
    required String callerName,
    required String receiverId,
    required String receiverName,
    required bool isVideoCall,
  }) {
    if (!_isConnected) {
      onError?.call('Not connected to server');
      return;
    }

    print('📞 Initiating call to $receiverName');

    _socket.emit('call:initiate', {
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'isVideoCall': isVideoCall,
    });
  }

  void acceptCall({
    required String callerId,
    required String receiverId,
    required String receiverName,
    required String roomId,
    required bool isVideoCall,
  }) {
    print('✅ Accepting call in room: $roomId');

    _socket.emit('call:accept', {
      'callerId': callerId,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'roomId': roomId,
      'isVideoCall': isVideoCall,
    });
  }

  void rejectCall({
    required String callerId,
    required String receiverId,
    required String roomId,
    required bool isVideoCall,
  }) {
    print('❌ Rejecting call from $callerId');

    _socket.emit('call:reject', {
      'callerId': callerId,
      'receiverId': receiverId,
      'roomId': roomId,
      'isVideoCall': isVideoCall,
    });
  }

  void endCall({
    required String callerId,
    required String receiverId,
    required String roomId,
    required int duration,
    required bool isVideoCall,
  }) {
    print('📞 Ending call in room: $roomId');

    _socket.emit('call:end', {
      'callerId': callerId,
      'receiverId': receiverId,
      'roomId': roomId,
      'duration': duration,
      'isVideoCall': isVideoCall,
    });
  }

  void disconnect() {
    _socket.disconnect();
    _isConnected = false;
  }
}