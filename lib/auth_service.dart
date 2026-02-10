import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// SIGN UP (Customer / Professional)
  Future<User?> signUp({
    required String email,
    required String password,
    required String role, // "customer" or "professional"
    required Map<String, dynamic> extraData,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // send verification email to the newly created user
    await cred.user!.sendEmailVerification();

    await _db.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': email,
      'role': role,
      ...extraData,
      'createdAt': FieldValue.serverTimestamp(),
      'emailVerified': cred.user!.emailVerified,
    });

    // sign out so the user can't access the app before verifying their email
    await _auth.signOut();

    return cred.user;
  }

  /// LOGIN
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  /// LOGOUT
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// CURRENT USER
  User? get currentUser => _auth.currentUser;
}
