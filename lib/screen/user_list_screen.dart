// users_list_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../service/socket_service.dart';
import 'video_call_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SocketService _socketService = SocketService();

  String? _currentUserName;
  String _userStatus = 'ONLINE';
  Map<String, dynamic>? _incomingCallData;

  // Add missing socket event callbacks
  Function(Map<String, dynamic>)? onCallInitiated;
  Function(Map<String, dynamic>)? onCallBusy;
  Function(Map<String, dynamic>)? onCallFailed;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser().then((_) {
      _initializeSocket();
    });
  }

  void _initializeSocket() {
    final user = _auth.currentUser;
    if (user != null) {
      _socketService.connect(
        user.uid,
        _currentUserName ?? user.displayName ?? 'User',
        user.email ?? '',
      );

      // Setup socket listeners
      _socketService.onCallIncoming = (data) {
        _handleIncomingCall(data);
      };

      _socketService.onCallAccepted = (data) {
        _handleCallAccepted(data);
      };

      _socketService.onCallRejected = (data) {
        _showSnackBar('Call rejected: ${data['reason']}');
        setState(() => _userStatus = 'ONLINE');
      };

      _socketService.onCallEnded = (data) {
        print('📞 Call ended remotely');
        setState(() => _userStatus = 'ONLINE');
      };

      _socketService.onCallInitiated = (data) {
        print('✅ Call initiated successfully: $data');

        final roomId = data['roomId'];
        final receiverId = data['receiverId'];

        if (roomId != null) {
          // ✅ Now navigate to call screen with the server-provided room ID
          _navigateToCallScreen(
            roomId: roomId,
            isVideo: true, // or use the actual value
            isJoining: false,
            receiverName: 'Connecting...', // We might not have this yet
            callerId: receiverId,
          );
        } else {
          print('❌ No room ID received from server');
          setState(() => _userStatus = 'ONLINE');
          _showSnackBar('Failed to start call: no room ID');
        }
      };

      _socketService.onCallBusy = (data) {
        print('⏳ User busy: ${data['reason']}');
        setState(() => _userStatus = 'ONLINE');
        _showSnackBar('User is busy: ${data['reason']}');
      };

      _socketService.onCallFailed = (data) {
        print('❌ Call failed: ${data['reason']}');
        setState(() => _userStatus = 'ONLINE');
        _showSnackBar('Call failed: ${data['reason']}');
      };

      _socketService.onError = (error) {
        _showSnackBar(error);
      };

      _socketService.onConnected = () {
        print('✅ Socket connected successfully');
      };
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (mounted && doc.exists) {
          setState(() {
            _currentUserName = doc.data()?['name'] ?? user.displayName ?? 'User';
          });
        } else {
          setState(() {
            _currentUserName = user.displayName ?? 'User';
          });
        }
      } catch (e) {
        print('Error loading user: $e');
        setState(() {
          _currentUserName = user.displayName ?? 'User';
        });
      }
    }
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      _incomingCallData = data;
      _userStatus = 'RINGING';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingCallDialog(
        callerName: data['callerName'] ?? 'Unknown',
        isVideo: data['isVideoCall'] ?? false,
        onAccept: () {
          Navigator.of(context).pop();
          _acceptCall(data);
        },
        onReject: () {
          Navigator.of(context).pop();
          _rejectCall(data);
        },
      ),
    );
  }

  void _acceptCall(Map<String, dynamic> data) {
    final user = _auth.currentUser;
    if (user == null) return;

    _socketService.acceptCall(
      callerId: data['callerId'],
      receiverId: user.uid,
      receiverName: _currentUserName ?? 'User',
      roomId: data['roomId'],
      isVideoCall: data['isVideoCall'] ?? false,
    );

    // Navigate to call screen as receiver (joining)
    _navigateToCallScreen(
      roomId: data['roomId'],
      isVideo: data['isVideoCall'] ?? false,
      isJoining: true,
      receiverName: data['callerName'] ?? 'Unknown',
      callerId: data['callerId'],
    );

    setState(() {
      _userStatus = 'IN_CALL';
      _incomingCallData = null;
    });
  }

  void _rejectCall(Map<String, dynamic> data) {
    final user = _auth.currentUser;
    if (user == null) return;

    _socketService.rejectCall(
      callerId: data['callerId'],
      receiverId: user.uid,
      roomId: data['roomId'],
      isVideoCall: data['isVideoCall'] ?? false,
    );

    setState(() {
      _userStatus = 'ONLINE';
      _incomingCallData = null;
    });
  }

  // void _initiateCall(String receiverId, String receiverName, bool isVideo) {
  //   final user = _auth.currentUser;
  //   if (user == null) return;
  //
  //   if (_userStatus != 'ONLINE') {
  //     _showSnackBar('You are already in a call');
  //     return;
  //   }
  //
  //   setState(() => _userStatus = 'RINGING');
  //
  //   // Generate room ID
  //   final roomId = 'room_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString()}';
  //
  //   print('📞 Calling $receiverName (${isVideo ? 'video' : 'audio'}) in room: $roomId');
  //
  //   // Navigate to call screen immediately as caller (creating)
  //   _navigateToCallScreen(
  //     roomId: roomId,
  //     isVideo: isVideo,
  //     isJoining: false,
  //     receiverName: receiverName,
  //     callerId: receiverId,
  //   );
  //
  //   // Initiate call through socket
  //   _socketService.initiateCall(
  //     callerId: user.uid,
  //     callerName: _currentUserName ?? 'User',
  //     receiverId: receiverId,
  //     receiverName: receiverName,
  //     isVideoCall: isVideo,
  //   );
  //
  //   // Set timeout for call initiation
  //   _setCallInitiationTimeout();
  // }

  void _initiateCall(String receiverId, String receiverName, bool isVideo) {
    final user = _auth.currentUser;
    if (user == null) return;

    // if (_userStatus != 'ONLINE') {
    //   _showSnackBar('You are already in a call');
    //   return;
    // }

    setState(() => _userStatus = 'RINGING');

    // ✅ FIX: Remove local room ID generation - let the server handle it
    // The server will generate the room ID and send it back in call:initiated

    print('📞 Calling $receiverName (${isVideo ? 'video' : 'audio'})');

    // ✅ FIX: Don't navigate immediately - wait for server confirmation
    // Initiate call through socket first
    _socketService.initiateCall(
      callerId: user.uid,
      callerName: _currentUserName ?? 'User',
      receiverId: receiverId,
      receiverName: receiverName,
      isVideoCall: isVideo,
    );

    // Set timeout for call initiation
    _setCallInitiationTimeout();
  }

  void _handleCallInitiated(Map<String, dynamic> data, String userId) {
    // This is called when the server confirms call initiation
    print('✅ Server confirmed call initiation: $data');

    // We don't need to navigate here since we already navigated in _initiateCall
    // This is just for confirmation
  }

  void _handleCallAccepted(Map<String, dynamic> data) {
    if (!mounted) return;

    print('✅ Call accepted by remote user: $data');

    // We're already in the call screen, just update status
    setState(() => _userStatus = 'IN_CALL');
  }

  void _navigateToCallScreen({
    required String roomId,
    required bool isVideo,
    required bool isJoining,
    required String receiverName,
    required String callerId,
  }) {

    print('🎯 Navigating to call screen:');
    print('   Room: $roomId');
    print('   Video: $isVideo');
    print('   Joining: $isJoining');
    print('   Receiver: $receiverName');
    print('   Caller ID: $callerId');


    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          roomId: roomId,
          isVideo: isVideo,
          isJoining: isJoining,
          socketService: _socketService,
          callerId: callerId,
          receiverName: receiverName,
        ),
      ),
    ).then((_) {
      // When returning from call screen, reset status
      if (mounted) {
        setState(() => _userStatus = 'ONLINE');
      }
    });
  }

  void _setCallInitiationTimeout() {
    Future.delayed(const Duration(seconds: 250), () {
      if (_userStatus == 'RINGING' && mounted) {
        setState(() => _userStatus = 'ONLINE');
        _showSnackBar('Call initiation timeout - no response from user');
      }
    });
  }

  String _generateRandomString({int length = 6}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _logout() async {
    _socketService.disconnect();
    await _auth.signOut();
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Video Call App - ${_userStatus}'),
        backgroundColor: _getStatusColor(),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Icon(
                  _socketService.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _socketService.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _socketService.isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: _socketService.isConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // User info header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue,
                  child: Text(
                    _currentUserName!.toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentUserName ?? 'Loading...',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStatusDotColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _userStatus,
                            style: TextStyle(
                              color: _getStatusTextColor(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Users list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('uid', isNotEqualTo: currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No other users online',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData = users[index].data() as Map<String, dynamic>;
                    final userName = userData['name'] ?? 'Unknown User';
                    final userEmail = userData['email'] ?? '';
                    final userId = userData['uid'];
                    final isOnline = userData['isOnline'] ?? false;
                    final status = userData['status'] ?? 'OFFLINE';
                    final isInCall = status == 'IN_CALL' || status == 'RINGING';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                userName!.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isOnline && !isInCall)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            if (isInCall)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isOnline ? Colors.black : Colors.grey,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isInCall ? 'In Call' : (isOnline ? 'Online' : 'Offline'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isInCall ? Colors.red : (isOnline ? Colors.green : Colors.grey),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.call, color: Colors.green),
                              tooltip: 'Audio Call',
                              onPressed: (){
                                _initiateCall(userId, userName, false);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.videocam, color: Colors.blue),
                              tooltip: 'Video Call',
                              onPressed: (){
                                _initiateCall(userId, userName, true);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_userStatus) {
      case 'IN_CALL':
        return Colors.red;
      case 'RINGING':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Color _getStatusDotColor() {
    switch (_userStatus) {
      case 'IN_CALL':
        return Colors.red;
      case 'RINGING':
        return Colors.orange;
      case 'ONLINE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusTextColor() {
    switch (_userStatus) {
      case 'IN_CALL':
        return Colors.red;
      case 'RINGING':
        return Colors.orange;
      case 'ONLINE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class IncomingCallDialog extends StatefulWidget {
  final String callerName;
  final bool isVideo;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const IncomingCallDialog({
    super.key,
    required this.callerName,
    required this.isVideo,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> {
  Timer? _timer;
  int _secondsRemaining = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        widget.onReject();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Incoming ${widget.isVideo ? 'Video' : 'Audio'} Call',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isVideo ? Icons.videocam : Icons.call,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          Text(
            widget.callerName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Ringing... $_secondsRemaining s',
            style: const TextStyle(color: Colors.orange),
          ),
        ],
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.call_end, color: Colors.white),
                label: const Text('Reject', style: TextStyle(color: Colors.white)),
                onPressed: widget.onReject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.call, color: Colors.white),
                label: const Text('Accept', style: TextStyle(color: Colors.white)),
                onPressed: widget.onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}