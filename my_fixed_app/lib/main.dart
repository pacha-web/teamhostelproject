import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/admin/view_history_screen.dart';

// Firebase options file (generated using flutterfire configure)
import 'firebase_options.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/student/student_home.dart';

// Admin Screens
import 'screens/admin/admin_panel.dart';
import 'screens/admin/add_student.dart';
import 'screens/admin/requested_gate_pass.dart';
import 'screens/admin/student_list_page.dart';

// Auth
import 'screens/auth/universal_signin.dart';

// Security
import 'screens/security/qr_scanner_page.dart';

// Role resolver page
import 'screens/resolve_role.dart';

/// ------------------ FCM / Local Notifications Setup ------------------ ///

/// Global local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Android channel used for foreground local notifications
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

/// Background message handler (top-level)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you use any other Firebase services in background handler, initialize:
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // simple debug log; you could perform background tasks here
  debugPrint('Background message received: ${message.messageId}, data: ${message.data}');
}

/// Save token to Firestore for current user
Future<void> _saveFcmTokenForCurrentUser() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }

    // update token on refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (newToken != null && newToken.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'fcmToken': newToken}, SetOptions(merge: true));
      }
    });
  } catch (e) {
    debugPrint('Error saving FCM token: $e');
  }
}

/// Request notification permissions (iOS & Android 13+)
Future<void> _requestNotificationPermissions() async {
  try {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');
  } catch (e) {
    debugPrint('Error requesting notification permissions: $e');
  }
}

/// Setup foreground message handling and local notifications
void _setupFCMHandlers(GoRouter router) {
  // When app is in foreground - show a local notification
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground message received: ${message.messageId}');
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            // other Android options
          ),
        ),
        payload: message.data.isNotEmpty ? message.data.toString() : null,
      );
    }
  });

  // When user taps a notification (app in background / terminated)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Notification opened App: ${message.data}');
    // Example: navigate to a route based on notification data
    final data = message.data;
    if (data.containsKey('type')) {
      final type = data['type'];
      if (type == 'gatepass_request') {
        router.go('/requested-gate-pass');
      } else if (type == 'gatepass_status') {
        router.go('/student-home');
      }
      // add more routing logic based on data keys
    } else {
      // default behavior
      router.go('/resolve');
    }
  });

  // Handle if app opened from terminated state via notification
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      debugPrint('App opened from terminated state by notification: ${message.data}');
      // Optionally navigate somewhere using router
    }
  });
}

/// ------------------ End FCM / Local Notifications Setup ------------------ ///

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register background handler for FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications (Android initialization)
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
    // Handle taps on local notifications if needed
    debugPrint('Local notification tapped. Payload: ${response.payload}');
  });

  // Create Android notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);

  runApp(const HostelApp());
}

class HostelApp extends StatelessWidget {
  const HostelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Hostel Gate Pass',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      routerConfig: _router,
    );
  }
}

/// Small helper so GoRouter refreshes when auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// We'll create the router but we need access to the router instance inside the auth listener,
/// so we create the router lazily below.
late final GoRouter _router = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    // Use state.uri.path (works for older GoRouter versions)
    final currentPath = state.uri.path; // e.g. "/", "/signin", "/student-home"
    final loggingIn = currentPath == '/signin' || currentPath == '/';
    final isResolve = currentPath == '/resolve';

    // If not logged in and trying to access protected pages, send to /signin
    if (!isLoggedIn && !loggingIn && !isResolve) {
      return '/signin';
    }

    // If logged in and on signin/splash, send to /resolve (resolve decides role)
    if (isLoggedIn && loggingIn && !isResolve) {
      return '/resolve';
    }

    // Allowed routes once signed in (add other pages you want allowed directly)
    final allowedWhenSignedIn = {
      '/', '/signin', '/resolve', '/student-home', '/admin', '/qr-scanner',
      '/requested-gate-pass', '/add-student', '/student-list'
    };

    if (isLoggedIn && !allowedWhenSignedIn.contains(currentPath)) {
      return '/resolve';
    }

    return null; // no redirect
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/signin',
      builder: (context, state) => const UniversalSignIn(),
    ),
    GoRoute(
      path: '/resolve',
      builder: (context, state) => const ResolveRolePage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminPanel(),
    ),
    GoRoute(
      path: '/add-student',
      builder: (context, state) => AddStudentPage(),
    ),
    GoRoute(
      path: '/requested-gate-pass',
      builder: (context, state) => const RequestedGatePass(),
    ),
    GoRoute(
      path: '/qr-scanner',
      builder: (context, state) => const QRScannerPage(),
    ),
    GoRoute(
      path: '/student-home',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final studentName = extra['studentName'] ?? 'Student';
        final profileImageUrl = extra['profileImageUrl'] ?? '';

        return StudentHomeScreen(
          studentName: studentName,
          profileImageUrl: profileImageUrl,
        );
      },
    ),
    GoRoute(
      path: '/student-list',
      builder: (context, state) => const StudentListPage(),

    ),
    
  ],
);

/// Attach auth state listener to request permissions, save token and setup handlers.
/// This runs once when the app UI builds (safe to run here).
class _AuthWatcher extends StatefulWidget {
  final Widget child;
  const _AuthWatcher({required this.child, super.key});
  @override
  State<_AuthWatcher> createState() => _AuthWatcherState();
}

class _AuthWatcherState extends State<_AuthWatcher> {
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();

    // Listen auth changes
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        // Request permissions and save token when user signs in
        await _requestNotificationPermissions();
        await _saveFcmTokenForCurrentUser();
        _setupFCMHandlers(_router);
      } else {
        // optional: clear token or do other cleanup if signed out
        debugPrint('User signed out; you may clear token if desired');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
