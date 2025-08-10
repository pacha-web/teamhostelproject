import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int totalStudents = 0;
  int outStudents = 0;
  bool isLoading = true;
  List<Map<String, dynamic>> outStudentDetails = [];
  List<Map<String, dynamic>> inStudentDetails = [];

  @override
  void initState() {
    super.initState();
    _loadStatsAndDetails();
  }

  Future<void> _loadStatsAndDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      final studentsSnapshot =
          await FirebaseFirestore.instance.collection('students').get();

      int outCount = 0;
      List<Map<String, dynamic>> outList = [];
      List<Map<String, dynamic>> inList = [];

      for (final student in studentsSnapshot.docs) {
        final studentData = student.data();

        final gatepasses = await FirebaseFirestore.instance
            .collection('students')
            .doc(student.id)
            .collection('gatepasses')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        String lastStatus = 'In'; // default assume in if no gatepass
        if (gatepasses.docs.isNotEmpty) {
          lastStatus = gatepasses.docs.first.data()['status'] ?? 'In';
        }

        final studentDetails = {
          'name': studentData['name'] ?? 'N/A',
          'roll': studentData['rollNumber'] ?? 'N/A',
          'department': studentData['department'] ?? 'N/A',
        };

        if (lastStatus == 'Out') {
          outCount++;
          outList.add(studentDetails);
        } else {
          inList.add(studentDetails);
        }
      }

      setState(() {
        totalStudents = studentsSnapshot.docs.length;
        outStudents = outCount;
        outStudentDetails = outList;
        inStudentDetails = inList;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        context.go('/signin');
      }
    }
  }

  Widget _buildStatBox(String label, int value, IconData icon, List<Color> colors,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(4, 4))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 30, color: Theme.of(context).primaryColor),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentListDialog(
      BuildContext context, String title, List<Map<String, dynamic>> students) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: students.isEmpty
              ? const Text('No students to display.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final s = students[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(s['name'][0])),
                      title: Text(s['name']),
                      subtitle: Text(
                          'Roll: ${s['roll']}  |  Dept: ${s['department']}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStrength = totalStudents - outStudents;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildStatBox(
                        "Total Students",
                        totalStudents,
                        Icons.group,
                        [Colors.blue.shade800, Colors.blue.shade500],
                      ),
                      _buildStatBox(
                        "Out Students",
                        outStudents,
                        Icons.exit_to_app,
                        [Colors.red.shade800, Colors.red.shade500],
                        onTap: () => _showStudentListDialog(
                            context, 'Out Students', outStudentDetails),
                      ),
                      _buildStatBox(
                        "Current Strength",
                        currentStrength,
                        Icons.home,
                        [Colors.green.shade800, Colors.green.shade500],
                        onTap: () => _showStudentListDialog(
                            context, 'Current Strength', inStudentDetails),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildMenuItem(
                    "Add Student",
                    Icons.person_add,
                    () => context.push('/add-student'),
                  ),
                  const SizedBox(height: 10),
                  _buildMenuItem(
                    "Student List",
                    Icons.list,
                    () => context.go('/student-list'),
                  ),
                  const SizedBox(height: 10),
                  _buildMenuItem(
                    "Requested Gate Pass",
                    Icons.assignment,
                    () => context.push('/requested-gate-pass'),
                  ),
                ],
              ),
            ),
    );
  }
}

