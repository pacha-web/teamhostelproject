// requested_gatepass.dart
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RequestedGatePass extends StatefulWidget {
  const RequestedGatePass({super.key});

  @override
  State<RequestedGatePass> createState() => _RequestedGatePassState();
}

class _RequestedGatePassState extends State<RequestedGatePass> {
  String _searchQuery = '';
  String _filterStatus = 'All';

  // Update status in Firestore
  Future<void> updateRequestStatus(String docId, String newStatus) async {
    final ref = FirebaseFirestore.instance.collection('gatepass_requests').doc(docId);
    try {
      await ref.update({
        'status': newStatus,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('gatepass_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F9),
      appBar: AppBar(
        title: const Text("Requested Gate Passes"),
        backgroundColor: const Color.fromARGB(255, 23, 16, 161),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by name or roll...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => setState(() => _filterStatus = value ?? 'All'),
            ),
          ),
          const SizedBox(height: 10),
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
                // Map and filter client-side
                final requests = docs
                    .map((d) => {'id': d.id, ...?d.data()})
                    .where((r) {
                      final statusOk = _filterStatus == 'All' || (r['status'] ?? 'Pending') == _filterStatus;
                      if (!statusOk) return false;
                      if (_searchQuery.isEmpty) return true;
                      final name = (r['studentName'] ?? '').toString().toLowerCase();
                      final roll = (r['roll'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || roll.contains(_searchQuery);
                    })
                    .toList();

                if (requests.isEmpty) {
                  return const Center(child: Text('No matching requests.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final status = (request['status'] ?? 'Pending').toString();

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
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      // profile image not stored here; placeholder
                                      child: const Icon(Icons.person),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(
                                      request['studentName'] ?? '',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    )),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: status == 'Approved'
                                            ? Colors.green.withOpacity(0.8)
                                            : status == 'Rejected'
                                                ? Colors.red.withOpacity(0.8)
                                                : Colors.orange.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text("Roll No: ${request['roll'] ?? ''}"),
                                Text("Dept: ${request['department'] ?? ''}"),
                                const SizedBox(height: 6),
                                Text("Reason: ${request['reason'] ?? ''}"),
                                const SizedBox(height: 6),
                                Text("Departure: ${request['departureTime'] ?? ''}"),
                                Text("Return: ${request['returnTime'] ?? ''}"),
                                const SizedBox(height: 8),
                                Text(
                                  request['createdAt'] != null && request['createdAt'] is Timestamp
                                      ? (request['createdAt'] as Timestamp).toDate().toString()
                                      : (request['createdAt'] ?? '').toString(),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(height: 10),
                                if (status == 'Pending')
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => updateRequestStatus(request['id'], 'Approved'),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Approve'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => updateRequestStatus(request['id'], 'Rejected'),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Reject'),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
