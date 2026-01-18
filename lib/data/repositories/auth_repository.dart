import 'package:fpdart/fpdart.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository_interface.dart';
import '../datasources/firebase_datasource.dart';

class AuthRepository implements AuthRepositoryInterface {
  final FirebaseDataSource _dataSource;

  AuthRepository(this._dataSource);

  @override
  Future<Either<String, UserEntity>> signInWithEmailAndPassword(
      String email,
      String password,
      ) async {
    AppLogger.info('Signing in with email: $email');
    final result = await _dataSource.signInWithEmailAndPassword(email, password);
    return result.fold(
          (error) => left(error),
          (userModel) => right(userModel.toEntity()),
    );
  }

  @override
  Future<Either<String, UserEntity>> signUpWithEmailAndPassword(
      String email,
      String password,
      String name,
      ) async {
    AppLogger.info('Signing up with email: $email');
    final result = await _dataSource.signUpWithEmailAndPassword(
      email,
      password,
      name,
    );
    return result.fold(
          (error) => left(error),
          (userModel) => right(userModel.toEntity()),
    );
  }

  @override
  Future<Either<String, UserEntity>> signInWithGoogle() async {
    AppLogger.info('Signing in with Google');
    final result = await _dataSource.signInWithGoogle();
    return result.fold(
          (error) => left(error),
          (userModel) => right(userModel.toEntity()),
    );
  }

  @override
  Future<Either<String, void>> signOut() async {
    AppLogger.info('Signing out');
    return await _dataSource.signOut();
  }

  @override
  Future<Either<String, void>> resetPassword(String email) async {
    AppLogger.info('Resetting password for: $email');
    return await _dataSource.resetPassword(email);
  }

  @override
  Future<Either<String, void>> updateUserStatus({
    required String userId,
    required String status,
    required bool isOnline,
  }) async {
    AppLogger.info('Updating user status: $status, online: $isOnline');
    return await _dataSource.updateUserStatus(
      userId: userId,
      status: status,
      isOnline: isOnline,
    );
  }

  @override
  Future<Either<String, void>> updateFCMToken(String token) async {
    AppLogger.info('Updating FCM token');
    return await _dataSource.updateFCMToken(token);
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    return _dataSource.authStateChanges.asyncMap((userModel) {
      return userModel?.toEntity();
    });
  }

  @override
  UserEntity? get currentUser {
    final userModel = _dataSource.currentUser;
    return userModel?.toEntity();
  }
}