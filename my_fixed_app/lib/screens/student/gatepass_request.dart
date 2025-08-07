// gatepass_request.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class GatePassRequest extends StatefulWidget {
  const GatePassRequest({super.key});

  @override
  _GatePassRequestState createState() => _GatePassRequestState();
}

class _GatePassRequestState extends State<GatePassRequest> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final rollController = TextEditingController();
  final deptController = TextEditingController();
  final reasonController = TextEditingController();
  final departureController = TextEditingController();
  final returnController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingStudent = true;

  // Use the same blue used elsewhere
  static const Color appBlue = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() => _isLoadingStudent = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingStudent = false);
        return;
      }

      final studentsCol = FirebaseFirestore.instance.collection('students');

      DocumentSnapshot<Map<String, dynamic>>? studentDoc;

      // 1) Try by uid
      final byUid = await studentsCol.where('uid', isEqualTo: user.uid).limit(1).get();
      if (byUid.docs.isNotEmpty) {
        studentDoc = byUid.docs.first;
      } else {
        // 2) Try by username (username now is rollNumber in your setup)
        // If user's email equals synthetic auth email, you might want to parse roll from it.
        // Fallback to searching by authEmail or rollNumber fields.
        final byUsername = await studentsCol.where('username', isEqualTo: user.email).limit(1).get();
        if (byUsername.docs.isNotEmpty) {
          studentDoc = byUsername.docs.first;
        } else {
          final byAuthEmail = await studentsCol.where('authEmail', isEqualTo: user.email).limit(1).get();
          if (byAuthEmail.docs.isNotEmpty) studentDoc = byAuthEmail.docs.first;
        }
      }

      if (studentDoc != null) {
        final data = studentDoc.data()!;
        nameController.text = (data['name'] ?? '').toString();
        // Use rollNumber (not 'roll')
        rollController.text = (data['rollNumber'] ?? data['username'] ?? '').toString();
        // department field fallback to 'department' or 'dept'
        deptController.text = (data['department'] ?? data['dept'] ?? '').toString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load student data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingStudent = false);
    }
  }

  Future<void> submitRequest() async {
    // Only validate the editable fields (reason, times)
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final email = user?.email;

    setState(() => _isSubmitting = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('gatepass_requests').doc();

      final data = {
        'uid': uid ?? '',
        'email': email ?? '',
        'studentName': nameController.text.trim(),
        // store rollNumber key consistently
        'rollNumber': rollController.text.trim(),
        'department': deptController.text.trim(),
        'reason': reasonController.text.trim(),
        'departureTime': departureController.text.trim(),
        'returnTime': returnController.text.trim(),
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    rollController.dispose();
    deptController.dispose();
    reasonController.dispose();
    departureController.dispose();
    returnController.dispose();
    super.dispose();
  }

  Widget _buildFormField(String label, IconData icon, TextEditingController controller,
      {int maxLines = 1, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        // Only validate if the field is editable (user should fill it)
        validator: readOnly
            ? null
            : (v) => v == null || v.trim().isEmpty ? '$label is required' : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: appBlue),
          floatingLabelStyle: const TextStyle(color: appBlue),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: appBlue, width: 2),
          ),
          // Make readOnly fields visually a bit disabled while still clear
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.shade100 : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loader while student data is loading
    if (_isLoadingStudent) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Gate Pass'),
        backgroundColor: appBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Read-only fields for student identity
              _buildFormField('Full Name', Icons.person_outline, nameController, readOnly: true),
              _buildFormField('Roll Number', Icons.numbers_outlined, rollController, readOnly: true),
              _buildFormField('Department', Icons.school_outlined, deptController, readOnly: true),

              // Editable fields
              _buildFormField('Reason for Leave', Icons.note_outlined, reasonController, maxLines: 4),
              _buildFormField('Departure Time', Icons.access_time_outlined, departureController),
              _buildFormField('Return Time', Icons.access_time_outlined, returnController),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : submitRequest,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(MaterialState.disabled)) return appBlue.withOpacity(0.6);
                    return appBlue;
                  }),
                  minimumSize: MaterialStateProperty.all(const Size(double.infinity, 50)),
                  overlayColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed)) return appBlue.withOpacity(0.85);
                    return null;
                  }),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
