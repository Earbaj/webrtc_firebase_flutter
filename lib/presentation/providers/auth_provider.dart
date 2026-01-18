import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../data/datasources/firebase_datasource.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/user_entity.dart';

// Provider for FirebaseDataSource
final firebaseDataSourceProvider = Provider<FirebaseDataSource>((ref) {
  return FirebaseDataSource();
});

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.watch(firebaseDataSourceProvider);
  return AuthRepository(dataSource);
});

// Auth State Provider
final authProvider = StreamProvider<UserEntity?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

// Auth Notifier for sign in/out operations
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;
  final Ref _ref;

  AuthNotifier(this._authRepository, this._ref) : super(const AsyncValue.data(null));

  Future<Either<String, UserEntity>> signInWithEmailAndPassword(
      String email,
      String password,
      ) async {
    state = const AsyncValue.loading();
    try {
      final result = await _authRepository.signInWithEmailAndPassword(
        email,
        password,
      );

      if (result.isLeft()) {
        state = AsyncValue.error(result.swap().getOrElse((entity) => ''), StackTrace.current);
      } else {
        state = const AsyncValue.data(null);
      }

      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('An unexpected error occurred');
    }
  }

  Future<Either<String, UserEntity>> signUpWithEmailAndPassword(
      String email,
      String password,
      String name,
      ) async {
    state = const AsyncValue.loading();
    try {
      final result = await _authRepository.signUpWithEmailAndPassword(
        email,
        password,
        name,
      );

      if (result.isLeft()) {
        state = AsyncValue.error(result.swap().getOrElse((entity) => ''), StackTrace.current);
      } else {
        state = const AsyncValue.data(null);
      }

      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('An unexpected error occurred');
    }
  }

  Future<Either<String, UserEntity>> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final result = await _authRepository.signInWithGoogle();

      if (result.isLeft()) {
        state = AsyncValue.error(result.swap().getOrElse((entity) => ''), StackTrace.current);
      } else {
        state = const AsyncValue.data(null);
      }

      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('An unexpected error occurred');
    }
  }

  Future<Either<String, void>> signOut() async {
    state = const AsyncValue.loading();
    try {
      final result = await _authRepository.signOut();

      if (result.isLeft()) {
        state = AsyncValue.error(result.swap().getOrElse((entity) => ''), StackTrace.current);
      } else {
        state = const AsyncValue.data(null);
      }

      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('An unexpected error occurred');
    }
  }

  Future<Either<String, void>> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      final result = await _authRepository.resetPassword(email);

      if (result.isLeft()) {
        state = AsyncValue.error(result.swap().getOrElse((entity) => ''), StackTrace.current);
      } else {
        state = const AsyncValue.data(null);
      }

      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return left('An unexpected error occurred');
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository, ref);
});