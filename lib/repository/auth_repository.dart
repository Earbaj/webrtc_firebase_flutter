import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// This class is responsible for direct communication with Firebase
/// for authentication and user-related Firestore operations.
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the current user if they are logged in.
  User? get currentUser => _auth.currentUser;

  /// A stream that emits events whenever the user logs in or out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Logs a user in with Firebase Auth and updates their status in Firestore.
  Future<void> login(String email, String password) async {
    // 1. Authenticate with Firebase.
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // 2. Mark the user as 'online' in the 'users' collection.
    // This helps other users know who they can call.
    await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Creates a new user in Firebase Auth and adds a corresponding profile in Firestore.
  Future<void> signUp(String email, String password, String name) async {
    // 1. Create the user credentials with Firebase Auth.
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    // 2. Initialize the user's profile document in Firestore.
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'uid': userCredential.user!.uid,
      'name': name.trim(),
      'email': email.trim(),
      'isOnline': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Logs the user out and updates their Firestore status to 'offline'.
  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      // 1. Mark as offline first so others don't try to call a logged-out user.
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
    // 2. End the session in Firebase Auth.
    await _auth.signOut();
  }
}