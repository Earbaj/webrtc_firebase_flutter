import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';

/// The screen where the actual video or audio call happens.
/// It uses WebRTC for peer-to-peer communication and Firestore for signaling.
class VideoCallScreen extends StatefulWidget {
  final String roomId; // The unique ID for the WebRTC room (usually the callId).
  final bool isVideo; // Whether this is a video call or audio-only.
  final bool isJoining; // True if this user is receiving the call, false if initiating.
  final String? receiverId;
  final String? receiverName;
  final String? receiverEmail;
  final String? callerName;
  final String? callerEmail;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.isVideo,
    required this.isJoining,
    this.receiverId,
    this.receiverName,
    this.receiverEmail,
    this.callerName,
    this.callerEmail,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  // WebRTC Configuration: Uses Google's public STUN server for ICE candidate discovery.
  final Map<String, dynamic> _configuration = {
    "iceServers": [
      {"urls": "stun:stun.l.google.com:19302"},
    ]
  };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  // Renderers to display the video streams from local and remote participants.
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // UI and call state variables.
  bool _isConnected = false;
  bool _isNegotiating = false;
  bool _isMicMuted = false;
  bool _isVideoOff = false;

  // Stream subscriptions for signaling and status monitoring.
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<QuerySnapshot>? _answerCandidatesSubscription;
  StreamSubscription<QuerySnapshot>? _offerCandidatesSubscription;
  StreamSubscription<DocumentSnapshot>? _callSubscription;

  Timer? _connectionTimeout;
  Timer? _callTimer;
  int _callDuration = 0;

  // Picture-in-Picture (PiP) position and state.
  Offset _pipPosition = const Offset(20, 20);
  bool _isRemoteFull = true;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    // Crucial to stop all streams and close connections to avoid memory leaks.
    _cleanup();
    super.dispose();
  }

  /// Initial setup sequence for a WebRTC call.
  Future<void> _initializeCall() async {
    await _initializeRenderers();
    await _getUserMedia();
    await _createPeerConnection();

    if (widget.isJoining) {
      // Receiver: Set up to join the existing signaling room.
      await _joinRoom();
    } else {
      // Caller: Set up to create the signaling room and wait for an answer.
      await _createRoom();
      _listenForCallStatus();
    }
    _listenForRoomChanges();
  }

  /// Monitors the 'rooms' document in Firestore for signaling changes.
  void _listenForRoomChanges() {
    _roomSubscription = _firestore
        .collection('rooms')
        .doc(widget.roomId)
        .snapshots()
        .listen((snapshot) async {
      
      // If room is deleted, it means the other participant hung up or there was an error.
      if (!snapshot.exists && mounted) {
        _endCall();
        return;
      }

      if (mounted) {
        final data = snapshot.data();
        if (data != null) {
          // FOR CALLER: Listen for the 'answer' from the receiver.
          if (!widget.isJoining && data.containsKey('answer')) {
            final remoteDesc = await _peerConnection!.getRemoteDescription();
            if (remoteDesc == null) {
              final RTCSessionDescription answer = RTCSessionDescription(
                data['answer']['sdp'],
                data['answer']['type'],
              );
              await _peerConnection!.setRemoteDescription(answer);
              if (mounted) setState(() => _isNegotiating = false);
            }
          }

          // Check for an explicit 'ended' status.
          if (data['status'] == 'ended') {
            _endCall();
          }
        }
      }
    });
  }

  /// Monitors the 'calls' document (specifically for callers) to see if the call is rejected or accepted.
  void _listenForCallStatus() {
    // Use the roomId to find the call document created by the caller.
    _callSubscription = _firestore
        .collection('calls')
        .doc(widget.roomId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        final status = data['status'] as String?;

        if (status == 'rejected') {
          _showCallStatusDialog('Call Rejected', '${widget.receiverName} rejected the call');
        } else if (status == 'accepted') {
          print('✅ Call accepted by ${widget.receiverName}');
        }
      }
    });

    // Auto-timeout for callers if the receiver doesn't pick up within 30 seconds.
    _connectionTimeout = Timer(const Duration(seconds: 30), () {
      if (!_isConnected && mounted) {
        _showCallStatusDialog('No Answer', '${widget.receiverName} did not answer.');
      }
    });
  }

  /// Shows a blocking dialog to the user when a call status changes (rejected/timeout).
  void _showCallStatusDialog(String title, String content) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Exit call screen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Releases all WebRTC and Firestore resources.
  void _cleanup() {
    _connectionTimeout?.cancel();
    _callTimer?.cancel();
    _roomSubscription?.cancel();
    _answerCandidatesSubscription?.cancel();
    _offerCandidatesSubscription?.cancel();
    _callSubscription?.cancel();
    
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.close();

    // The caller is usually responsible for final document cleanup.
    if (!widget.isJoining) {
      _firestore.collection('calls').doc(widget.roomId).delete();
      _firestore.collection('rooms').doc(widget.roomId).delete();
    }
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  /// Accesses the local device's microphone and/or camera.
  Future<void> _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      "audio": true,
      "video": widget.isVideo
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'optional': [],
            }
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localRenderer.srcObject = _localStream;
    } catch (e) {
      log('❌ Error getting user media: $e');
    }
  }

  /// Creates a WebRTC Peer Connection and sets up event handlers.
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_configuration);

    // Triggered when the remote participant's media track is received.
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty && mounted) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          _isConnected = true;
        });
        _connectionTimeout?.cancel();
        _startCallTimer();
      }
    };

    // Triggered when a new ICE candidate is found by the local device.
    _peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate != null) {
        // We save candidates to specific collections in Firestore for the other peer to pick up.
        final collection = widget.isJoining ? 'answerCandidates' : 'offerCandidates';
        _firestore
            .collection('rooms')
            .doc(widget.roomId)
            .collection(collection)
            .add(candidate.toMap());
      }
    };

    // Track state changes of the connection.
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        setState(() => _isConnected = true);
        _startCallTimer();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
                 state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        setState(() => _isConnected = false);
      }
    };

    // Add local media tracks to the peer connection so the other participant can see/hear us.
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
    }
  }

  /// FOR CALLER: Creates the WebRTC 'Offer' and saves it to Firestore.
  Future<void> _createRoom() async {
    setState(() => _isNegotiating = true);
    try {
      final RTCSessionDescription offer = await _peerConnection!.createOffer({
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': widget.isVideo,
        },
        'optional': [],
      });
      
      await _peerConnection!.setLocalDescription(offer);

      // Save offer to Firestore as the starting point of negotiation.
      await _firestore.collection('rooms').doc(widget.roomId).update({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      });

      // Listen for ICE candidates sent by the receiver (answer).
      _answerCandidatesSubscription = _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('answerCandidates')
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data()!;
            _peerConnection!.addCandidate(RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ));
          }
        }
      });
    } catch (e) {
      log('❌ Error creating room: $e');
      if (mounted) setState(() => _isNegotiating = false);
    }
  }

  /// FOR RECEIVER: Retrieves the offer from Firestore and creates an 'Answer'.
  Future<void> _joinRoom() async {
    setState(() => _isNegotiating = true);
    try {
      final snapshot = await _firestore.collection('rooms').doc(widget.roomId).get();
      if (!snapshot.exists) throw Exception('Room not found');

      final data = snapshot.data()!;
      final RTCSessionDescription offer = RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      );

      // Set the caller's offer as the remote description.
      await _peerConnection!.setRemoteDescription(offer);

      // Listen for ICE candidates sent by the caller (offer).
      _offerCandidatesSubscription = _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('offerCandidates')
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data()!;
            _peerConnection!.addCandidate(RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ));
          }
        }
      });

      // Create an answer and set it as our local description.
      final RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Save answer to Firestore to complete the negotiation.
      await _firestore.collection('rooms').doc(widget.roomId).update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'status': 'connected',
      });

      if (mounted) setState(() => _isNegotiating = false);
    } catch (e) {
      log('❌ Error joining room: $e');
      if (mounted) setState(() => _isNegotiating = false);
    }
  }

  void _toggleMic() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final enabled = !audioTracks[0].enabled;
        audioTracks[0].enabled = enabled;
        setState(() => _isMicMuted = !enabled);
      }
    }
  }

  void _toggleVideo() {
    if (_localStream != null && widget.isVideo) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final enabled = !videoTracks[0].enabled;
        videoTracks[0].enabled = enabled;
        setState(() => _isVideoOff = !enabled);
      }
    }
  }

  void _startCallTimer() {
    if (_callTimer != null) return;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _callDuration++);
    });
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _endCall() {
    _cleanup();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // PRIMARY VIDEO: Displays remote user by default.
            Positioned.fill(
              child: RTCVideoView(
                _isRemoteFull ? _remoteRenderer : _localRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: !_isRemoteFull,
              ),
            ),

            // FALLBACK: Shown if there's no remote video stream.
            if (_isRemoteFull && _remoteRenderer.srcObject == null)
              _buildConnectingPlaceholder(),

            // PIP VIDEO: Smaller movable window showing the other track (usually self).
            if (widget.isVideo && (_localRenderer.srcObject != null || _remoteRenderer.srcObject != null))
              _buildPictureInPicture(),

            // TOP BAR: User information and timer.
            _buildTopBar(),

            // BOTTOM BAR: Mute, Video Toggle, and End Call control buttons.
            _buildControlBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingPlaceholder() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey.shade800,
              child: Icon(
                widget.isVideo ? Icons.videocam_off : Icons.call,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isJoining ? 'Connecting...' : 'Calling ${widget.receiverName}...',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            if (_isNegotiating)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPictureInPicture() {
    return Positioned(
      top: _pipPosition.dy,
      right: _pipPosition.dx,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pipPosition += Offset(-details.delta.dx, details.delta.dy);
          });
        },
        onTap: () {
          setState(() => _isRemoteFull = !_isRemoteFull);
        },
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 10)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: (_isRemoteFull && _isVideoOff)
                ? Container(color: Colors.grey.shade900, child: const Icon(Icons.videocam_off, color: Colors.white))
                : RTCVideoView(
                    _isRemoteFull ? _localRenderer : _remoteRenderer,
                    mirror: _isRemoteFull,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final displayName = (widget.isJoining ? widget.callerName : widget.receiverName) ?? 'User';
    final displayEmail = (widget.isJoining ? widget.callerEmail : widget.receiverEmail) ?? '';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(displayName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(displayEmail, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                ],
              ),
            ),
            if (_isConnected)
              _buildCallTimer()
            else
              const Text('Connecting...', style: TextStyle(color: Colors.orange, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildCallTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(15)),
      child: Text(
        _formatDuration(_callDuration),
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildControlBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: _isMicMuted ? Icons.mic_off : Icons.mic,
              label: _isMicMuted ? 'Unmute' : 'Mute',
              onPressed: _toggleMic,
              color: _isMicMuted ? Colors.red : Colors.white,
            ),
            if (widget.isVideo)
              _buildControlButton(
                icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                label: _isVideoOff ? 'Vid On' : 'Vid Off',
                onPressed: _toggleVideo,
                color: _isVideoOff ? Colors.red : Colors.white,
              ),
            _buildControlButton(
              icon: Icons.call_end,
              label: 'End',
              onPressed: _endCall,
              color: Colors.red,
              size: 70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    double size = 60,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color == Colors.red ? Colors.red : Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}