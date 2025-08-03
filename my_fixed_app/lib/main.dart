import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

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

void main() {
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

/// ✅ Centralized Route Configuration using GoRouter
final GoRouter _router = GoRouter(
  initialLocation: '/',
  // Optional redirect logic for future authentication (uncomment to use)
  /*
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    if (!isLoggedIn && state.location != '/signin') {
      return '/signin';
    }
    return null;
  },
  */
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
        final extra = state.extra as Map<String, dynamic>?;

        final studentName = extra?['studentName'] ?? 'Student';
        final profileImageUrl = extra?['profileImageUrl'] ?? '';

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
