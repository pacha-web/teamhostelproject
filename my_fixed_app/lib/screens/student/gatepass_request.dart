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

  Future<void> submitRequest() async {
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
        'roll': rollController.text.trim(),
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
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (v) => v == null || v.trim().isEmpty ? '$label is required' : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Gate Pass'),
        backgroundColor: const Color.fromARGB(255, 23, 16, 161),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildFormField('Full Name', Icons.person_outline, nameController),
              _buildFormField('Roll Number', Icons.numbers_outlined, rollController),
              _buildFormField('Department', Icons.school_outlined, deptController),
              _buildFormField('Reason for Leave', Icons.note_outlined, reasonController, maxLines: 4),
              _buildFormField('Departure Time', Icons.access_time_outlined, departureController),
              _buildFormField('Return Time', Icons.access_time_outlined, returnController),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 17, 9, 172),
                  minimumSize: const Size(double.infinity, 50),
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
