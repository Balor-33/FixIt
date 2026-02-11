import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/role_selection_screen.dart';
import 'screens/customer_home_screen.dart';
import 'screens/professional_home_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Notification Service
  await NotificationService().initialize();

  runApp(const FixItApp());
}

class FixItApp extends StatelessWidget {
  const FixItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FixIt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _updateFCMToken();
  }

  // Update FCM token when user logs in
  Future<void> _updateFCMToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await NotificationService().updateUserToken(user.uid);
    }
  }

  // ✅ Fix user role if missing
  Future<void> _ensureUserHasRole(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists || !userDoc.data()!.containsKey('role')) {
        print('⚠️ User missing role field, creating document...');

        final user = FirebaseAuth.instance.currentUser;
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'email': user?.email ?? '',
          'role': 'customer', // Default to customer
          'displayName': user?.displayName ?? 'User',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('✅ User role fixed!');
      }
    } catch (e) {
      print('❌ Error ensuring user has role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/FixIt_logo.png',
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          // User is not logged in
          return const RoleSelectionScreen();
        }

        final userId = snapshot.data!.uid;

        // Update token when user logs in
        _updateFCMToken();

        // User is logged in, fetch their role
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get()
              .then((doc) async {
                // ✅ Auto-fix missing role
                if (!doc.exists || !doc.data()!.containsKey('role')) {
                  await _ensureUserHasRole(userId);
                  // Refetch the document
                  return FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get();
                }
                return doc;
              }),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/FixIt_logo.png',
                        width: 150,
                        height: 150,
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                    ],
                  ),
                ),
              );
            }

            if (!userSnapshot.hasData ||
                userSnapshot.data == null ||
                !userSnapshot.data!.exists) {
              // If still no user document, show error screen
              return _ErrorScreen(onRetry: () => setState(() {}));
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

            if (userData == null || !userData.containsKey('role')) {
              return _ErrorScreen(onRetry: () => setState(() {}));
            }

            final userRole = userData['role'] as String?;

            if (userRole == 'customer') {
              return const CustomerHomeScreen();
            } else if (userRole == 'professional') {
              return const ProfessionalHomeScreen();
            }

            return const RoleSelectionScreen();
          },
        );
      },
    );
  }
}

// ✅ Error screen with retry option
class _ErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/FixIt_logo.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'User Profile Error',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Could not load your user profile. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
