import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/auth_repository.dart';

// =============================================
// PROVIDERS - Dependency Injection & State Management
// =============================================

/// [Provider] for AuthRepository instance
/// Purpose: Creates and provides a single instance of AuthRepository
/// Usage: This ensures we have only one AuthRepository instance across the app
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// [StreamProvider] for authentication state changes
/// Purpose: Listens to Firebase Auth state changes (user login/logout)
/// Value: Stream of User? - null when logged out, User object when logged in
/// Usage: Widgets can watch this to react to auth state changes
final authStateChangesProvider = StreamProvider<User?>((ref) {
  // Get the AuthRepository instance and return its authStateChanges stream
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// [StateNotifierProvider] for auth operations with loading/error states
/// Purpose: Manages async state for login/signup operations (loading, success, error)
/// Value: AsyncValue<void> - represents the state of async operations
final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  // Create AuthController with the AuthRepository instance
  return AuthController(ref.watch(authRepositoryProvider));
});

// =============================================
// AUTH CONTROLLER - Business Logic & State Management
// =============================================

/// Controller class that handles authentication business logic and state management
/// Why we need this class:
/// 1. Separates business logic from UI
/// 2. Manages loading/error states properly
/// 3. Makes auth operations testable
/// 4. Provides a clean API for the UI layer
class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;

  /// Constructor: Initializes with AuthRepository and sets initial state
  /// Initial state: AsyncValue.data(null) - means no operation in progress
  AuthController(this._authRepository) : super(const AsyncValue.data(null));

  // =============================================
  // PUBLIC METHODS - API for UI Layer
  // =============================================

  /// Login method with proper state management
  /// Why async operations need state management:
  /// - Show loading indicators
  /// - Handle errors gracefully
  /// - Prevent multiple simultaneous requests
  Future<void> login(String email, String password) async {
    // 1. Set loading state - UI can show progress indicator
    state = const AsyncValue.loading();
    try {
      // 2. Perform the actual login operation
      await _authRepository.login(email, password);
      // 3. Set success state - operation completed successfully
      state = const AsyncValue.data(null);
    } catch (e, st) {
      // 4. Set error state - operation failed
      // AsyncValue.error preserves both error and stack trace for debugging
      state = AsyncValue.error(e, st);
      // 5. Re-throw to allow UI layer to handle specific errors (like showing SnackBar)
      rethrow;
    }
  }

  /// SignUp method with the same state management pattern
  Future<void> signUp(String email, String password, String name) async {
    // Set loading state
    state = const AsyncValue.loading();
    try {
      // Perform signup operation
      await _authRepository.signUp(email, password, name);
      // Set success state
      state = const AsyncValue.data(null);
    } catch (e, st) {
      // Set error state and re-throw
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}