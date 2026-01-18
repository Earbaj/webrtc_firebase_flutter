import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../data/repositories/user_repository.dart';
import '../../domain/entities/user_entity.dart';
import 'auth_provider.dart';

// Provider for UserRepository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  final dataSource = ref.watch(firebaseDataSourceProvider);
  return UserRepository(dataSource);
});

// All Users Provider
final allUsersProvider = StreamProvider<List<UserEntity>>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.allUsersStream();
});

// Online Users Provider
final onlineUsersProvider = StreamProvider<List<UserEntity>>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.onlineUsersStream();
});

// Current User Provider
final currentUserProvider = Provider<UserEntity?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.valueOrNull;
});

// User Notifier for user operations
class UserNotifier extends StateNotifier<AsyncValue<void>> {
  final UserRepository _userRepository;
  final Ref _ref;

  UserNotifier(this._userRepository, this._ref) : super(const AsyncValue.data(null));

  Future<Either<String, UserEntity>> getUser(String userId) async {
    try {
      final result = await _userRepository.getUser(userId);
      return result;
    } catch (e) {
      return left('Failed to get user');
    }
  }

  Future<Either<String, void>> updateUserProfile({
    required String userId,
    String? name,
    String? profileImage,
    String? phoneNumber,
  }) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await _userRepository.getUser(userId);

      return currentUser.fold(
            (error) => left(error),
            (user) async {
          final updatedUser = user.copyWith(
            name: name ?? user.name,
            profileImage: profileImage ?? user.profileImage,
            phoneNumber: phoneNumber ?? user.phoneNumber,
          );

          final result = await _userRepository.updateUser(updatedUser);
          state = const AsyncValue.data(null);
          return result;
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('Failed to update profile');
    }
  }

  Future<Either<String, List<UserEntity>>> searchUsers(String query) async {
    try {
      return await _userRepository.searchUsers(query);
    } catch (e) {
      return left('Failed to search users');
    }
  }
}

final userNotifierProvider = StateNotifierProvider<UserNotifier, AsyncValue<void>>((ref) {
  final userRepository = ref.watch(userRepositoryProvider);
  return UserNotifier(userRepository, ref);
});