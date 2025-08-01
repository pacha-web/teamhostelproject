import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RequestedGatePass extends StatefulWidget {
  const RequestedGatePass({super.key});

  @override
  State<RequestedGatePass> createState() => _RequestedGatePassState();
}

class _RequestedGatePassState extends State<RequestedGatePass> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  String _searchQuery = '';
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    try {
      final response =
          await http.get(Uri.parse("http://192.168.13.144:5000/api/requests"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _requests = data.map((item) => {
                'id': item['id'],
                'studentName': item['studentName'],
                'roll': item['roll'],
                'department': item['department'],
                'reason': item['reason'],
                'departureTime': item['departureTime'],
                'returnTime': item['returnTime'],
                'createdAt': item['createdAt'],
                'status': item['status'],
                'profileImage': item['profileImage'],
              }).toList();
          _isLoading = false;
        });
      } else {
        throw Exception("Failed to load data");
      }
    } catch (e) {
      print("Error fetching requests: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void updateRequestStatus(int index, String newStatus) async {
    final id = _requests[index]['id'];
    final response = await http.put(
      Uri.parse("http://192.168.13.144:5000/api/requests/$id/status"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({'status': newStatus}),
    );

    if (response.statusCode == 200) {
      setState(() {
        _requests[index]['status'] = newStatus;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
      );
    }
  }

  void approveRequest(int index) => updateRequestStatus(index, 'Approved');
  void rejectRequest(int index) => updateRequestStatus(index, 'Rejected');

  List<Map<String, dynamic>> get filteredRequests {
    return _requests.where((request) {
      final matchesStatus =
          _filterStatus == 'All' || request['status'] == _filterStatus;
      final matchesSearch = request['studentName']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          request['roll'].toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      appBar: AppBar(
        title: const Text("Requested Gate Passes"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: const Color.fromARGB(255, 23, 16, 161),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search by name or roll...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: DropdownButtonFormField<String>(
                    value: _filterStatus,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All')),
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                      DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Filter by Status',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _filterStatus = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: filteredRequests.isEmpty
                      ? const Center(child: Text("No matching requests."))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredRequests.length,
                          itemBuilder: (context, index) {
                            final request = filteredRequests[index];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundImage:
                                                  request['profileImage'] != null
                                                      ? NetworkImage(
                                                          "http://192.168.13.144:5000${request['profileImage']}")
                                                      : null,
                                              child: request['profileImage'] == null
                                                  ? const Icon(Icons.person)
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                request['studentName'],
                                                style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: request['status'] == 'Approved'
                                                    ? Colors.green.withOpacity(0.8)
                                                    : request['status'] == 'Rejected'
                                                        ? Colors.red.withOpacity(0.8)
                                                        : Colors.orange.withOpacity(0.8),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                request['status'],
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text("Roll No: ${request['roll']}"),
                                        Text("Dept: ${request['department']}"),
                                        Text("Reason: ${request['reason']}"),
                                        Text("Departure: ${request['departureTime']}"),
                                        Text("Return: ${request['returnTime']}"),
                                        Text("Date: ${request['createdAt'].substring(0, 10)}"),
                                        const SizedBox(height: 10),
                                        if (request['status'] == 'Pending')
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.check, color: Colors.green),
                                                onPressed: () => approveRequest(
                                                    _requests.indexWhere((r) => r['id'] == request['id'])),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.close, color: Colors.red),
                                                onPressed: () => rejectRequest(
                                                    _requests.indexWhere((r) => r['id'] == request['id'])),
                                              ),
                                            ],
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
