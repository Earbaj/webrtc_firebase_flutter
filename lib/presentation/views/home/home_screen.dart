import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webrtc_flutter/presentation/views/home/profile_screen.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/themes/colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/call_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/user_provider.dart';
import '../../router/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../widgets/user/user_list_tile.dart';
import 'calls_screen.dart';
import 'contacts_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription? _incomingCallSubscription;

  // Store instances of screens to prevent recreation
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    // Create screen instances once and reuse them
    _screens = [
      const ContactsScreen(key: Key('contacts_screen')),
      const CallsScreen(key: Key('calls_screen')),
      const ProfileScreen(key: Key('profile_screen')),
    ];

    _setupCallListeners();
  }

  void _setupCallListeners() {
    final callNotifier = ref.read(callNotifierProvider.notifier);

    // Listen for incoming calls
    final incomingCallStream = callNotifier.listenForIncomingCalls();

    _incomingCallSubscription = incomingCallStream.listen((signaling) async {
      if (signaling.isOffer && mounted) {
        // Show incoming call screen
        context.push(
          RouteNames.incomingCall,
          extra: {
            'callId': signaling.callId,
            'callType': signaling.type,
            'callerId': signaling.fromUserId,
            'callerName': 'Incoming Call', // Fetch from DB in real app
            'callerEmail': 'caller@example.com',
            'sdp': signaling.sdp,
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    super.dispose();
  }

  void _onUserTap(UserEntity user) {
    // Navigate to user profile or start chat
    // TODO: Implement user profile screen
  }

  Future<void> _onVideoCall(UserEntity user) async {
    final callNotifier = ref.read(callNotifierProvider.notifier);
    final result = await callNotifier.initiateCall(
      receiverId: user.id,
      callType: AppConstants.callTypeVideo,
    );

    result.fold(
          (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      },
          (call) {
        if (!mounted) return;
        // Navigate to call screen
        context.push(
          RouteNames.videoCall,
          extra: {
            'call': call,
            'receiver': user,
          },
        );
      },
    );
  }

  Future<void> _onAudioCall(UserEntity user) async {
    final callNotifier = ref.read(callNotifierProvider.notifier);
    final result = await callNotifier.initiateCall(
      receiverId: user.id,
      callType: AppConstants.callTypeAudio,
    );

    result.fold(
          (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      },
          (call) {
        if (!mounted) return;
        // Navigate to call screen
        context.push(
          RouteNames.audioCall,
          extra: {
            'call': call,
            'receiver': user,
          },
        );
      },
    );
  }

  void _onSignOut() async {
    final authViewModel = ref.read(authViewModelProvider);
    final result = await authViewModel.signOut();

    result.fold(
          (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      },
          (_) {
        // Sign out successful, router will handle navigation
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'WebRTC Call',
          style: TextStyles.h2,
        ),
        actions: [
          // Notifications button
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  // TODO: Open notifications
                },
                icon: const Icon(Icons.notifications_outlined),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'Calls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}