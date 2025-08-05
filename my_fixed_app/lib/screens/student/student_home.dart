// student_home.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Update these imports to the correct relative paths in your project:
import 'gatepass_request.dart';
import 'view_requests.dart';

class StudentHomeScreen extends StatelessWidget {
  final String studentName;
  final String profileImageUrl;

  const StudentHomeScreen({
    Key? key,
    required this.studentName,
    required this.profileImageUrl,
  }) : super(key: key);

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
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // close loading
      context.go('/signin'); // navigate to sign in route
    } catch (e) {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 21, 15, 135),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/signin'),
        ),
        title: Center(
          child: Text(
            studentName,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) as ImageProvider : null,
              radius: 18,
              child: profileImageUrl.isEmpty ? const Icon(Icons.person) : null,
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
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
                // Use Navigator.push with the correct widget (no const if constructor not const)
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GatePassRequest()),
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
                  MaterialPageRoute(builder: (context) => MyGatePass()),
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
              Icon(icon, size: 40, color: const Color(0xFF6C63FF)),
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
