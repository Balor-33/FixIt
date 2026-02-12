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
      theme: AppTheme.light().copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
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
          return const _LoadingScreen();
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
              return const _LoadingScreen();
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

// ✨ Animated Loading Screen with Logo
class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/FixIt_logo.png',
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ✨ Animated Error Screen
class _ErrorScreen extends StatefulWidget {
  final VoidCallback onRetry;

  const _ErrorScreen({required this.onRetry});

  @override
  State<_ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<_ErrorScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/FixIt_logo.png',
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 32),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'User Profile Error',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load your user profile. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  _AnimatedButton(
                    onPressed: widget.onRetry,
                    icon: Icons.refresh,
                    label: 'Retry',
                    isPrimary: true,
                  ),
                  const SizedBox(height: 12),
                  _AnimatedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    icon: Icons.logout,
                    label: 'Sign Out',
                    isPrimary: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ✨ Animated Button with Hover Effect
class _AnimatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;

  const _AnimatedButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.isPrimary,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.isPrimary
            ? ElevatedButton.icon(
                onPressed: widget.onPressed,
                icon: Icon(widget.icon),
                label: Text(widget.label),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : TextButton.icon(
                onPressed: widget.onPressed,
                icon: Icon(widget.icon),
                label: Text(widget.label),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
      ),
    );
  }
}
