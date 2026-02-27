import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/auth_repository.dart';

// =============================================
// PROVIDERS - Dependency Injection & State Management
// =============================================

/// A [Provider] that creates and manages the life of an [AuthRepository] instance.
/// This allows us to easily swap out the repository for testing if needed.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// A [StreamProvider] that listens to real-time changes in the user's authentication state.
/// It returns null if the user is logged out, and a [User] object if they are logged in.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  // We watch the authRepositoryProvider to get the instance we created above.
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// A [StateNotifierProvider] that exposes an [AuthController] to the UI.
/// It tracks the current state of asynchronous auth operations (like logging in).
final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

// =============================================
// AUTH CONTROLLER - Business Logic & State Management
// =============================================

/// This class acts as a bridge between the UI and the Data layer (Repository).
/// It handles the 'loading' and 'error' states so the UI can respond accordingly.
class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  // Initial state is 'AsyncValue.data(null)', which means 'idle' or 'not loading'.
  AuthController(this._authRepository) : super(const AsyncValue.data(null));

  // =============================================
  // PUBLIC METHODS - API for the Screens
  // =============================================

  /// Attempts to log a user in with their email and password.
  Future<void> login(String email, String password) async {
    // 1. Tell the UI to show a loading spinner.
    state = const AsyncValue.loading();
    
    try {
      // 2. Perform the actual login work via the repository.
      await _authRepository.login(email, password);
      
      // 3. Clear the loading state on success.
      state = const AsyncValue.data(null);
    } catch (e, st) {
      // 4. Capture any error and provide it to the UI.
      state = AsyncValue.error(e, st);
      // Re-throw allows the UI (like a SnackBar) to handle the error specifically.
      rethrow;
    }
  }

  /// Attempts to register a new user with their email, password, and name.
  Future<void> signUp(String email, String password, String name) async {
    // 1. Enter loading state.
    state = const AsyncValue.loading();
    
    try {
      // 2. Perform the actual sign-up work.
      await _authRepository.signUp(email, password, name);
      
      // 3. Exit loading state.
      state = const AsyncValue.data(null);
    } catch (e, st) {
      // 4. Handle errors.
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}