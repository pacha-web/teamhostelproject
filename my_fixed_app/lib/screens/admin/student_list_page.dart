import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StudentListPage extends StatefulWidget {
  const StudentListPage({super.key});

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to map a Firestore doc to Student model
  Student _studentFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Student(
      id: doc.id,
      name: data['name'] ?? '',
      department: data['department'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      dob: data['dob'] ?? '',
      gender: data['gender'] ?? '',
      guardianName: data['guardianName'] ?? '',
      guardianPhone: data['guardianPhNo'] ?? '',
      profileImageUrl: (data['profileImageUrl'] is String)
          ? data['profileImageUrl'] as String
          : '',
    );
  }

  // Delete document by doc id
  Future<void> _deleteStudent(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete error: $e')),
        );
      }
    }
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this student? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteStudent(docId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Filter function client-side (simple substring search)
  bool _matchesQuery(Student s) {
    if (_query.isEmpty) return true;
    final lower = _query;
    return s.name.toLowerCase().contains(lower) ||
        s.department.toLowerCase().contains(lower) ||
        s.guardianName.toLowerCase().contains(lower) ||
        s.phone.toLowerCase().contains(lower);
  }

  @override
  Widget build(BuildContext context) {
    // Stream students ordered by createdAt (descending). If you didn't store createdAt, you can order by name.
    final stream = FirebaseFirestore.instance
        .collection('students')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student List'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search students...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),

            // Streamed list
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  final students = docs.map(_studentFromDoc).toList();

                  // Client-side filtering
                  final filtered = students.where(_matchesQuery).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No students found.'));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      return StudentListTile(
                        student: student,
                        onDelete: () => _confirmDelete(student.id),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentDetailPage(student: student),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Student list tile widget to improve code readability
class StudentListTile extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const StudentListTile({
    super.key,
    required this.student,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: (student.profileImageUrl != null && student.profileImageUrl!.isNotEmpty)
            ? CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(student.profileImageUrl!),
              )
            : CircleAvatar(
                radius: 30,
                backgroundColor: Colors.indigo.shade100,
                child: const Icon(Icons.person, color: Colors.blue),
              ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Department: ${student.department}'),
            Text('Phone: ${student.phone}'),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
        onTap: onTap,
      ),
    );
  }
}

// Student model adapted for Firestore doc id string
class Student {
  final String id;
  final String name;
  final String department;
  final String phone;
  final String address;
  final String dob;
  final String gender;
  final String guardianName;
  final String guardianPhone;
  final String? profileImageUrl;

  Student({
    required this.id,
    required this.name,
    required this.department,
    required this.phone,
    required this.address,
    required this.dob,
    required this.gender,
    required this.guardianName,
    required this.guardianPhone,
    this.profileImageUrl,
  });
}

// Details page (re-usable for Firestore-backed Student)
class StudentDetailPage extends StatelessWidget {
  final Student student;
  const StudentDetailPage({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: (student.profileImageUrl != null && student.profileImageUrl!.isNotEmpty)
                    ? CircleAvatar(
                        radius: 80,
                        backgroundImage: NetworkImage(student.profileImageUrl!),
                      )
                    : CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.indigo.shade100,
                        child: const Icon(Icons.person, size: 80, color: Colors.indigo),
                      ),
              ),
              const SizedBox(height: 32),
              _detailCard('Name', student.name),
              _detailCard('Department', student.department),
              _detailCard('Phone', student.phone),
              _detailCard('Address', student.address),
              _detailCard('Date of Birth', student.dob),
              _detailCard('Gender', student.gender),
              _detailCard('Guardian Name', student.guardianName),
              _detailCard('Guardian Phone', student.guardianPhone),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}