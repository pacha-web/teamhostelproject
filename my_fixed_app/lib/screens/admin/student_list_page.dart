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
      profileImageUrl: (data['profileImageUrl'] is String) ? data['profileImageUrl'] as String : '',
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
        content: const Text('Are you sure you want to delete this student?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteStudent(docId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
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

                  // Client-side filtering (simple)
                  final filtered = students.where(_matchesQuery).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No students found.'));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final student = filtered[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: (student.profileImageUrl != null && student.profileImageUrl!.isNotEmpty)
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(student.profileImageUrl!),
                                )
                              : const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(student.name),
                          subtitle: Text('Dept: ${student.department}\nPhone: ${student.phone}'),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelete(student.id),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentDetailPage(student: student),
                              ),
                            );
                          },
                        ),
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              (student.profileImageUrl != null && student.profileImageUrl!.isNotEmpty)
                  ? CircleAvatar(radius: 60, backgroundImage: NetworkImage(student.profileImageUrl!))
                  : const CircleAvatar(radius: 60, child: Icon(Icons.person, size: 60)),
              const SizedBox(height: 20),
              _detailRow('Name', student.name),
              _detailRow('Department', student.department),
              _detailRow('Phone', student.phone),
              _detailRow('Address', student.address),
              _detailRow('Date of Birth', student.dob),
              _detailRow('Gender', student.gender),
              _detailRow('Guardian Name', student.guardianName),
              _detailRow('Guardian Phone', student.guardianPhone),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
