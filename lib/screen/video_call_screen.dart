import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final bool isVideo;
  final bool isJoining;
  final String? receiverId;
  final String? receiverName;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.isVideo,
    required this.isJoining,
    this.receiverId,
    this.receiverName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final Map<String, dynamic> _configuration = {
    "iceServers": [
      {"urls": "stun:stun.l.google.com:19302"},
    ]
  };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isConnected = false;
  bool _isNegotiating = false;
  bool _isMicMuted = false;
  bool _isVideoOff = false;

  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<QuerySnapshot>? _answerCandidatesSubscription;
  StreamSubscription<QuerySnapshot>? _offerCandidatesSubscription;
  StreamSubscription<DocumentSnapshot>? _callSubscription;

  Timer? _connectionTimeout;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  Future<void> _initializeCall() async {
    await _initializeRenderers();
    await _getUserMedia();
    await _createPeerConnection();

    if (widget.isJoining) {
      // Joining existing call
      await _joinRoom();
    } else {
      // Creating new call
      await _createRoom();
      _listenForCallStatus();
    }
    _listenForRoomChanges();
  }

  void _listenForRoomChanges() {
    _roomSubscription = _firestore
        .collection('rooms')
        .doc(widget.roomId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists && mounted) {
        print('🚪 Room deleted, ending call');
        _endCall();
        return;
      }

      if (mounted) {
        final data = snapshot.data();
        if (data != null) {
          // For caller: listen for answer
          if (!widget.isJoining && data.containsKey('answer')) {
            final remoteDesc = await _peerConnection!.getRemoteDescription();
            if (remoteDesc == null) {
              final RTCSessionDescription answer = RTCSessionDescription(
                data['answer']['sdp'],
                data['answer']['type'],
              );

              await _peerConnection!.setRemoteDescription(answer);
              print('✅ Remote description set');

              if (mounted) {
                setState(() => _isNegotiating = false);
              }
            }
          }

          // Also check for explicit ended status
          if (data['status'] == 'ended') {
            _endCall();
          }
        }
      }
    });
  }

  void _listenForCallStatus() {
    if (widget.receiverId != null) {
      _callSubscription = _firestore
          .collection('calls')
          .doc(widget.receiverId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data()!;
          final status = data['status'] as String?;

          if (status == 'rejected') {
            _showCallRejected();
          } else if (status == 'accepted') {
            print('✅ Call accepted by ${widget.receiverName}');
          }
        }
      });

      // Auto timeout after 30 seconds if not accepted
      _connectionTimeout = Timer(const Duration(seconds: 30), () {
        if (!_isConnected && mounted) {
          _showCallTimeout();
        }
      });
    }
  }

  void _showCallRejected() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Call Rejected'),
          content: Text('${widget.receiverName} rejected the call'),
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
  }

  void _showCallTimeout() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('No Answer'),
          content: Text('${widget.receiverName} did not answer'),
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
  }

  void _cleanup() {
    _connectionTimeout?.cancel();
    _roomSubscription?.cancel();
    _answerCandidatesSubscription?.cancel();
    _offerCandidatesSubscription?.cancel();
    _callSubscription?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.close();

    // Clean up call document
    if (widget.receiverId != null && !widget.isJoining) {
      _firestore.collection('calls').doc(widget.receiverId).delete();
    }

    // Clean up room
    _firestore.collection('rooms').doc(widget.roomId).delete();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

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
      print('🎥 Media accessed successfully');
    } catch (e) {
      print('❌ Error getting user media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Media access failed: $e')),
        );
      }
    }
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      print('🎬 Remote track received');
      if (event.streams.isNotEmpty && mounted) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          _isConnected = true;
        });
        _connectionTimeout?.cancel();
      }
    };

    _peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) {
      if (candidate != null) {
        print('📤 Sending ICE candidate');
        final collection = widget.isJoining ? 'answerCandidates' : 'offerCandidates';
        _firestore
            .collection('rooms')
            .doc(widget.roomId)
            .collection(collection)
            .add(candidate.toMap());
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      print('🌐 ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        setState(() => _isConnected = true);
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        setState(() => _isConnected = false);
      }
    };

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
    }
  }

  Future<void> _createRoom() async {
    setState(() => _isNegotiating = true);

    try {
      final Map<String, dynamic> offerConstraints = {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': widget.isVideo,
        },
        'optional': [],
      };

      final RTCSessionDescription offer =
      await _peerConnection!.createOffer(offerConstraints);
      await _peerConnection!.setLocalDescription(offer);

      await _firestore.collection('rooms').doc(widget.roomId).update({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      });

      print('✅ Offer created and saved');

      print('✅ Offer created and saved');
    } catch (e) {

      // Listen for answer ICE candidates
      _answerCandidatesSubscription = _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('answerCandidates')
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final candidateData = change.doc.data()!;
            _peerConnection!.addCandidate(RTCIceCandidate(
              candidateData['candidate'],
              candidateData['sdpMid'],
              candidateData['sdpMLineIndex'],
            ));
            print('✅ Added answer ICE candidate');
          }
        }
      });
    } catch (e) {
      print('❌ Error creating room: $e');
      if (mounted) {
        setState(() => _isNegotiating = false);
      }
    }
  }

  Future<void> _joinRoom() async {
    setState(() => _isNegotiating = true);

    try {
      final roomSnapshot =
      await _firestore.collection('rooms').doc(widget.roomId).get();

      if (!roomSnapshot.exists) {
        throw Exception('Room not found');
      }

      final data = roomSnapshot.data()!;
      final RTCSessionDescription offer = RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      );

      await _peerConnection!.setRemoteDescription(offer);
      print('✅ Remote description set');

      // Listen for offer ICE candidates
      _offerCandidatesSubscription = _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('offerCandidates')
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final candidateData = change.doc.data()!;
            _peerConnection!.addCandidate(RTCIceCandidate(
              candidateData['candidate'],
              candidateData['sdpMid'],
              candidateData['sdpMLineIndex'],
            ));
            print('✅ Added offer ICE candidate');
          }
        }
      });

      final RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      await _firestore.collection('rooms').doc(widget.roomId).update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'status': 'connected',
      });

      print('✅ Answer sent');

      if (mounted) {
        setState(() => _isNegotiating = false);
      }
    } catch (e) {
      print('❌ Error joining room: $e');
      if (mounted) {
        setState(() => _isNegotiating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join: $e')),
        );
      }
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

  void _endCall() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote Video (Full Screen)
            if (_remoteRenderer.srcObject != null)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              Container(
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      if (_isNegotiating)
                        const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),

            // Local Video (Picture-in-Picture)
            if (widget.isVideo && _localRenderer.srcObject != null)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _isVideoOff
                        ? Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Icon(
                          Icons.videocam_off,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    )
                        : RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // Top Bar - User Info
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    if (!widget.isJoining) ...[
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          widget.receiverName?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.receiverName ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _isConnected ? 'Connected' : 'Connecting...',
                            style: TextStyle(
                              color: _isConnected ? Colors.green : Colors.orange,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute/Unmute Mic
                    _buildControlButton(
                      icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                      label: _isMicMuted ? 'Unmute' : 'Mute',
                      onPressed: _toggleMic,
                      color: _isMicMuted ? Colors.red : Colors.white,
                    ),

                    // Toggle Video (only for video calls)
                    if (widget.isVideo)
                      _buildControlButton(
                        icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                        label: _isVideoOff ? 'Video On' : 'Video Off',
                        onPressed: _toggleVideo,
                        color: _isVideoOff ? Colors.red : Colors.white,
                      ),

                    // End Call
                    _buildControlButton(
                      icon: Icons.call_end,
                      label: 'End Call',
                      onPressed: _endCall,
                      color: Colors.red,
                      size: 70,
                    ),
                  ],
                ),
              ),
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(size / 2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color == Colors.red
                    ? Colors.red
                    : Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: size * 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}