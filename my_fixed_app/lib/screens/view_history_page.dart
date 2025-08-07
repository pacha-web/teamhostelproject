import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ViewHistoryScreen extends StatelessWidget {
  const ViewHistoryScreen({Key? key}) : super(key: key);

  // Use the same app blue color
  static const Color appBlue = Colors.blue;

  void _showHistoryDialog(BuildContext context, String name, String roll, String dept) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('History: $name ($roll)'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _getGatepasses(roll),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Text('Error loading data');
              }

              final docs = snapshot.data ?? [];

              final Map<String, Map<String, dynamic>> history = {};

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                final status = data['status'];
                final scannedDataStr = data['scannedData'] ?? '{}';

                if (timestamp == null || !(status == 'In' || status == 'Out')) continue;

                final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);
                final parsed = jsonDecode(scannedDataStr);

                history[dateKey] ??= {};
                history[dateKey]![status] = timestamp;

                if (!history[dateKey]!.containsKey('reason')) {
                  history[dateKey]!['reason'] = parsed['reason'] ?? 'N/A';
                }
              }

              if (history.isEmpty) return const Text('No history available.');

              return SingleChildScrollView(
                child: Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(3),
                    3: FlexColumnWidth(5),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: appBlue.withOpacity(0.2)),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Out Time', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('In Time', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    ...history.entries.map((entry) {
                      final date = entry.key;
                      final out = entry.value['Out'] as DateTime?;
                      final inn = entry.value['In'] as DateTime?;
                      final reason = entry.value['reason'] ?? 'N/A';

                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(date),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                if (out != null) const Icon(Icons.logout, color: Colors.red, size: 16),
                                const SizedBox(width: 5),
                                Text(out != null ? DateFormat('hh:mm a').format(out) : '—'),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                if (inn != null) const Icon(Icons.login, color: Colors.green, size: 16),
                                const SizedBox(width: 5),
                                Text(inn != null ? DateFormat('hh:mm a').format(inn) : '—'),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(reason.toString()),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _getGatepasses(String roll) async {
    try {
      final nestedSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .doc(roll)
          .collection('gatepasses')
          .orderBy('timestamp', descending: true)
          .get();

      if (nestedSnapshot.docs.isNotEmpty) {
        debugPrint('📁 Found nested gatepasses for $roll');
        return nestedSnapshot.docs;
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching nested gatepasses: $e');
    }

    try {
      final flatSnapshot = await FirebaseFirestore.instance
          .collection('gatepasses')
          .where('roll', isEqualTo: roll.trim())
          .orderBy('timestamp', descending: true)
          .get();
      debugPrint('📂 Found flat gatepasses for $roll');
      return flatSnapshot.docs;
    } catch (e) {
      debugPrint('❌ Error fetching flat gatepasses: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View History'), backgroundColor: appBlue),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('students').orderBy('rollNumber').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading students.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final students = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(3),
                },
                border: TableBorder.all(color: Colors.grey.shade300),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: appBlue.withOpacity(0.2)),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Roll No.', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...students.map((student) {
                    final data = student.data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Unknown';
                    final roll = data['rollNumber'] ?? 'Unknown';
                    final dept = data['department'] ?? 'Unknown';

                    return TableRow(
                      children: [
                        InkWell(
                          onTap: () => _showHistoryDialog(context, name, roll, dept),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(name),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showHistoryDialog(context, name, roll, dept),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(roll),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showHistoryDialog(context, name, roll, dept),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(dept),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
