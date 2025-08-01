import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';

class StudentListPage extends StatefulWidget {
  const StudentListPage({super.key});

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  List<Student> students = [];
  List<Student> filteredStudents = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  Future<void> fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final response =
          await http.get(Uri.parse("http://192.168.13.144:5000/api/students"));
      if (response.statusCode == 200) {
        final List<dynamic> studentList = json.decode(response.body);
        students = studentList.map((json) => Student.fromJson(json)).toList();
        for (var s in students) {
          print('Profile Image: ${s.profileImage}');
        }
        setState(() {
          filteredStudents = students;
          _isLoading = false;
        });
      } else {
        showError("Failed to load students.");
      }
    } catch (e) {
      showError("Error fetching students: $e");
    }
  }

  void _deleteStudent(int id) async {
    try {
      final response =
          await http.delete(Uri.parse("http://192.168.13.144:5000/api/students/$id"));
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Student deleted successfully")),
        );
        fetchStudents();
      } else {
        showError("Failed to delete student.");
      }
    } catch (e) {
      showError("Error deleting student: $e");
    }
  }

  void showError(String message) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _searchStudents(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredStudents = students.where((student) {
        return student.name.toLowerCase().contains(lowerQuery) ||
            student.department.toLowerCase().contains(lowerQuery) ||
            student.guardianName.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this student?"),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel")),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteStudent(id);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student List"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/admin'); // Using go_router to navigate back
          },
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchStudents,
                      decoration: const InputDecoration(
                        labelText: "Search",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filteredStudents.isEmpty
                        ? const Center(child: Text("No students found."))
                        : ListView.builder(
                            itemCount: filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              final baseUrl = 'http://192.168.13.144:5000';
                              final profileImageUrl =
                                  '$baseUrl${student.profileImage?.startsWith('/') ?? false ? '' : '/'}${student.profileImage ?? ''}';

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: (student.profileImage != null &&
                                          student.profileImage!.isNotEmpty)
                                      ? CircleAvatar(
                                          backgroundImage:
                                              NetworkImage(profileImageUrl),
                                        )
                                      : const CircleAvatar(
                                          child: Icon(Icons.person),
                                        ),
                                  title: Text(student.name),
                                  subtitle: Text(
                                      "Dept: ${student.department}\nPhone: ${student.phone}"),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _confirmDelete(student.id),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StudentDetailPage(student: student),
                                      ),
                                    );
                                  },
                                ),
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

class StudentDetailPage extends StatelessWidget {
  final Student student;

  const StudentDetailPage({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final baseUrl = 'http://192.168.13.144:5000';
    final profileImageUrl =
        '$baseUrl${student.profileImage?.startsWith('/') ?? false ? '' : '/'}${student.profileImage ?? ''}';

    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              (student.profileImage != null && student.profileImage!.isNotEmpty)
                  ? CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(profileImageUrl),
                    )
                  : const CircleAvatar(
                      radius: 60,
                      child: Icon(Icons.person, size: 60),
                    ),
              const SizedBox(height: 20),
              detailRow('Name', student.name),
              detailRow('Department', student.department),
              detailRow('Phone', student.phone),
              detailRow('Address', student.address),
              detailRow('Date of Birth', student.dob),
              detailRow('Gender', student.gender),
              detailRow('Guardian Name', student.guardianName),
              detailRow('Guardian Phone', student.guardianPhone),
            ],
          ),
        ),
      ),
    );
  }

  Widget detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class Student {
  final int id;
  final String name;
  final String department;
  final String phone;
  final String address;
  final String dob;
  final String gender;
  final String guardianName;
  final String guardianPhone;
  final String? profileImage;

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
    this.profileImage,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      department: json['department'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      dob: json['dob'] != null ? json['dob'].toString().split('T')[0] : '',

      gender: json['gender'] ?? '',
      guardianName: json['guardianName'] ?? '',
      guardianPhone: json['guardianPhone'] ?? '',
      profileImage: json['profileImage'],
    );
  }
}
