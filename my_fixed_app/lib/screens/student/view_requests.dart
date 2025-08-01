import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ViewRequests extends StatefulWidget {
  const ViewRequests({super.key});

  @override
  State<ViewRequests> createState() => _ViewRequestsState();
}

class _ViewRequestsState extends State<ViewRequests> {
  List<dynamic> requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    try {
      final url = Uri.parse("http://192.168.13.144:5000/api/my-requests");
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer YOUR_TOKEN', // replace or remove if unused
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          requests = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch requests: $e')),
      );
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget buildStatusMessage(String status) {
    if (status == 'Approved') {
      return const Text(
        '✅ Your gate pass has been accepted. Please show this message at the gate.',
        style: TextStyle(fontSize: 14, color: Colors.green),
      );
    } else if (status == 'Rejected') {
      return const Text(
        '❌ Your gate pass request was rejected by the admin.',
        style: TextStyle(fontSize: 14, color: Colors.red),
      );
    } else {
      return const Text(
        '⏳ Your request is under review.',
        style: TextStyle(fontSize: 14, color: Colors.orange),
      );
    }
  }

  Widget buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        "$label: ${value ?? 'N/A'}",
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Gate Pass Requests'),
        backgroundColor: Colors.blueAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(child: Text('No requests found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    final status = req['status'] ?? 'Pending';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildDetailRow("Reason", req['reason']),
                            buildDetailRow("Departure Time", req['departureTime']),
                            buildDetailRow("Return Time", req['returnTime']),
                            buildDetailRow("Date Requested", req['createdAt']?.substring(0, 10)),
                            const SizedBox(height: 8),
                            Text(
                              'Status: $status',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: getStatusColor(status),
                              ),
                            ),
                            const SizedBox(height: 12),
                            buildStatusMessage(status),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
