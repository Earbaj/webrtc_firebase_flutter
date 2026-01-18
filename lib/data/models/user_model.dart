import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    super.name,
    super.profileImage,
    super.phoneNumber,
    required super.status,
    required super.lastSeen,
    super.createdAt,
    super.updatedAt,
    required super.isOnline,
    super.fcmToken,
    super.metadata,
  });

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      email: entity.email,
      name: entity.name,
      profileImage: entity.profileImage,
      phoneNumber: entity.phoneNumber,
      status: entity.status,
      lastSeen: entity.lastSeen,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isOnline: entity.isOnline,
      fcmToken: entity.fcmToken,
      metadata: entity.metadata,
    );
  }

  factory UserModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      ) {
    final data = snapshot.data()!;
    Timestamp? parseTimestamp(String key) {
      if (data[key] != null && data[key] is Timestamp) {
        return data[key] as Timestamp;
      }
      return null;
    }
    return UserModel(
      id: snapshot.id,
      email: data['email'] as String,
      name: data['name'] as String?,
      profileImage: data['profileImage'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      status: data['status'] as String? ?? AppConstants.userStatusOffline,
      lastSeen: parseTimestamp('lastSeen')?.toDate() ?? DateTime.now(),
      createdAt: parseTimestamp('createdAt')?.toDate() ?? DateTime.now(),
      updatedAt: parseTimestamp('updatedAt')?.toDate() ?? DateTime.now(),
      isOnline: data['isOnline'] as bool? ?? false,
      fcmToken: data['fcmToken'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profileImage': profileImage,
      'phoneNumber': phoneNumber,
      'status': status,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : DateTime.now(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : DateTime.now(),
      'isOnline': isOnline,
      'fcmToken': fcmToken,
      'metadata': metadata,
      'updatedAtServer': FieldValue.serverTimestamp(),
    };
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      email: email,
      name: name,
      profileImage: profileImage,
      phoneNumber: phoneNumber,
      status: status,
      lastSeen: lastSeen,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isOnline: isOnline,
      fcmToken: fcmToken,
      metadata: metadata,
    );
  }
}