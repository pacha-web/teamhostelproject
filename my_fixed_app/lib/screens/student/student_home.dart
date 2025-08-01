// student_home.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'gatepass_request.dart';
import 'view_requests.dart';

class StudentHomeScreen extends StatelessWidget {
  final String studentName;
  final String profileImageUrl;

  const StudentHomeScreen({
    super.key,
    required this.studentName,
    required this.profileImageUrl,
  });

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
          CircleAvatar(
            backgroundImage: NetworkImage(profileImageUrl),
            radius: 18,
          ),
          const SizedBox(width: 12),
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
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GatePassRequest()),
              ),
            ),
            const SizedBox(height: 20),
            _buildFeatureCard(
              context,
              "View My Requests",
              Icons.list_alt_outlined,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ViewRequests()),
              ),
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
            // Wrap title in Expanded to prevent overflow
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
