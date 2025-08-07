import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
          backgroundColor: Color.fromARGB(255, 26, 26, 155),
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

/// GoRouter Config (role-aware, uses state.uri.path to be compatible with older GoRouter)
final GoRouter _router = GoRouter(
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
