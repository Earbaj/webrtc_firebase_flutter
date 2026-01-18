import 'package:fpdart/fpdart.dart';

import '../entities/user_entity.dart';

abstract class UserRepositoryInterface {
  // User CRUD
  Future<Either<String, UserEntity>> getUser(String userId);
  Future<Either<String, void>> createUser(UserEntity user);
  Future<Either<String, void>> updateUser(UserEntity user);
  Future<Either<String, void>> deleteUser(String userId);

  // User queries
  Future<Either<String, List<UserEntity>>> getAllUsers();
  Future<Either<String, List<UserEntity>>> searchUsers(String query);

  // Presence system
  Future<Either<String, void>> setUserOnline(String userId);
  Future<Either<String, void>> setUserOffline(String userId);
  Future<Either<String, void>> setUserBusy(String userId, bool isBusy);

  // Streams
  Stream<UserEntity> userStream(String userId);
  Stream<List<UserEntity>> onlineUsersStream();
  Stream<List<UserEntity>> allUsersStream();
}