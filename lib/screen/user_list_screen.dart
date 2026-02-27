import 'dart:developer';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:webrtc_flutter/notification_service.dart';
import 'package:webrtc_flutter/api_server_key.dart';

import '../fcm_service.dart';

/// The main screen displaying a list of users to call.
/// It also handles listening for and responding to incoming calls.
class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  // Subscription to the Firestore 'calls' collection to listen for incoming calls.
  StreamSubscription<QuerySnapshot>? _callStream;

  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    // Add observer to detect when the app goes to background or resumes.
    WidgetsBinding.instance.addObserver(this);
    
    // Set user as online when the screen is first loaded.
    _setUserOnline(true);
    _loadCurrentUserName();
    
    // Start listening for ringing calls targeted at the current user.
    _listenForIncomingCalls();
  }

  @override
  void dispose() {
    // Clean up observers and streams.
    WidgetsBinding.instance.removeObserver(this);
    _setUserOnline(false);
    _callStream?.cancel();
    super.dispose();
  }

  /// Triggered whenever the app's lifecycle state changes (e.g., background vs foreground).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setUserOnline(true);
    } else {
      // Set offline if the app is paused or inactive.
      _setUserOnline(false);
    }
  }

  /// Fetches the current user's name from Firestore and saves it in state.
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

  /// Updates the user's online status and FCM token in Firestore.
  void _setUserOnline(bool isOnline) async {
    if (_auth.currentUser != null) {
      String deviceToken = await _notificationService.getDeviceToken();
      _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'fcmToken': deviceToken,
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((e) => log('Error updating online status: $e'));
    }
  }

  /// Establishes a real-time listener for any 'ringing' call entries in Firestore 
  /// where the 'receiverId' matches the current user.
  void _listenForIncomingCalls() {
    final currentUserId = _auth.currentUser!.uid;

    _callStream = _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) async {

      if (snapshot.docs.isNotEmpty){
        // A new ringing call is detected. Use the document data to show the dialog.
        final callDoc = snapshot.docs.first;
        final callData = callDoc.data();
        final uniqueCallId = callData['callId'] as String;

        await FCMHandlerService.showNativeIncomingCall(
          callId: uniqueCallId,
          callerName: callData['callerName'] as String,
          callerId: callData['callerId'] as String,
          isVideo: callData['callType'] == 'video',
          roomId: callData['roomId'] as String,
          callerEmail: callData['callerEmail'] as String? ?? 'No email',
        );
        // _showIncomingCallDialog(
        //   callId: uniqueCallId,
        //   callerName: callData['callerName'] as String,
        //   callerEmail: callData['callerEmail'] as String? ?? 'No email',
        //   callerId: callData['callerId'] as String,
        //   callType: callData['callType'] as String,
        //   roomId: callData['roomId'] as String,
        // );
      } else {
        // If the call document is deleted or status changes, dismiss the dialog.
        _dismissIncomingCallDialog();
      }
    });
  }

  // Tracking for the incoming call dialog state.
  bool _isShowingIncomingDialog = false;
  BuildContext? _incomingDialogContext;

  /// Closes the incoming call dialog if it's currently visible.
  void _dismissIncomingCallDialog() {
    if (_isShowingIncomingDialog && _incomingDialogContext != null && mounted) {
      Navigator.of(_incomingDialogContext!).pop();
      _isShowingIncomingDialog = false;
      _incomingDialogContext = null;
    }
  }

  /// Displays the custom [IncomingCallDialog] to the user.
  void _showIncomingCallDialog({
    required String callId,
    required String callerName,
    required String callerEmail,
    required String callerId,
    required String callType,
    required String roomId,
  }) {
    if (_isShowingIncomingDialog) return;
    _isShowingIncomingDialog = true;

    final isVideo = callType == 'video';

    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside.
      builder: (dialogContext) {
        _incomingDialogContext = dialogContext;
        return IncomingCallDialog(
          callerName: callerName,
          isVideo: isVideo,
          onAccept: () async {
            // 1. Mark dialog as closed in local state.
            _isShowingIncomingDialog = false;
            _incomingDialogContext = null;
            
            // 2. Clear the dialog UI.
            Navigator.of(dialogContext).pop();

            // 3. Update Firestore status to notify the caller the call was accepted.
            await _firestore.collection('calls').doc(callId).update({
              'status': 'accepted',
              'acceptedAt': FieldValue.serverTimestamp(),
            });

            // 4. Navigate to the call screen to begin WebRTC signaling.
            if (mounted) {
              Navigator.of(context).pushNamed(
                '/video_call',
                arguments: {
                  'roomId': roomId,
                  'isVideo': isVideo,
                  'isJoining': true,
                  'callerName': callerName,
                  'callerEmail': callerEmail,
                },
              );
            }
          },
          onReject: () async {
            _isShowingIncomingDialog = false;
            _incomingDialogContext = null;
            Navigator.of(dialogContext).pop();

            // Notify the caller that the call was rejected.
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

  /// Creates a new call session and notifies the receiver.
  Future<void> _initiateCall({
    required String receiverId,
    required String receiverName,
    required String receiverEmail,
    required bool isVideo,
  }) async {
    if (!mounted) return;

    try {
      final currentUserId = _auth.currentUser!.uid;

      // 1. Generate a unique call ID and its corresponding document ref.
      final callDocRef = _firestore.collection('calls').doc();
      final uniqueCallId = callDocRef.id;

      // 2. Fetch the receiver's FCM token. If missing, they cannot be called.
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      final receiverToken = receiverDoc.data()?['fcmToken'] as String?;

      if (receiverToken == null || receiverToken.isEmpty) {
        log('Receiver does not have an FCM token.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User is offline or cannot receive calls.')),
          );
        }
        return;
      }

      // 3. Create a signaling room document in the 'rooms' collection.
      // This document will later hold the WebRTC offer, answer, and ICE candidates.
      final roomRef = _firestore.collection('rooms').doc(uniqueCallId);
      final roomId = roomRef.id;

      await roomRef.set({
        'callerId': currentUserId,
        'callerName': _currentUserName ?? 'Unknown',
        'receiverId': receiverId,
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Create the call tracking document in the 'calls' collection.
      // The receiver listens to changes on this specific document to see incoming calls.
      await callDocRef.set({
        'callId': uniqueCallId,
        'callerId': currentUserId,
        'callerName': _currentUserName ?? 'Unknown',
        'callerEmail': _auth.currentUser?.email ?? '',
        'receiverId': receiverId,
        'callType': isVideo ? 'video' : 'audio',
        'roomId': roomId,
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Send a push notification through FCM to wake the receiver's device.
      await _notificationService.sendCallNotification(
        receiverToken: receiverToken,
        callerName: _currentUserName ?? 'Unknown',
        callType: isVideo ? 'video' : 'audio',
        roomId: roomId,
        callerEmail: _auth.currentUser?.email ?? '',
        callerId: currentUserId,
        callId: uniqueCallId
      );

      // 6. Navigate directly to the video call screen where signaling begins.
      if (!mounted) return;
      await Navigator.of(context).pushNamed(
        '/video_call',
        arguments: {
          'roomId': roomId,
          'isVideo': isVideo,
          'isJoining': false, // Signifies that this user is the caller.
          'receiverId': receiverId,
          'receiverName': receiverName,
          'receiverEmail': receiverEmail,
        },
      );

    } catch (e) {
      log('Error initiating call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call. Please try again.')),
        );
      }
    }
  }

  /// Logs the user out of the application and clears their online status.
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
          // Header Section: Displays current user profile and Logout button.
          _buildHeader(),

          // Section Title: "Explore Users"
          _buildSectionTitle(),

          // Main List of Other Users fetched from Firestore.
          _buildUserList(currentUserId),
        ],
      ),
      // Hidden debug button to log keys/tokens.
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: () async {
          String token = await _notificationService.getDeviceToken();
          log("Debug - Device Token: $token");
        },
        child: const Icon(Icons.bug_report, size: 20),
      ),
    );
  }

  /// Modern header widget with a gradient background.
  Widget _buildHeader() {
    return Container(
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
          colors: [Colors.blue.shade600, Colors.indigo.shade700],
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
          // Title and Logout row.
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
          // User Avatar and Names.
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
    );
  }

  /// Small section title widget.
  Widget _buildSectionTitle() {
    return Padding(
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
    );
  }

  /// Stream-based user list fetched from Firestore.
  Widget _buildUserList(String currentUserId) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            // Don't show the current user in the list.
            .where('uid', isNotEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text('No other users currently online'),
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

              return _buildUserListItem(userName, userEmail, isOnline, userId);
            },
          );
        },
      ),
    );
  }

  /// Individual user card with call buttons.
  Widget _buildUserListItem(String userName, String userEmail, bool isOnline, String userId) {
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
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            // Avatar with a small green/grey online indicator.
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
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 15),
            // User Name and Email text.
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
            // Call and Video buttons.
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
    );
  }

  /// Reusable widget for audio/video call buttons.
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
      ),
    );
  }
}

/// A specialized widget to show when an incoming call is detected.
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
  int _secondsRemaining = 30; // 30-second timeout for calls.

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  /// Starts a countdown. If it reaches zero, the call is auto-rejected.
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
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
          // Visual indicator of call type.
          Icon(
            widget.isVideo ? Icons.videocam : Icons.call,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          Text(
            'Incoming ${widget.isVideo ? 'Video' : 'Audio'} Call',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            widget.callerName,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Text(
            'Ringing... $_secondsRemaining s',
            style: const TextStyle(fontSize: 14, color: Colors.orange),
          ),
          const SizedBox(height: 30),
          // Action buttons: Reject and Accept.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                onPressed: widget.onReject,
                backgroundColor: Colors.red,
                heroTag: 'reject',
                child: const Icon(Icons.call_end, color: Colors.white),
              ),
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