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
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Custom Gradient Header (Modern AppBar replacement)
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 25,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade600,
                  Colors.indigo.shade700,
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(35),
                bottomRight: Radius.circular(35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Row: App Title & Logout
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'VideoCall App',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: _logout,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                // User Profile Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        child: Text(
                          _currentUserName?.substring(0, 1).toUpperCase() ?? 'U',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _currentUserName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _auth.currentUser?.email ?? '',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Users Section Title
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 25, 25, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Explore Users',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3243),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'View All',
                    style: TextStyle(color: Colors.blue.shade600),
                  ),
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          'No other users available',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userData = users[index].data() as Map<String, dynamic>;
                    final userName = userData['name'] as String? ?? 'Unknown';
                    final userEmail = userData['email'] as String? ?? '';
                    final isOnline = userData['isOnline'] as bool? ?? false;
                    final userId = userData['uid'] as String;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {}, // Could expand for profile view
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(
                              children: [
                                // Avatar with Online Indicator
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.blue.shade50,
                                      child: Text(
                                        userName.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          color: Colors.blue.shade600,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      bottom: 2,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: isOnline ? Colors.green : Colors.grey.shade400,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2.5,
                                          ),
                                          boxShadow: [
                                            if (isOnline)
                                              BoxShadow(
                                                color: Colors.green.withOpacity(0.4),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 15),
                                // User Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: Color(0xFF2D3243),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        userEmail,
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // Call Actions
                                Row(
                                  children: [
                                    _buildActionIcon(
                                      icon: Icons.call_outlined,
                                      color: Colors.green,
                                      onPressed: () => _initiateCall(
                                        receiverId: userId,
                                        receiverName: userName,
                                        receiverEmail: userEmail,
                                        isVideo: false,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildActionIcon(
                                      icon: Icons.videocam_outlined,
                                      color: Colors.blue,
                                      onPressed: () => _initiateCall(
                                        receiverId: userId,
                                        receiverName: userName,
                                        receiverEmail: userEmail,
                                        isVideo: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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

  Widget _buildActionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        iconSize: 22,
        onPressed: onPressed,
        constraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
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