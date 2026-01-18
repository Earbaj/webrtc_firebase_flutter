import '../../core/constants/app_constants.dart';

class UserEntity {
  final String id;
  final String email;
  final String? name;
  final String? profileImage;
  final String? phoneNumber;
  final String status;
  final DateTime lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isOnline;
  final String? fcmToken;
  final Map<String, dynamic>? metadata;

  const UserEntity({
    required this.id,
    required this.email,
    this.name,
    this.profileImage,
    this.phoneNumber,
    required this.status,
    required this.lastSeen,
    this.createdAt,
    this.updatedAt,
    required this.isOnline,
    this.fcmToken,
    this.metadata,
  });

  UserEntity copyWith({
    String? id,
    String? email,
    String? name,
    String? profileImage,
    String? phoneNumber,
    String? status,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isOnline,
    String? fcmToken,
    Map<String, dynamic>? metadata,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImage: profileImage ?? this.profileImage,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isOnline: isOnline ?? this.isOnline,
      fcmToken: fcmToken ?? this.fcmToken,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profileImage': profileImage,
      'phoneNumber': phoneNumber,
      'status': status,
      'lastSeen': lastSeen.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isOnline': isOnline,
      'fcmToken': fcmToken,
      'metadata': metadata,
    };
  }

  factory UserEntity.fromMap(Map<String, dynamic> map) {
    return UserEntity(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String?,
      profileImage: map['profileImage'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      status: map['status'] as String? ?? AppConstants.userStatusOffline,
      lastSeen: DateTime.parse(map['lastSeen'] as String),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      isOnline: map['isOnline'] as bool? ?? false,
      fcmToken: map['fcmToken'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  // Convenience getters
  String get displayName => name ?? email.split('@').first;
  bool get isBusy => status == AppConstants.userStatusBusy;
  bool get isAvailable => !isBusy && isOnline;
}