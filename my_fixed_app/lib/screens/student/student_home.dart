// student_home.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
    _studentName = widget.studentName;
    _profileImageUrl = widget.profileImageUrl;

    _loadStudentData(initialLoad: _studentName.isEmpty && _profileImageUrl.isEmpty);

    // Save FCM token
    _saveFcmToken();

    // Optional: Listen to token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _saveFcmToken(token: newToken);
    });
  }

  Future<void> _saveFcmToken({String? token}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final fcmToken = token ?? await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': fcmToken,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  Future<void> _loadStudentData({bool initialLoad = false}) async {
    if (initialLoad) {
      setState(() => _loading = true);
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final studentsCol = FirebaseFirestore.instance.collection('students');

      DocumentSnapshot<Map<String, dynamic>>? studentDoc;

      final byUid = await studentsCol.where('uid', isEqualTo: user.uid).limit(1).get();
      if (byUid.docs.isNotEmpty) {
        studentDoc = byUid.docs.first;
      } else {
        final byUsername = await studentsCol.where('username', isEqualTo: user.email).limit(1).get();
        if (byUsername.docs.isNotEmpty) {
          studentDoc = byUsername.docs.first;
        } else {
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
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
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
