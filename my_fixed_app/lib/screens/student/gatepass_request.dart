import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GatePassRequest extends StatefulWidget {
  const GatePassRequest({super.key});

  @override
  _GatePassRequestState createState() => _GatePassRequestState();
}

class _GatePassRequestState extends State<GatePassRequest> {
  final nameController = TextEditingController();
  final rollController = TextEditingController();
  final deptController = TextEditingController();
  final reasonController = TextEditingController();
  final departureController = TextEditingController();
  final returnController = TextEditingController();

  Future<void> submitRequest() async {
    final url = Uri.parse("http://192.168.13.144:5000/api/requests");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        "name": nameController.text,
        "roll": rollController.text,
        "department": deptController.text,
        "reason": reasonController.text,
        "departureTime": departureController.text,
        "returnTime": returnController.text,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted successfully')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit request')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Gate Pass', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 23, 16, 161),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            _buildFormField("Full Name", Icons.person_outline, nameController),
            _buildFormField("Roll Number", Icons.numbers_outlined, rollController),
            _buildFormField("Department", Icons.school_outlined, deptController),
            _buildFormField("Reason for Leave", Icons.note_outlined, reasonController, maxLines: 3),
            _buildFormField("Departure Time", Icons.access_time_outlined, departureController),
            _buildFormField("Return Time", Icons.access_time_outlined, returnController),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 17, 9, 172),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(String label, IconData icon, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}