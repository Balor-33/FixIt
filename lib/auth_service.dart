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
    try {
      // Create user account
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send verification email
      await cred.user!.sendEmailVerification();

      // Save user data to Firestore
      await _db.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'email': email,
        'role': role,
        ...extraData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'emailVerified': false, // Initially false
      });

      // Sign out so user must verify email before accessing app
      await _auth.signOut();

      return cred.user;
    } catch (e) {
      print('❌ SignUp Error: $e');
      rethrow;
    }
  }

  /// LOGIN with Email Verification Check
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with email and password
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ✅ Check if email is verified
      await cred.user!.reload(); // Refresh user data
      final user = _auth.currentUser;

      if (user != null && !user.emailVerified) {
        // Email not verified - sign out and throw error
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message:
              'Please verify your email before logging in. Check your inbox for the verification link.',
        );
      }

      // ✅ Update emailVerified status in Firestore
      if (user != null && user.emailVerified) {
        await _db.collection('users').doc(user.uid).update({
          'emailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-not-verified') {
        rethrow;
      }
      print('❌ SignIn Error: ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ SignIn Error: $e');
      rethrow;
    }
  }

  /// RESEND VERIFICATION EMAIL
  Future<void> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print('✅ Verification email sent');
      }
    } catch (e) {
      print('❌ Resend Email Error: $e');
      rethrow;
    }
  }

  /// CHECK EMAIL VERIFICATION STATUS
  Future<bool> checkEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        return _auth.currentUser?.emailVerified ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Check Verification Error: $e');
      return false;
    }
  }

  /// RESET PASSWORD
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Password reset email sent');
    } catch (e) {
      print('❌ Reset Password Error: $e');
      rethrow;
    }
  }

  /// LOGOUT
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// CURRENT USER
  User? get currentUser => _auth.currentUser;

  /// STREAM OF AUTH CHANGES
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// GET USER ROLE FROM FIRESTORE
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Get User Role Error: $e');
      return null;
    }
  }
}
