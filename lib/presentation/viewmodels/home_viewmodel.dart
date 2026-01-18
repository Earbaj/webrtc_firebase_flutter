import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user_entity.dart';
import '../providers/user_provider.dart';

class HomeViewModel {
  final Ref ref;

  HomeViewModel(this.ref);

  // Get all users
  Stream<List<UserEntity>> getAllUsers() {
    return ref.watch(allUsersProvider.stream);
  }

  // Get online users
  Stream<List<UserEntity>> getOnlineUsers() {
    return ref.watch(onlineUsersProvider.stream);
  }

  // Get current user
  UserEntity? getCurrentUser() {
    return ref.read(currentUserProvider);
  }

  // Filter users by search query
  Stream<List<UserEntity>> searchUsers(String query) {
    return getAllUsers().map((users) {
      if (query.isEmpty) return users;

      return users.where((user) {
        final name = user.name?.toLowerCase() ?? '';
        final email = user.email.toLowerCase();
        final searchLower = query.toLowerCase();

        return name.contains(searchLower) || email.contains(searchLower);
      }).toList();
    });
  }

  // Get user by ID
  Stream<UserEntity?> getUserById(String userId) {
    return getAllUsers().map((users) {
      return users.firstWhere(
            (user) => user.id == userId,
        orElse: () => UserEntity(
          id: '',
          email: '',
          status: '',
          lastSeen: DateTime.now(),
          isOnline: false,
        ),
      );
    });
  }
}

// Provider for HomeViewModel
final homeViewModelProvider = Provider<HomeViewModel>((ref) {
  return HomeViewModel(ref);
});