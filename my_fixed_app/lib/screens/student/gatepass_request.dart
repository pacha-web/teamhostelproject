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

  DateTime? _departureDateTime;
  DateTime? _returnDateTime;

  bool _isSubmitting = false;
  bool _isLoadingStudent = true;

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

      final byUid = await studentsCol.where('uid', isEqualTo: user.uid).limit(1).get();
      if (byUid.docs.isNotEmpty) {
        studentDoc = byUid.docs.first;
      } else {
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
        rollController.text = (data['rollNumber'] ?? data['username'] ?? '').toString();
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
    if (!_formKey.currentState!.validate()) return;

    if (_departureDateTime == null || _returnDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both Departure and Return Date & Time')),
      );
      return;
    }

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
        'rollNumber': rollController.text.trim(),
        'department': deptController.text.trim(),
        'reason': reasonController.text.trim(),
        'departureTime': _departureDateTime!.toIso8601String(),
        'returnTime': _returnDateTime!.toIso8601String(),
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
        validator: readOnly ? null : (v) => v == null || v.trim().isEmpty ? '$label is required' : null,
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
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.shade100 : null,
        ),
      ),
    );
  }

  Widget _buildDateTimeField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final formatted = value != null ? _formatDateTime(value) : 'Select $label';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: _isSubmitting ? null : onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.access_time_outlined, color: appBlue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            formatted,
            style: TextStyle(color: value != null ? Colors.black : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatDateTime(DateTime dt) {
    return '${_formatDate(dt)} at ${_formatTime(dt)}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
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
              _buildFormField('Full Name', Icons.person_outline, nameController, readOnly: true),
              _buildFormField('Roll Number', Icons.numbers_outlined, rollController, readOnly: true),
              _buildFormField('Department', Icons.school_outlined, deptController, readOnly: true),
              _buildFormField('Reason for Leave', Icons.note_outlined, reasonController, maxLines: 4),
              _buildDateTimeField(
                label: 'Departure Date & Time',
                value: _departureDateTime,
                onTap: () async {
                  final picked = await _pickDateTime(context);
                  if (picked != null) setState(() => _departureDateTime = picked);
                },
              ),
              _buildDateTimeField(
                label: 'Return Date & Time',
                value: _returnDateTime,
                onTap: () async {
                  final picked = await _pickDateTime(context);
                  if (picked != null) setState(() => _returnDateTime = picked);
                },
              ),
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
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
