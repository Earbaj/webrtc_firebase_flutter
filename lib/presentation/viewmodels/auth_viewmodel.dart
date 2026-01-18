import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';

class AuthViewModel {
  final Ref ref;

  AuthViewModel(this.ref);

  // Sign in with email and password
  Future<Either<String, UserEntity>> signInWithEmailAndPassword(
      String email,
      String password,
      ) async {
    final notifier = ref.read(authNotifierProvider.notifier);
    return await notifier.signInWithEmailAndPassword(email, password);
  }

  // Sign up with email and password
  Future<Either<String, UserEntity>> signUpWithEmailAndPassword(
      String email,
      String password,
      String name,
      ) async {
    final notifier = ref.read(authNotifierProvider.notifier);
    return await notifier.signUpWithEmailAndPassword(email, password, name);
  }

  // Sign in with Google
  Future<Either<String, UserEntity>> signInWithGoogle() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    return await notifier.signInWithGoogle();
  }

  // Sign out
  Future<Either<String, void>> signOut() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    return await notifier.signOut();
  }

  // Reset password
  Future<Either<String, void>> resetPassword(String email) async {
    final notifier = ref.read(authNotifierProvider.notifier);
    return await notifier.resetPassword(email);
  }

  // Check if user is authenticated
  bool get isAuthenticated {
    final authState = ref.read(authProvider);
    return authState.valueOrNull != null;
  }

  // Get current user
  UserEntity? get currentUser {
    final authState = ref.read(authProvider);
    return authState.valueOrNull;
  }

  // Get auth state stream
  Stream<UserEntity?> get authStateStream {
    final authStream = ref.read(authProvider.stream);
    return authStream;
  }
}

// Provider for AuthViewModel
final authViewModelProvider = Provider<AuthViewModel>((ref) {
  return AuthViewModel(ref);
});