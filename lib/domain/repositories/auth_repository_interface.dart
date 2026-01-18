import 'package:fpdart/fpdart.dart';

import '../entities/user_entity.dart';


abstract class AuthRepositoryInterface {
  // Authentication methods
  Future<Either<String, UserEntity>> signInWithEmailAndPassword(
      String email,
      String password,
      );

  Future<Either<String, UserEntity>> signUpWithEmailAndPassword(
      String email,
      String password,
      String name,
      );

  Future<Either<String, UserEntity>> signInWithGoogle();

  Future<Either<String, void>> signOut();

  Future<Either<String, void>> resetPassword(String email);

  // User status
  Future<Either<String, void>> updateUserStatus({
    required String userId,
    required String status,
    required bool isOnline,
  });

  // Token management
  Future<Either<String, void>> updateFCMToken(String token);

  // Streams
  Stream<UserEntity?> get authStateChanges;
  UserEntity? get currentUser;
}