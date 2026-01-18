import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/call_entity.dart';
import '../../domain/entities/signaling_entity.dart';
import '../models/call_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

class FirebaseDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // Auth methods
  Future<Either<String, UserModel>> signInWithEmailAndPassword(
      String email,
      String password,
      ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return left('User not found');
      }

      // Update user online status
      await updateUserStatus(
        userId: user.uid,
        status: AppConstants.userStatusOnline,
        isOnline: true,
      );

      return await _getUserModel(user.uid);
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Sign in failed', error: e);
      return left(_getAuthErrorMessage(e));
    } catch (e) {
      AppLogger.error('Sign in failed', error: e);
      return left('An unexpected error occurred');
    }
  }

  Future<Either<String, UserModel>> signUpWithEmailAndPassword(
      String email,
      String password,
      String name,
      ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return left('User creation failed');
      }

      // Create user document
      final userModel = UserModel(
        id: user.uid,
        email: email,
        name: name,
        status: AppConstants.userStatusOnline,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
        isOnline: true,
      );

      await firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(userModel.toFirestore());

      return right(userModel);
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Sign up failed', error: e);
      return left(_getAuthErrorMessage(e));
    } catch (e) {
      AppLogger.error('Sign up failed', error: e);
      return left('An unexpected error occurred');
    }
  }

  Future<Either<String, UserModel>> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return left('Google sign in cancelled');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        return left('Google sign in failed');
      }

      // Check if user exists in Firestore
      final userDoc = await firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        // Create new user document
        final userModel = UserModel(
          id: user.uid,
          email: user.email!,
          name: user.displayName ?? googleUser.displayName,
          profileImage: user.photoURL ?? googleUser.photoUrl,
          status: AppConstants.userStatusOnline,
          lastSeen: DateTime.now(),
          createdAt: DateTime.now(),
          isOnline: true,
        );

        await firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set(userModel.toFirestore());

        return right(userModel);
      } else {
        // Update existing user status
        await updateUserStatus(
          userId: user.uid,
          status: AppConstants.userStatusOnline,
          isOnline: true,
        );

        return await _getUserModel(user.uid);
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Google sign in failed', error: e);
      return left(_getAuthErrorMessage(e));
    } catch (e) {
      AppLogger.error('Google sign in failed', error: e);
      return left('An unexpected error occurred');
    }
  }

  Future<Either<String, void>> signOut() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await updateUserStatus(
          userId: currentUser.uid,
          status: AppConstants.userStatusOffline,
          isOnline: false,
        );
      }

      await _googleSignIn.signOut();
      await _auth.signOut();
      return right(null);
    } catch (e) {
      AppLogger.error('Sign out failed', error: e);
      return left('Sign out failed');
    }
  }

  Future<Either<String, void>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return right(null);
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Reset password failed', error: e);
      return left(_getAuthErrorMessage(e));
    } catch (e) {
      AppLogger.error('Reset password failed', error: e);
      return left('An unexpected error occurred');
    }
  }

  // User management
  Future<Either<String, UserModel>> getUser(String userId) async {
    try {
      final doc = await firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) {
        return left('User not found');
      }

      final user = UserModel.fromFirestore(doc);
      return right(user);
    } catch (e) {
      AppLogger.error('Get user failed', error: e);
      return left('Failed to get user');
    }
  }

  Future<Either<String, List<UserModel>>> getAllUsers() async {
    try {
      final querySnapshot = await firestore
          .collection(AppConstants.usersCollection)
          .get();

      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      return right(users);
    } catch (e) {
      AppLogger.error('Get all users failed', error: e);
      return left('Failed to get users');
    }
  }

  // Presence system
  Future<Either<String, void>> updateUserStatus({
    required String userId,
    required String status,
    required bool isOnline,
  }) async {
    try {
      await firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'status': status,
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return right(null);
    } catch (e) {
      AppLogger.error('Update user status failed', error: e);
      return left('Failed to update status');
    }
  }

  Future<Either<String, void>> setUserOnline(String userId) async {
    return await updateUserStatus(
      userId: userId,
      status: AppConstants.userStatusOnline,
      isOnline: true,
    );
  }

  Future<Either<String, void>> setUserOffline(String userId) async {
    return await updateUserStatus(
      userId: userId,
      status: AppConstants.userStatusOffline,
      isOnline: false,
    );
  }

  Future<Either<String, void>> setUserBusy(String userId, bool isBusy) async {
    return await updateUserStatus(
      userId: userId,
      status: isBusy
          ? AppConstants.userStatusBusy
          : AppConstants.userStatusOnline,
      isOnline: true,
    );
  }

  // FCM Token management
  Future<Either<String, void>> updateFCMToken(String token) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return left('No user logged in');
      }

      await firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUser.uid)
          .update({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return right(null);
    } catch (e) {
      AppLogger.error('Update FCM token failed', error: e);
      return left('Failed to update FCM token');
    }
  }

  // Streams
  Stream<UserModel?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      try {
        final user = await _getUserModel(firebaseUser.uid);
        return user.fold(
              (error) => null,
              (user) => user,
        );
      } catch (e) {
        return null;
      }
    });
  }

  Stream<UserModel> userStream(String userId) {
    return firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('User not found');
      }
      return UserModel.fromFirestore(snapshot);
    });
  }

  Stream<List<UserModel>> onlineUsersStream() {
    return firestore
        .collection(AppConstants.usersCollection)
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .toList());
  }

  // Helper methods
  Future<Either<String, UserModel>> _getUserModel(String userId) async {
    final result = await getUser(userId);
    return result;
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  UserModel? get currentUser {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    // Note: This doesn't fetch from Firestore
    return UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName,
      profileImage: firebaseUser.photoURL,
      status: AppConstants.userStatusOffline,
      lastSeen: DateTime.now(),
      isOnline: false,
    );
  }

  // Call Management Methods
  Future<Either<String, CallModel>> createCall({
    required String callerId,
    required String receiverId,
    required String callType,
  }) async {
    try {
      final callId = _generateCallId();
      final callModel = CallModel(
        id: callId,
        callId: callId,
        callerId: callerId,
        receiverId: receiverId,
        callType: callType,
        status: AppConstants.callStatusInitiated,
        startedAt: DateTime.now(),
        isIncoming: false,
      );

      await firestore
          .collection(AppConstants.callsCollection)
          .doc(callId)
          .set(callModel.toFirestore());

      // Create subcollection for signaling
      await firestore
          .collection(AppConstants.callsCollection)
          .doc(callId)
          .collection('signaling')
          .doc('init')
          .set({
        'callId': callId,
        'callerId': callerId,
        'receiverId': receiverId,
        'callType': callType,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Set caller as busy
      await setUserBusy(callerId, true);

      return right(callModel);
    } catch (e) {
      AppLogger.error('Create call failed', error: e);
      return left('Failed to create call');
    }
  }

  Future<Either<String, CallModel>> getCall(String callId) async {
    try {
      final doc = await firestore
          .collection(AppConstants.callsCollection)
          .doc(callId)
          .get();

      if (!doc.exists) {
        return left('Call not found');
      }

      final call = CallModel.fromFirestore(doc);
      return right(call);
    } catch (e) {
      AppLogger.error('Get call failed', error: e);
      return left('Failed to get call');
    }
  }

  Future<Either<String, void>> updateCall(CallModel call) async {
    try {
      await firestore
          .collection(AppConstants.callsCollection)
          .doc(call.id)
          .update(call.toFirestore());
      return right(null);
    } catch (e) {
      AppLogger.error('Update call failed', error: e);
      return left('Failed to update call');
    }
  }

// Signaling Methods
  Future<Either<String, void>> sendOffer({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> offer,
  }) async {
    try {
      await firestore
          .collection(AppConstants.callsCollection)
          .doc(callId)
          .collection('signaling')
          .add({
        'type': 'offer',
        'sdp': offer,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'callId': callId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return right(null);
    } catch (e) {
      AppLogger.error('Send offer failed', error: e);
      return left('Failed to send offer');
    }
  }

  Future<Either<String, void>> sendAnswer({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> answer,
  }) async {
    try {
      await firestore
          .collection(AppConstants.callsCollection)
          .doc(callId)
          .collection('signaling')
          .add({
        'type': 'answer',
        'sdp': answer,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'callId': callId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return right(null);
    } catch (e) {
      AppLogger.error('Send answer failed', error: e);
      return left('Failed to send answer');
    }
  }

  Future<Either<String, void>> sendIceCandidate({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required Map<String, dynamic> candidate,
  }) async {
    try {
      await firestore
          .collection(AppConstants.callsCollection)
          .doc(callId)
          .collection('signaling')
          .add({
        'type': 'candidate',
        'candidate': candidate,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'callId': callId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return right(null);
    } catch (e) {
      AppLogger.error('Send ICE candidate failed', error: e);
      return left('Failed to send ICE candidate');
    }
  }

// Streams for Signaling
  Stream<SignalingEntity> listenForOffers(String userId) {
    return firestore
        .collectionGroup('signaling')
        .where('type', isEqualTo: 'offer')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .asyncExpand((snapshot) async* {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          yield SignalingEntity.fromMap({
            ...data,
            'id': change.doc.id,
            'timestamp': (data['timestamp'] as Timestamp).toDate(),
          });
        }
      }
    });
  }

  Stream<CallEntity> listenForCallUpdates(String callId) {
    return firestore
        .collection(AppConstants.callsCollection)
        .doc(callId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        throw Exception('Call not found');
      }
      return CallModel.fromFirestore(snapshot).toEntity();
    });
  }

// Notification Methods
  Future<Either<String, void>> sendNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await firestore
          .collection(AppConstants.notificationsCollection)
          .add({
        'userId': userId,
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return right(null);
    } catch (e) {
      AppLogger.error('Send notification failed', error: e);
      return left('Failed to send notification');
    }
  }

  Stream<List<NotificationModel>> notificationsStream(String userId) {
    return firestore
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => NotificationModel.fromFirestore(doc))
        .toList());
  }

// Helper Methods
  String _generateCallId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        _auth.currentUser!.uid.substring(0, 8) ?? '';
  }

  Future<Either<String, bool>> isUserBusy(String userId) async {
    try {
      final doc = await firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (!doc.exists) {
        return left('User not found');
      }

      final data = doc.data()!;
      final isBusy = data['status'] == AppConstants.userStatusBusy;
      return right(isBusy);
    } catch (e) {
      AppLogger.error('Check user busy failed', error: e);
      return left('Failed to check user status');
    }
  }
}