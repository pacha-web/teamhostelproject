// student_home.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'gatepass_request.dart';
import 'view_requests.dart';

class StudentHomeScreen extends StatefulWidget {
  final String studentName;
  final String profileImageUrl;

  const StudentHomeScreen({
    Key? key,
    required this.studentName,
    required this.profileImageUrl,
  }) : super(key: key);

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  late String _studentName;
  late String _profileImageUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Start with provided extras (may be empty strings)
    _studentName = widget.studentName;
    _profileImageUrl = widget.profileImageUrl;

    // If we already have values, still attempt to refresh in background.
    // If values are empty, wait and show loader until fetched.
    _loadStudentData(initialLoad: _studentName.isEmpty && _profileImageUrl.isEmpty);
  }

  Future<void> _loadStudentData({bool initialLoad = false}) async {
    if (initialLoad) {
      setState(() => _loading = true);
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Not signed in — leave defaults and stop loading
        if (mounted) setState(() => _loading = false);
        return;
      }

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
        final data = studentDoc.data()!;
        final name = (data['name'] ?? '').toString();
        final profile = (data['profileImageUrl'] ?? '').toString();

        if (mounted) {
          setState(() {
            _studentName = name.isNotEmpty ? name : _studentName;
            _profileImageUrl = profile.isNotEmpty ? profile : _profileImageUrl;
            _loading = false;
          });
        }
      } else {
        // No student doc found — stop loading but keep whatever we had
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      // On error, just stop loading and keep defaults
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load student data: $e')));
      }
    }
  }

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final doLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Logout')),
        ],
      ),
    );

    if (doLogout != true) return;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      await FirebaseAuth.instance.signOut();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      context.go('/signin');
    } catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // While loading initial data show a simple loader to avoid empty title/avatar flash
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          _studentName.isNotEmpty ? _studentName : 'Student',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              backgroundImage: _profileImageUrl.isNotEmpty ? NetworkImage(_profileImageUrl) as ImageProvider : null,
              radius: 18,
              child: _profileImageUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _confirmAndSignOut(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8F9FA), Colors.white],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            _buildFeatureCard(
              context,
              "Request Gate Pass",
              Icons.note_add_outlined,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GatePassRequest()),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildFeatureCard(
              context,
              "View My Requests",
              Icons.list_alt_outlined,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyGatePass()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.blue),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}
