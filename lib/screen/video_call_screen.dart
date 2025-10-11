import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import '../service/socket_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final bool isVideo;
  final bool isJoining;
  final SocketService socketService;
  final String? callerId;
  final String? receiverName;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.isVideo,
    required this.isJoining,
    required this.socketService,
    this.callerId,
    this.receiverName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final Map<String, dynamic> _configuration = {
    "iceServers": [
      {"urls": "stun:stun.l.google.com:19302"},
    ],
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': 'all',
  };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isConnected = false;
  bool _isMicMuted = false;
  bool _isVideoOff = false;
  DateTime? _callStartTime;
  String _callDurationDisplay = '00:00';
  Timer? _durationTimer;
  Timer? _connectionTimeout;
  bool _isDisposed = false;
  bool _hasRemoteStream = false;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cleanup();
    super.dispose();
  }

  Future<void> _initializeCall() async {
    try {
      print('🔄 Initializing WebRTC...');
      await _initializeRenderers();
      await _getUserMedia();
      await _createPeerConnection();
      _setupSocketListeners();

      if (widget.isJoining) {
        print('📥 Joining as receiver - waiting for offer');
        _requestOffer();
      } else {
        print('📤 Creating as caller - sending offer');
        await _createAndSendOffer();
      }

      _startCallTimer();
    } catch (e) {
      print('❌ Initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _setupSocketListeners() {
    print('Setting up socket listeners...');

    // Receive offer (for receiver/callee)
    widget.socketService.onWebRtcOffer = (data) async {
      print('📥 Received WebRTC offer');
      if (data['roomId'] != widget.roomId || _peerConnection == null) return;

      try {
        final offer = RTCSessionDescription(
          data['offer']['sdp'],
          data['offer']['type'],
        );

        await _peerConnection!.setRemoteDescription(offer);
        print('✅ Set remote description (offer)');

        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        print('✅ Created answer');

        // Use the SocketService method
        widget.socketService.sendWebRtcAnswer(
          roomId: widget.roomId,
          answer: {
            'type': answer.type,
            'sdp': answer.sdp,
          },
          receiverId: _auth.currentUser!.uid,
          callerId: data['callerId'],
        );
        print('📤 Sent answer');

      } catch (e) {
        print('❌ Error handling offer: $e');
      }
    };

    // Receive answer (for caller)
    widget.socketService.onWebRtcAnswer = (data) async {
      print('📥 Received WebRTC answer');
      if (data['roomId'] != widget.roomId || _peerConnection == null) return;

      try {
        final answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );

        await _peerConnection!.setRemoteDescription(answer);
        print('✅ Set remote description (answer)');

      } catch (e) {
        print('❌ Error setting remote description: $e');
      }
    };

    // Receive ICE candidates
    widget.socketService.onWebRtcIceCandidate = (data) async {
      if (data['roomId'] != widget.roomId ||
          data['senderId'] == _auth.currentUser!.uid ||
          _peerConnection == null) return;

      try {
        final candidate = RTCIceCandidate(
          data['candidate']['candidate'],
          data['candidate']['sdpMid'],
          data['candidate']['sdpMLineIndex'],
        );
        await _peerConnection!.addCandidate(candidate);
        print('✅ Added ICE candidate');
      } catch (e) {
        print('❌ Error adding ICE candidate: $e');
      }
    };

    // Call ended by remote user
    widget.socketService.onCallEnded = (_) {
      print('📞 Remote user ended call');
      if (mounted && !_isDisposed) {
        Navigator.pop(context);
      }
    };
  }

  void _requestOffer() {
    print('📋 Requesting offer from caller...');
    widget.socketService.requestOffer(
      roomId: widget.roomId,
      receiverId: _auth.currentUser!.uid,
    );

    _connectionTimeout = Timer(const Duration(seconds: 250), () {
      if (!_isConnected && mounted && !_isDisposed) {
        print('⏰ Timeout waiting for offer');
        _showTimeout();
      }
    });
  }

  Future<void> _createAndSendOffer() async {
    if (_isDisposed || _peerConnection == null) return;

    try {
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      print('✅ Created offer');

      // Use the SocketService method instead of direct emit
      widget.socketService.sendWebRtcOffer(
        roomId: widget.roomId,
        offer: {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        callerId: _auth.currentUser!.uid,
        receiverId: widget.callerId ?? '',
      );

      _connectionTimeout = Timer(const Duration(seconds: 250), () {
        if (!_isConnected && mounted && !_isDisposed) {
          print('⏰ Timeout waiting for answer');
          _showTimeout();
        }
      });

    } catch (e) {
      print('❌ Error creating offer: $e');
    }
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _getUserMedia() async {
    final constraints = {
      "audio": {
        "echoCancellation": true,
        "noiseSuppression": true,
        "autoGainControl": true,
      },
      "video": widget.isVideo
          ? {
        "width": {"ideal": 640},
        "height": {"ideal": 480},
        "frameRate": {"ideal": 30},
      }
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localRenderer.srcObject = _localStream;
      print('✅ Media access granted');
    } catch (e) {
      print('❌ Error getting media: $e');
      rethrow;
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(_configuration);

      if (_peerConnection == null) {
        throw Exception('Failed to create peer connection');
      }

      // Handle remote track (remote video/audio)
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('🎬 Received remote track: ${event.track.kind}');
        if (event.streams.isNotEmpty && mounted && !_isDisposed) {
          setState(() {
            _remoteRenderer.srcObject = event.streams[0];
            _hasRemoteStream = true;
            _isConnected = true;
          });
          _connectionTimeout?.cancel();
          print('✅ Remote stream connected!');
        }
      };

      // Send local ICE candidates to peer
      _peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) {
        if (candidate != null) {
          widget.socketService.sendIceCandidate(
            roomId: widget.roomId,
            candidate: {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            senderId: _auth.currentUser!.uid,
          );
        }
      };

      // Monitor ICE connection state
      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('🌐 ICE state: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          setState(() => _isConnected = true);
        }
      };

      // Add local tracks to connection
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
        print('✅ Added local tracks');
      }

      print('✅ Peer connection created');
    } catch (e) {
      print('❌ Error creating peer connection: $e');
      rethrow;
    }
  }

  void _startCallTimer() {
    _callStartTime = DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isDisposed && _callStartTime != null) {
        final duration = DateTime.now().difference(_callStartTime!);
        setState(() {
          _callDurationDisplay =
          '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
        });
      }
    });
  }

  void _cleanup() {
    _durationTimer?.cancel();
    _connectionTimeout?.cancel();

    // Clear socket callbacks
    widget.socketService.onWebRtcOffer = null;
    widget.socketService.onWebRtcAnswer = null;
    widget.socketService.onWebRtcIceCandidate = null;
    widget.socketService.onCallEnded = null;
    // Remove listeners
    widget.socketService.socket.off('webrtc:offer');
    widget.socketService.socket.off('webrtc:answer');
    widget.socketService.socket.off('webrtc:ice-candidate');
    widget.socketService.socket.off('call:ended');

    // Notify server
    if (_callStartTime != null) {
      final duration = DateTime.now().difference(_callStartTime!).inSeconds;
      widget.socketService.endCall(
        callerId: _auth.currentUser!.uid,
        receiverId: widget.callerId ?? '',
        roomId: widget.roomId,
        duration: duration,
        isVideoCall: widget.isVideo,
      );
    }

    // Stop tracks
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();

    _peerConnection?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  void _toggleMic() {
    if (_localStream == null) return;
    setState(() => _isMicMuted = !_isMicMuted);
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = !_isMicMuted;
    });
  }

  void _toggleVideo() {
    if (_localStream == null || !widget.isVideo) return;
    setState(() => _isVideoOff = !_isVideoOff);
    _localStream!.getVideoTracks().forEach((track) {
      track.enabled = !_isVideoOff;
    });
  }

  void _showTimeout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Timeout'),
        content: const Text('Failed to establish connection'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video
            // Remote video (full screen)
            Positioned.fill(
              child: _hasRemoteStream && widget.isVideo && !_isVideoOff
                  ? Stack(
                children: [
                  RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  ),
                  // Debug overlay
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black54,
                      child: Text(
                        'Remote: ${_remoteRenderer.srcObject != null ? "Active" : "Null"}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              )
                  : _buildAudioView(),
            ),
            // Positioned.fill(
            //   child: _hasRemoteStream && widget.isVideo && !_isVideoOff
            //       ? RTCVideoView(
            //     _remoteRenderer,
            //     objectFit:
            //     RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            //   )
            //       : _buildAudioView(),
            // ),

            // Local video (PiP)
            if (widget.isVideo && !_isVideoOff && _localStream != null)
              Positioned(
                top: 60,
                right: 20,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Call info
            Positioned(
              top: 60,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.receiverName ?? 'Connecting...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isConnected ? _callDurationDisplay : 'Connecting...',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            // Controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute
                  FloatingActionButton(
                    onPressed: _toggleMic,
                    backgroundColor:
                    _isMicMuted ? Colors.red : Colors.blue,
                    child: Icon(
                      _isMicMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                    ),
                  ),

                  // End call
                  FloatingActionButton(
                    onPressed: () => Navigator.pop(context),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),

                  // Toggle video
                  if (widget.isVideo)
                    FloatingActionButton(
                      onPressed: _toggleVideo,
                      backgroundColor:
                      _isVideoOff ? Colors.red : Colors.blue,
                      child: Icon(
                        _isVideoOff ? Icons.videocam_off : Icons.videocam,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioView() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[700],
              child: const Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              widget.receiverName ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isConnected ? _callDurationDisplay : 'Connecting...',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}