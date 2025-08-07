// lib/screens/resolve_role.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class ResolveRolePage extends StatefulWidget {
  const ResolveRolePage({Key? key}) : super(key: key);

  @override
  State<ResolveRolePage> createState() => _ResolveRolePageState();
}

class _ResolveRolePageState extends State<ResolveRolePage> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) context.go('/signin');
      return;
    }

    try {
      // Fetch role from users collection
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final role = (doc.data()?['role'] ?? 'student').toString().toLowerCase();

      if (!mounted) return;

      switch (role) {
        case 'admin':
          context.go('/admin');
          break;

        case 'security':
          context.go('/qr-scanner');
          break;

        case 'student':
        default:
          // For students, try to find the student doc and pass extras to student-home.
          final studentsCol = FirebaseFirestore.instance.collection('students');

          DocumentSnapshot<Map<String, dynamic>>? studentDoc;

          // 1) Try by uid
          final byUid = await studentsCol.where('uid', isEqualTo: user.uid).limit(1).get();
          if (byUid.docs.isNotEmpty) {
            studentDoc = byUid.docs.first;
          } else {
            // 2) Try by username (where username == user's email)
            final byUsername = await studentsCol.where('username', isEqualTo: user.email).limit(1).get();
            if (byUsername.docs.isNotEmpty) {
              studentDoc = byUsername.docs.first;
            } else {
              // 3) Try by email field
              final byEmail = await studentsCol.where('email', isEqualTo: user.email).limit(1).get();
              if (byEmail.docs.isNotEmpty) studentDoc = byEmail.docs.first;
            }
          }

          if (studentDoc != null) {
            final sdata = studentDoc.data()!;
            final studentName = (sdata['name'] ?? '').toString();
            final profileImageUrl = (sdata['profileImageUrl'] ?? '').toString();

            // Pass extras to student-home
            context.go('/student-home', extra: {
              'studentName': studentName,
              'profileImageUrl': profileImageUrl,
              'studentDocId': studentDoc.id,
              'uid': user.uid,
            });
          } else {
            // If student record not found, still go to student-home (no extras)
            // You may alternatively route to an error page or ask user to contact admin.
            context.go('/student-home');
          }
          break;
      }
    } catch (e) {
      // On any error, fallback to student-home (or change to /signin if preferred)
      if (mounted) context.go('/student-home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
