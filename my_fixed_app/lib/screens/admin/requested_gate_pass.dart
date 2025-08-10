import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RequestedGatePass extends StatefulWidget {
  const RequestedGatePass({super.key});

  @override
  State<RequestedGatePass> createState() => _RequestedGatePassState();
}

class _RequestedGatePassState extends State<RequestedGatePass> {
  String _searchQuery = '';
  String _filterStatus = 'Pending'; // Default to show only pending requests

  final Set<String> selectedRequests = {};

  @override
  void initState() {
    super.initState();
  }

  // Update status in Firestore
  Future<void> updateRequestStatus(String docId, String newStatus) async {
    final ref = FirebaseFirestore.instance.collection('gatepass_requests').doc(docId);
    try {
      await ref.update({
        'status': newStatus,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
      }
      setState(() {
        selectedRequests.remove(docId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  // Delete selected requests
  Future<void> deleteSelectedRequests() async {
    if (selectedRequests.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No requests selected')));
      }
      return;
    }

    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${selectedRequests.length} selected request(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final docId in selectedRequests) {
        final docRef = FirebaseFirestore.instance.collection('gatepass_requests').doc(docId);
        batch.delete(docRef);
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected requests deleted')));
      }
      setState(() {
        selectedRequests.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete requests: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stream requests ordered by creation time
    final stream = FirebaseFirestore.instance
        .collection('gatepass_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Gate Pass Requests"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (selectedRequests.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete Selected',
              onPressed: deleteSelectedRequests,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter and Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search by name or roll...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _filterStatus,
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All')),
                        DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                        DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                      ],
                      onChanged: (value) => setState(() => _filterStatus = value ?? 'Pending'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Streamed list of requests
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
                    .where((doc) {
                      final data = doc.data();
                      final status = (data['status'] ?? 'Pending').toString();
                      final statusOk = _filterStatus == 'All' || status == _filterStatus;
                      if (!statusOk) return false;

                      if (_searchQuery.isEmpty) return true;
                      final name = (data['studentName'] ?? '').toString().toLowerCase();
                      final roll = (data['rollNumber'] ?? '').toString().toLowerCase();
                      return name.contains(_searchQuery) || roll.contains(_searchQuery);
                    })
                    .toList();

                if (requests.isEmpty) {
                  return const Center(child: Text('No matching requests.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index].data();
                    final id = requests[index].id;
                    final isSelected = selectedRequests.contains(id);

                    return RequestedGatePassListItem(
                      key: ValueKey(id),
                      request: {'id': id, ...request},
                      isSelected: isSelected,
                      onSelectionChanged: (selected) {
                        setState(() {
                          if (selected) {
                            selectedRequests.add(id);
                          } else {
                            selectedRequests.remove(id);
                          }
                        });
                      },
                      onApprove: () => updateRequestStatus(id, 'Approved'),
                      onReject: () => updateRequestStatus(id, 'Rejected'),
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

class RequestedGatePassListItem extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const RequestedGatePassListItem({
    required Key key,
    required this.request,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onApprove,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = (request['status'] ?? 'Pending').toString();
    Color statusColor;
    switch (status) {
      case 'Approved':
        statusColor = Colors.green;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
        break;
    }

    // Safely parse date and time
    String formatDateTime(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return DateFormat('MMM d, yyyy - hh:mm a').format(timestamp.toDate());
      }
      return 'N/A';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    request['studentName'] ?? 'N/A',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  onChanged: (val) => onSelectionChanged(val ?? false),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: Text("Roll No: ${request['rollNumber'] ?? 'N/A'}")),
                Expanded(child: Text("Dept: ${request['department'] ?? 'N/A'}")),
              ],
            ),
            const SizedBox(height: 12),
            Text("Reason: ${request['reason'] ?? 'N/A'}"),
            const SizedBox(height: 12),
            Text("Departure: ${request['departureTime'] ?? 'N/A'}"),
            Text("Return: ${request['returnTime'] ?? 'N/A'}"),
            const SizedBox(height: 12),
            Text(
              'Requested on: ${formatDateTime(request['createdAt'])}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            if (status == 'Pending')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Approve', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}