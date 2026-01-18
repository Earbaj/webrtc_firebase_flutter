import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _callSubscription;

  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUserOnline(true);
    _loadCurrentUserName();
    _listenForIncomingCalls();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnline(false);
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline(true);
    } else {
      _setUserOnline(false);
    }
  }

  Future<void> _loadCurrentUserName() async {
    final doc = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get();

    if (mounted && doc.exists) {
      setState(() {
        _currentUserName = doc.data()?['name'] ?? 'Unknown';
      });
    }
  }

  void _setUserOnline(bool isOnline) {
    if (_auth.currentUser != null) {
      _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((e) => print('Error updating online status: $e'));
    }
  }

  void _listenForIncomingCalls() {
    final currentUserId = _auth.currentUser!.uid;

    _callSubscription = _firestore
        .collection('calls')
        .doc(currentUserId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        if (!snapshot.exists) {
          // If the call document is deleted, user should no longer see the incoming call dialog
          if (Navigator.of(context).canPop()) {
            // This is a bit risky if other dialogs are open, 
            // but for this simple app it's usually the incoming call dialog.
            // A better way would be tracker for the dialog.
            _dismissIncomingCallDialog();
          }
          return;
        }

        final data = snapshot.data();
        if (data != null) {
          final status = data['status'] as String?;

          if (status == 'ringing') {
            _showIncomingCallDialog(
              callId: snapshot.id,
              callerName: data['callerName'] as String,
              callerId: data['callerId'] as String,
              callType: data['callType'] as String,
              roomId: data['roomId'] as String,
            );
          } else if (status == 'accepted' || status == 'rejected') {
            _dismissIncomingCallDialog();
          }
        }
      }
    });
  }

  // void _dismissIncomingCallDialog() {
  //   // We check if the dialog is showing.
  //   // In Flutter, there isn't a direct way to check if a specific dialog is open
  //   // without tracking the Route.
  //   // For now, we'll try to pop if it's the current route.
  //   if (mounted) {
  //     // Navigator.of(context).popUntil((route) => route.isFirst);
  //     // This is too aggressive.
  //     // Better approach: track the dialog with a boolean or a Completer.
  //   }
  // }

  // Improved dialog tracking
  bool _isShowingIncomingDialog = false;
  BuildContext? _incomingDialogContext;

  void _dismissIncomingCallDialog() {
    if (_isShowingIncomingDialog && _incomingDialogContext != null && mounted) {
      Navigator.of(_incomingDialogContext!).pop();
      _isShowingIncomingDialog = false;
      _incomingDialogContext = null;
    }
  }

  void _showIncomingCallDialog({
    required String callId,
    required String callerName,
    required String callerId,
    required String callType,
    required String roomId,
  }) {
    if (_isShowingIncomingDialog) return;
    _isShowingIncomingDialog = true;

    final isVideo = callType == 'video';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _incomingDialogContext = dialogContext;
        return IncomingCallDialog(
          callerName: callerName,
          isVideo: isVideo,
          onAccept: () async {
            _isShowingIncomingDialog = false;
            _incomingDialogContext = null;
            // Close dialog first
            Navigator.of(dialogContext).pop();

            // Update call status to accepted
            await _firestore.collection('calls').doc(callId).update({
              'status': 'accepted',
              'acceptedAt': FieldValue.serverTimestamp(),
            });

            // Navigate to video call screen using the main context
            if (mounted) {
              Navigator.of(context).pushNamed(
                '/video_call',
                arguments: {
                  'roomId': roomId,
                  'isVideo': isVideo,
                  'isJoining': true,
                },
              );
            }
          },
          onReject: () async {
            _isShowingIncomingDialog = false;
            _incomingDialogContext = null;
            // Close dialog first
            Navigator.of(dialogContext).pop();

            // Update call status to rejected
            await _firestore.collection('calls').doc(callId).update({
              'status': 'rejected',
              'rejectedAt': FieldValue.serverTimestamp(),
            });
          },
        );
      },
    ).then((_) {
      _isShowingIncomingDialog = false;
      _incomingDialogContext = null;
    });
  }

  Future<void> _initiateCall({
    required String receiverId,
    required String receiverName,
    required String receiverEmail,
    required bool isVideo,
  }) async {
    try {
      final currentUserId = _auth.currentUser!.uid;

      // Create a room first
      final roomRef = _firestore.collection('rooms').doc();
      final roomId = roomRef.id;

      await roomRef.set({
        'callerId': currentUserId,
        'callerName': _currentUserName ?? 'Unknown',
        'receiverId': receiverId,
        'receiverName': receiverName,
        'callType': isVideo ? 'video' : 'audio',
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create call notification for receiver
      await _firestore.collection('calls').doc(receiverId).set({
        'callerId': currentUserId,
        'callerName': _currentUserName ?? 'Unknown',
        'callType': isVideo ? 'video' : 'audio',
        'roomId': roomId,
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Navigate to video call screen
      if (!mounted) return;

      await Navigator.of(context).pushNamed(
        '/video_call',
        arguments: {
          'roomId': roomId,
          'isVideo': isVideo,
          'isJoining': false,
          'receiverId': receiverId,
          'receiverName': receiverName,
        },
      );
    } catch (e) {
      print('Error initiating call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate call: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    _setUserOnline(false);
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Current User Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue,
                  child: Text(
                    _currentUserName?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUserName ?? 'Loading...',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _auth.currentUser?.email ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('uid', isNotEqualTo: currentUserId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No other users available'),
                  );
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData = users[index].data() as Map<String, dynamic>;
                    final userName = userData['name'] as String? ?? 'Unknown';
                    final userEmail = userData['email'] as String? ?? '';
                    final isOnline = userData['isOnline'] as bool? ?? false;
                    final userId = userData['uid'] as String;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.blue.shade300,
                              child: Text(
                                userName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          userEmail,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Audio Call Button
                            IconButton(
                              icon: const Icon(Icons.call),
                              color: Colors.green,
                              iconSize: 28,
                              onPressed: () => _initiateCall(
                                receiverId: userId,
                                receiverName: userName,
                                receiverEmail: userEmail,
                                isVideo: false,
                              ),
                              tooltip: 'Audio Call',
                            ),
                            const SizedBox(width: 8),
                            // Video Call Button
                            IconButton(
                              icon: const Icon(Icons.videocam),
                              color: Colors.blue,
                              iconSize: 28,
                              onPressed: () => _initiateCall(
                                receiverId: userId,
                                receiverName: userName,
                                receiverEmail: userEmail,
                                isVideo: true,
                              ),
                              tooltip: 'Video Call',
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
}

// Incoming Call Dialog Widget
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
            'Incoming ${widget.isVideo ? 'Video' : 'Audio'} Call',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.callerName,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ringing... $_secondsRemaining s',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Reject Button
              FloatingActionButton(
                onPressed: widget.onReject,
                backgroundColor: Colors.red,
                heroTag: 'reject',
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
              // Accept Button
              FloatingActionButton(
                onPressed: widget.onAccept,
                backgroundColor: Colors.green,
                heroTag: 'accept',
                child: const Icon(Icons.call, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}