import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/app_theme.dart';
import 'firebase_options.dart';
import 'screens/customer_home_screen.dart';
import 'screens/professional_home_screen.dart';
import 'screens/role_selection_screen.dart';
import 'services/notification_routes.dart';
import 'services/notification_service.dart';
import 'services/image_recognition_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: ".env");
  if (kDebugMode && dotenv.env['LOG_GEMINI_STARTUP_CHECK'] == 'true') {
    await ImageRecognitionService.logGeminiModelStatus();
  }

  FirebaseMessaging.onBackgroundMessage(
    NotificationService.firebaseMessagingBackgroundHandler,
  );

  await NotificationService().initialize();
  NotificationService().setNavigatorKey(appNavigatorKey);

  runApp(FixItApp(navigatorKey: appNavigatorKey));
}

class FixItApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const FixItApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FixIt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: navigatorKey,
      onGenerateRoute: NotificationRoutes.onGenerateRoute,
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
  String? _initializedNotificationUid;

  Future<void> _initializeUser(String uid) async {
    await NotificationService().updateUserToken(uid);
    await _ensureUserHasRole(uid);
    await NotificationService().syncProfessionalTopics();
  }

  Future<void> _ensureUserHasRole(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists || !(userDoc.data()!.containsKey('role'))) {
        final user = FirebaseAuth.instance.currentUser;

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'email': user?.email ?? '',
          'role': 'customer',
          'displayName': user?.displayName ?? 'User',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error ensuring user role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user != null && _initializedNotificationUid != user.uid) {
          _initializedNotificationUid = user.uid;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeUser(user.uid);
          });
        } else if (user == null) {
          _initializedNotificationUid = null;
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return const RoleSelectionScreen();
        }

        final userId = user.uid;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get()
              .then((doc) async {
                if (!doc.exists ||
                    !(doc.data() as Map<String, dynamic>).containsKey('role')) {
                  await _ensureUserHasRole(userId);
                  return FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .get();
                }
                return doc;
              }),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData ||
                userSnapshot.data == null ||
                !userSnapshot.data!.exists) {
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
