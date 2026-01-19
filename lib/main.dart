import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:webrtc_flutter/screen/auth_screen.dart';
import 'package:webrtc_flutter/screen/user_list_screen.dart';
import 'package:webrtc_flutter/screen/video_call_screen.dart';

import 'controller/auth_controller_riverpod.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter WebRTC Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthWrapper(),
      routes: {
        '/video_call': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return VideoCallScreen(
            roomId: args['roomId'],
            isVideo: args['isVideo'],
            isJoining: args['isJoining'],
            receiverId: args['receiverId'],
            receiverName: args['receiverName'],
            receiverEmail: args['receiverEmail'],
            callerName: args['callerName'],
            callerEmail: args['callerEmail'],
          );
        },
      },
    );
  }
}


//auth wrapper in traditional way
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          // User is logged in
          return const UsersListScreen();
        } else {
          // User is not logged in
          return const AuthScreen();
        }
      },
    );
  }
}

// auth_wrapper from river pod way
class RiverPodAuthWrapper extends ConsumerWidget {
  const RiverPodAuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
      data: (user) {
        return user == null ? const AuthScreen() : const UsersListScreen();
      },
    );
  }
}

// class VideoCallScreen extends StatefulWidget {
//   const VideoCallScreen({super.key});
//
//   @override
//   State<VideoCallScreen> createState() => _VideoCallScreenState();
// }
//
// class _VideoCallScreenState extends State<VideoCallScreen> {
//   final Map<String, dynamic> _configuration = {
//     "iceServers": [
//       {"urls": "stun:stun.l.google.com:19302"},
//     ]
//   };
//
//   RTCPeerConnection? _peerConnection;
//   MediaStream? _localStream;
//   final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
//   final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
//
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   String? _currentRoomId;
//   bool _isNegotiating = false;
//   StreamSubscription<DocumentSnapshot>? _roomSubscription;
//   StreamSubscription<QuerySnapshot>? _answerCandidatesSubscription;
//   StreamSubscription<QuerySnapshot>? _offerCandidatesSubscription;
//
//   final TextEditingController _roomIdController = TextEditingController();
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeRenderers();
//     _initializePeerConnection();
//   }
//
//   @override
//   void dispose() {
//     _cleanup();
//     super.dispose();
//   }
//
//   void _cleanup() {
//     _cleanupSubscriptions();
//     _localRenderer.dispose();
//     _remoteRenderer.dispose();
//     _roomIdController.dispose();
//     _localStream?.dispose();
//     _peerConnection?.close();
//   }
//
//   void _cleanupSubscriptions() {
//     _roomSubscription?.cancel();
//     _answerCandidatesSubscription?.cancel();
//     _offerCandidatesSubscription?.cancel();
//   }
//
//   Future<void> _initializeRenderers() async {
//     await _localRenderer.initialize();
//     await _remoteRenderer.initialize();
//   }
//
//   Future<void> _initializePeerConnection() async {
//     await _getUserMedia();
//     await _createNewPeerConnection();
//   }
//
//   Future<void> _createNewPeerConnection() async {
//     // Close existing connection if any
//     _peerConnection?.close();
//
//     // Create new peer connection
//     _peerConnection = await createPeerConnection(_configuration);
//
//     // Set up event handlers
//     _peerConnection!.onTrack = (RTCTrackEvent event) {
//       print('🎬 Remote track received');
//       if (event.streams.isNotEmpty && mounted) {
//         setState(() {
//           _remoteRenderer.srcObject = event.streams[0];
//         });
//       }
//     };
//
//     _peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) {
//       if (candidate != null && _currentRoomId != null) {
//         print('📤 Sending ICE candidate');
//         _firestore
//             .collection('rooms')
//             .doc(_currentRoomId)
//             .collection('offerCandidates')
//             .add(candidate.toMap());
//       }
//     };
//
//     _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
//       print('🌐 ICE connection state: $state');
//     };
//
//     _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
//       print('🔗 Peer connection state: $state');
//     };
//
//     // Add local tracks to the new connection
//     if (_localStream != null) {
//       _localStream!.getTracks().forEach((track) {
//         _peerConnection?.addTrack(track, _localStream!);
//       });
//     }
//   }
//
//   Future<void> _getUserMedia() async {
//     final Map<String, dynamic> constraints = {
//       "audio": true,
//       "video": {
//         'mandatory': {
//           'minWidth': '640',
//           'minHeight': '480',
//           'minFrameRate': '30',
//         },
//         'optional': [],
//       }
//     };
//
//     try {
//       _localStream = await navigator.mediaDevices.getUserMedia(constraints);
//       _localRenderer.srcObject = _localStream;
//       print('🎥 Camera and microphone accessed successfully');
//     } catch (e) {
//       print('❌ Error getting user media: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Camera/microphone access failed: $e')),
//         );
//       }
//     }
//   }
//
//   // === CALLER: Create a new room ===
//   Future<void> _createRoom() async {
//     if (_isNegotiating) {
//       print('Already negotiating, skipping createRoom');
//       return;
//     }
//
//     _cleanupSubscriptions();
//     await _createNewPeerConnection(); // Fresh connection for new call
//
//     final roomRef = _firestore.collection('rooms').doc();
//     final roomId = roomRef.id;
//
//     setState(() {
//       _currentRoomId = roomId;
//       _isNegotiating = true;
//     });
//
//     print('=== CREATING ROOM ===');
//     print('Room ID: $roomId');
//     print('=====================');
//
//     try {
//       // Create offer with proper constraints
//       final Map<String, dynamic> offerConstraints = {
//         'mandatory': {
//           'OfferToReceiveAudio': true,
//           'OfferToReceiveVideo': true,
//         },
//         'optional': [],
//       };
//
//       final RTCSessionDescription offer = await _peerConnection!.createOffer(offerConstraints);
//
//       // Set local description first
//       await _peerConnection!.setLocalDescription(offer);
//       print('✅ Local description set');
//
//       // Save to Firestore
//       final roomData = {
//         'offer': {
//           'type': offer.type,
//           'sdp': offer.sdp,
//         },
//         'createdAt': FieldValue.serverTimestamp(),
//         'status': 'waiting',
//       };
//
//       await roomRef.set(roomData);
//       print('✅ Room saved to Firestore');
//
//       // Listen for answer
//       _roomSubscription = roomRef.snapshots().listen((snapshot) async {
//         if (snapshot.exists && mounted) {
//           final data = snapshot.data()!;
//           if (data.containsKey('answer')) {
//             print('🎯 Answer received from remote peer');
//
//             // Check if we already processed this answer
//             final remoteDesc = await _peerConnection!.getRemoteDescription();
//             if (remoteDesc == null) {
//               final RTCSessionDescription answer = RTCSessionDescription(
//                 data['answer']['sdp'],
//                 data['answer']['type'],
//               );
//
//               try {
//                 await _peerConnection!.setRemoteDescription(answer);
//                 print('✅ Remote description set successfully');
//
//                 if (mounted) {
//                   setState(() {
//                     _isNegotiating = false;
//                   });
//                 }
//               } catch (e) {
//                 print('❌ Error setting remote description: $e');
//               }
//             }
//           }
//         }
//       });
//
//       // Listen for answer ICE candidates
//       _answerCandidatesSubscription = roomRef.collection('answerCandidates').snapshots().listen((snapshot) {
//         for (var change in snapshot.docChanges) {
//           if (change.type == DocumentChangeType.added) {
//             final candidateData = change.doc.data()!;
//             try {
//               _peerConnection!.addCandidate(RTCIceCandidate(
//                 candidateData['candidate'],
//                 candidateData['sdpMid'],
//                 candidateData['sdpMLineIndex'],
//               ));
//               print('✅ Added answer ICE candidate');
//             } catch (e) {
//               print('❌ Error adding ICE candidate: $e');
//             }
//           }
//         }
//       });
//
//       // Auto timeout after 60 seconds
//       Future.delayed(const Duration(seconds: 60), () {
//         if (_isNegotiating && mounted) {
//           print('⏰ Room creation timeout - no one joined');
//           setState(() {
//             _isNegotiating = false;
//           });
//
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('No one joined the room. Try creating a new room.')),
//           );
//         }
//       });
//
//     } catch (e) {
//       print('❌ Error in createRoom: $e');
//       if (mounted) {
//         setState(() {
//           _isNegotiating = false;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to create room: $e')),
//         );
//       }
//     }
//   }
//
//   // === CALLEE: Join an existing room ===
//   Future<void> _joinRoom() async {
//     final String roomId = _roomIdController.text.trim();
//     if (roomId.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please enter a room ID')),
//       );
//       return;
//     }
//
//     if (_isNegotiating) {
//       print('Already negotiating, skipping joinRoom');
//       return;
//     }
//
//     _cleanupSubscriptions();
//     await _createNewPeerConnection(); // Fresh connection for joining
//
//     setState(() {
//       _currentRoomId = roomId;
//       _isNegotiating = true;
//     });
//
//     final roomRef = _firestore.collection('rooms').doc(roomId);
//
//     print('=== JOINING ROOM ===');
//     print('Room ID: $roomId');
//     print('====================');
//
//     try {
//       // Check if room exists first
//       final snapshot = await roomRef.get();
//
//       if (!snapshot.exists) {
//         print('❌ Room not found: $roomId');
//         if (mounted) {
//           setState(() {
//             _isNegotiating = false;
//           });
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Room not found. Please check the Room ID.')),
//           );
//         }
//         return;
//       }
//
//       final data = snapshot.data()!;
//       if (!data.containsKey('offer')) {
//         print('❌ No offer found in room: $roomId');
//         if (mounted) {
//           setState(() {
//             _isNegotiating = false;
//           });
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Invalid room. No offer found.')),
//           );
//         }
//         return;
//       }
//
//       print('✅ Room found, setting up connection...');
//
//       // Set remote description from offer FIRST
//       final RTCSessionDescription offer = RTCSessionDescription(
//         data['offer']['sdp'],
//         data['offer']['type'],
//       );
//
//       print('Setting remote description...');
//       await _peerConnection!.setRemoteDescription(offer);
//       print('✅ Remote description set');
//
//       // Listen for offer ICE candidates AFTER setting remote description
//       _offerCandidatesSubscription = roomRef.collection('offerCandidates').snapshots().listen((snapshot) {
//         for (var change in snapshot.docChanges) {
//           if (change.type == DocumentChangeType.added) {
//             final candidateData = change.doc.data()!;
//             try {
//               _peerConnection!.addCandidate(RTCIceCandidate(
//                 candidateData['candidate'],
//                 candidateData['sdpMid'],
//                 candidateData['sdpMLineIndex'],
//               ));
//               print('✅ Added offer ICE candidate');
//             } catch (e) {
//               print('❌ Error adding ICE candidate: $e');
//             }
//           }
//         }
//       });
//
//       // Create and set local description (answer)
//       final RTCSessionDescription answer = await _peerConnection!.createAnswer();
//       print('✅ Answer created');
//
//       await _peerConnection!.setLocalDescription(answer);
//       print('✅ Local description set');
//
//       // Send answer back to Firestore
//       final roomWithAnswer = {
//         'answer': {
//           'type': answer.type,
//           'sdp': answer.sdp,
//         },
//         'status': 'connected',
//       };
//
//       await roomRef.update(roomWithAnswer);
//       print('✅ Answer sent to Firestore');
//
//       // Update ICE candidate handler for answer
//       _peerConnection!.onIceCandidate = (RTCIceCandidate? candidate) {
//         if (candidate != null && _currentRoomId != null) {
//           roomRef.collection('answerCandidates').add(candidate.toMap());
//           print('📤 Sent answer ICE candidate');
//         }
//       };
//
//       if (mounted) {
//         setState(() {
//           _isNegotiating = false;
//         });
//       }
//
//       print('🎉 Successfully joined room!');
//
//     } catch (e) {
//       print('❌ Error in joinRoom: $e');
//       if (mounted) {
//         setState(() {
//           _isNegotiating = false;
//         });
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to join room: $e')),
//         );
//       }
//     }
//   }
//
//   // Clean room function
//   Future<void> _cleanupRoom() async {
//     if (_currentRoomId != null) {
//       final roomRef = _firestore.collection('rooms').doc(_currentRoomId);
//       try {
//         await roomRef.delete();
//         print('🗑️ Room cleaned up: $_currentRoomId');
//       } catch (e) {
//         print('⚠️ Error cleaning room: $e');
//       }
//     }
//   }
//
//   // Reset everything
//   Future<void> _resetConnection() async {
//     print('🔄 Resetting connection...');
//
//     _cleanupSubscriptions();
//     await _cleanupRoom();
//
//     if (mounted) {
//       setState(() {
//         _isNegotiating = false;
//         _currentRoomId = null;
//         _remoteRenderer.srcObject = null;
//       });
//     }
//
//     // Reinitialize peer connection for next call
//     await _createNewPeerConnection();
//
//     print('✅ Connection reset complete');
//   }
//
//   // Build active rooms list
//   Widget _buildActiveRoomsList() {
//     return StreamBuilder<QuerySnapshot>(
//       stream: _firestore
//           .collection('rooms')
//           .where('status', isEqualTo: 'waiting')
//           .snapshots(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) {
//           return const Card(
//             child: Padding(
//               padding: EdgeInsets.all(16.0),
//               child: Text('Loading rooms...'),
//             ),
//           );
//         }
//
//         final rooms = snapshot.data!.docs;
//         if (rooms.isEmpty) {
//           return const Card(
//             child: Padding(
//               padding: EdgeInsets.all(16.0),
//               child: Text('No active rooms available. Create one first!'),
//             ),
//           );
//         }
//
//         return Card(
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Active Rooms:',
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 ...rooms.map((room) => ListTile(
//                   title: Text(
//                     'Room: ${room.id}',
//                     style: const TextStyle(fontFamily: 'monospace'),
//                   ),
//                   trailing: ElevatedButton(
//                     onPressed: _isNegotiating ? null : () {
//                       _roomIdController.text = room.id;
//                       _joinRoom();
//                     },
//                     child: const Text('Join'),
//                   ),
//                 )).toList(),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Flutter WebRTC Video Chat'),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // Video Areas
//             Expanded(
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Card(
//                       elevation: 4,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.black,
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: RTCVideoView(_localRenderer),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Card(
//                       elevation: 4,
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.black,
//                           borderRadius: BorderRadius.circular(8),
//                           border: Border.all(
//                             color: _remoteRenderer.srcObject != null
//                                 ? Colors.green
//                                 : Colors.grey,
//                             width: 2,
//                           ),
//                         ),
//                         child: Stack(
//                           children: [
//                             RTCVideoView(_remoteRenderer),
//                             if (_remoteRenderer.srcObject == null)
//                               const Center(
//                                 child: Column(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     Icon(Icons.videocam_off, size: 50, color: Colors.grey),
//                                     SizedBox(height: 8),
//                                     Text(
//                                       'Waiting for connection...',
//                                       style: TextStyle(color: Colors.grey),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//             const SizedBox(height: 20),
//
//             // Active Rooms List
//             _buildActiveRoomsList(),
//
//             const SizedBox(height: 20),
//
//             // Room ID Input and Join Button
//             Card(
//               elevation: 2,
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: TextField(
//                         controller: _roomIdController,
//                         decoration: const InputDecoration(
//                           labelText: 'Enter Room ID to Join',
//                           border: OutlineInputBorder(),
//                           prefixIcon: Icon(Icons.meeting_room),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 10),
//                     ElevatedButton.icon(
//                       onPressed: _isNegotiating ? null : _joinRoom,
//                       icon: const Icon(Icons.login),
//                       label: const Text('Join Room'),
//                       style: ElevatedButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//
//             const SizedBox(height: 20),
//
//             // Action Buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _isNegotiating ? null : _createRoom,
//                   icon: const Icon(Icons.add),
//                   label: const Text('Create Room'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//                   ),
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: _resetConnection,
//                   icon: const Icon(Icons.call_end),
//                   label: const Text('Hang Up'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//                   ),
//                 ),
//               ],
//             ),
//
//             // Status Information
//             if (_currentRoomId != null) ...{
//               const SizedBox(height: 20),
//               Card(
//                 color: Colors.blue[50],
//                 child: Padding(
//                   padding: const EdgeInsets.all(12.0),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Icon(Icons.info, color: Colors.blue),
//                       const SizedBox(width: 8),
//                       Text(
//                         'Room ID: $_currentRoomId',
//                         style: const TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.blue,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             },
//
//             // Loading Indicator
//             if (_isNegotiating) ...{
//               const SizedBox(height: 20),
//               Card(
//                 color: Colors.orange[50],
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     children: [
//                       const CircularProgressIndicator(),
//                       const SizedBox(height: 16),
//                       const Text(
//                         'Establishing Connection...',
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           color: Colors.orange,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       const Text(
//                         'Please wait while we connect you to the other peer',
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 16),
//                       ElevatedButton(
//                         onPressed: _resetConnection,
//                         child: const Text('Cancel Connection'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.red,
//                           foregroundColor: Colors.white,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             },
//           ],
//         ),
//       ),
//     );
//   }
// }