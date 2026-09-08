import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    required String pantryType,
  }) async {
    // 1. Create Firebase Authentication account
    final UserCredential credential =
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final User? user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-created',
        message: 'Unable to create your account. Please try again.',
      );
    }

    // 2. Save the user's name in Firebase Authentication
    await user.updateDisplayName(name.trim());

    // 3. Create the user's profile in Firestore
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name.trim(),
      'email': email.trim(),
      'pantryType': pantryType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  User? get currentUser => _auth.currentUser;

  Future<void> signOut() async {
    await _auth.signOut();
  }
}