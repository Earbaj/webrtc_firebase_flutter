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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _setupCallListeners();
  }

  void _setupCallListeners() {
    // Listen for incoming calls
    final callNotifier = ref.read(callNotifierProvider.notifier);
    final incomingCallStream = callNotifier.listenForIncomingCalls();

    // Handle incoming calls
    // This will be implemented in Phase 4 with proper call handling
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      },
          (call) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      },
          (call) {
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

  Widget _buildUserList() {
    final homeViewModel = ref.read(homeViewModelProvider);
    final usersStream = homeViewModel.searchUsers(_searchQuery);

    return StreamBuilder<List<UserEntity>>(
      stream: usersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading users',
              style: TextStyles.bodyMedium.copyWith(
                color: AppColors.error,
              ),
            ),
          );
        }

        final users = snapshot.data ?? [];
        final currentUser = ref.read(currentUserProvider);
        final filteredUsers = users.where((user) => user.id != currentUser?.id).toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.group_off_rounded,
                  size: 80,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No users found'
                      : 'No users match your search',
                  style: TextStyles.h3.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            return UserListTile(
              user: user,
              onTap: () => _onUserTap(user),
              onVideoCall: () => _onVideoCall(user),
              onAudioCall: () => _onAudioCall(user),
            );
          },
        );
      },
    );
  }

  Widget _buildCallsTab() {
    // TODO: Implement calls history screen
    return Center(
      child: Text(
        'Calls History',
        style: TextStyles.h3,
      ),
    );
  }

  Widget _buildProfileTab() {
    final currentUser = ref.watch(currentUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.surfaceLight,
                  child: currentUser?.profileImage != null
                      ? ClipOval(
                    child: Image.network(
                      currentUser!.profileImage!,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  )
                      : Icon(
                    Icons.person,
                    size: 50,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  currentUser?.displayName ?? 'User',
                  style: TextStyles.h2,
                ),

                const SizedBox(height: 8),

                Text(
                  currentUser?.email ?? '',
                  style: TextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 16),

                // Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: currentUser?.isOnline ?? false
                        ? AppColors.statusOnline.withOpacity(0.1)
                        : AppColors.statusOffline.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: currentUser?.isOnline ?? false
                              ? AppColors.statusOnline
                              : AppColors.statusOffline,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currentUser?.isOnline ?? false ? 'Online' : 'Offline',
                        style: TextStyles.bodySmall.copyWith(
                          color: currentUser?.isOnline ?? false
                              ? AppColors.statusOnline
                              : AppColors.statusOffline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Settings Options
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildSettingsOption(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () => context.push(RouteNames.settings),
                ),

                _buildSettingsOption(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  badgeCount: ref.watch(unreadNotificationsCountProvider),
                  onTap: () {
                    // TODO: Implement notifications screen
                  },
                ),

                _buildSettingsOption(
                  icon: Icons.help,
                  title: 'Help & Support',
                  onTap: () {
                    // TODO: Implement help screen
                  },
                ),

                _buildSettingsOption(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  color: AppColors.error,
                  onTap: _onSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String title,
    int badgeCount = 0,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (color ?? AppColors.primary).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color ?? AppColors.primary,
                  size: 20,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Text(
                  title,
                  style: TextStyles.bodyLarge,
                ),
              ),

              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: TextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
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
        children: [
          // Contacts Tab
          Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _buildUserList(),
              ),
            ],
          ),

          // Calls Tab
          _buildCallsTab(),

          // Profile Tab
          ProfileScreen(),
        ],
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