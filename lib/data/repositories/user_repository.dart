import 'package:fpdart/fpdart.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository_interface.dart';
import '../datasources/firebase_datasource.dart';
import '../models/user_model.dart';

class UserRepository implements UserRepositoryInterface {
  final FirebaseDataSource _dataSource;

  UserRepository(this._dataSource);

  @override
  Future<Either<String, UserEntity>> getUser(String userId) async {
    AppLogger.info('Getting user: $userId');
    final result = await _dataSource.getUser(userId);
    return result.fold(
          (error) => left(error),
          (userModel) => right(userModel.toEntity()),
    );
  }

  @override
  Future<Either<String, void>> createUser(UserEntity user) async {
    AppLogger.info('Creating user: ${user.id}');
    try {
      final userModel = UserModel.fromEntity(user);
      await _dataSource.firestore
          .collection(AppConstants.usersCollection)
          .doc(user.id)
          .set(userModel.toFirestore());
      return right(null);
    } catch (e) {
      AppLogger.error('Create user failed', error: e);
      return left('Failed to create user');
    }
  }

  @override
  Future<Either<String, void>> updateUser(UserEntity user) async {
    AppLogger.info('Updating user: ${user.id}');
    try {
      final userModel = UserModel.fromEntity(user);
      await _dataSource.firestore
          .collection(AppConstants.usersCollection)
          .doc(user.id)
          .update(userModel.toFirestore());
      return right(null);
    } catch (e) {
      AppLogger.error('Update user failed', error: e);
      return left('Failed to update user');
    }
  }

  @override
  Future<Either<String, void>> deleteUser(String userId) async {
    AppLogger.info('Deleting user: $userId');
    try {
      await _dataSource.firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .delete();
      return right(null);
    } catch (e) {
      AppLogger.error('Delete user failed', error: e);
      return left('Failed to delete user');
    }
  }

  @override
  Future<Either<String, List<UserEntity>>> getAllUsers() async {
    AppLogger.info('Getting all users');
    final result = await _dataSource.getAllUsers();
    return result.fold(
          (error) => left(error),
          (userModels) => right(userModels.map((model) => model.toEntity()).toList()),
    );
  }

  @override
  Future<Either<String, List<UserEntity>>> searchUsers(String query) async {
    AppLogger.info('Searching users: $query');
    try {
      final snapshot = await _dataSource.firestore
          .collection(AppConstants.usersCollection)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '${query}z')
          .get();

      final users = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc).toEntity())
          .toList();

      return right(users);
    } catch (e) {
      AppLogger.error('Search users failed', error: e);
      return left('Failed to search users');
    }
  }

  @override
  Future<Either<String, void>> setUserOnline(String userId) async {
    AppLogger.info('Setting user online: $userId');
    return await _dataSource.setUserOnline(userId);
  }

  @override
  Future<Either<String, void>> setUserOffline(String userId) async {
    AppLogger.info('Setting user offline: $userId');
    return await _dataSource.setUserOffline(userId);
  }

  @override
  Future<Either<String, void>> setUserBusy(String userId, bool isBusy) async {
    AppLogger.info('Setting user busy: $userId, busy: $isBusy');
    return await _dataSource.setUserBusy(userId, isBusy);
  }

  @override
  Stream<UserEntity> userStream(String userId) {
    return _dataSource.userStream(userId)
        .map((userModel) => userModel.toEntity());
  }

  @override
  Stream<List<UserEntity>> onlineUsersStream() {
    return _dataSource.onlineUsersStream()
        .map((userModels) => userModels
        .map((model) => model.toEntity())
        .toList());
  }

  @override
  Stream<List<UserEntity>> allUsersStream() {
    return _dataSource.firestore
        .collection(AppConstants.usersCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc).toEntity())
        .toList());
  }
}