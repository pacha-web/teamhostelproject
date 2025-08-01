import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/signin'), // ✅ Fixed route to Sign In page
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => context.push('/add-student'),
              icon: const Icon(Icons.person_add),
              label: const Text("Add Student"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () => context.go('/student-list'), // ✅ Go to student list
              icon: const Icon(Icons.list),
              label: const Text("Student List"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () => context.push('/requested-gate-pass'),
              icon: const Icon(Icons.assignment),
              label: const Text("Requested Gate Pass"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
