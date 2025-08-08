
// view_history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

enum HistoryType { current, old }

class ViewHistoryScreen extends StatelessWidget {
  const ViewHistoryScreen({super.key});
  static const Color appBlue = Colors.blue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View History'), backgroundColor: appBlue),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('students').get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading students.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final students = snapshot.data!.docs;

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchAllGatepasses(students),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No gatepass history available.'));
              }

              final groupedByDate = _groupByDate(snapshot.data!);

              return ListView(
                padding: const EdgeInsets.all(12),
                children: groupedByDate.entries.map((entry) {
                  final date = entry.key;
                  final passes = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date: $date',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        columnWidths: const {
                          0: FlexColumnWidth(2),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(3),
                          4: FlexColumnWidth(2),
                          5: FlexColumnWidth(2),
                        },
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(color: Color(0xFFD6EAF8)),
                            children: [
                              _HeaderCell('Name'),
                              _HeaderCell('Roll No'),
                              _HeaderCell('Dept'),
                              _HeaderCell('Reason'),
                              _HeaderCell('In-Time'),
                              _HeaderCell('Out-Time'),
                            ],
                          ),
                          ...passes.map((entry) {
                            return TableRow(
                              children: [
                                _TableCell(entry['name']),
                                _TableCell(entry['roll']),
                                _TableCell(entry['department']),
                                _TableCell(entry['reason']),
                                _TableCell(entry['inTime']),
                                _TableCell(entry['outTime']),
                              ],
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  // Fetch gatepasses of all students
  Future<List<Map<String, dynamic>>> _fetchAllGatepasses(List<QueryDocumentSnapshot> students) async {
    List<Map<String, dynamic>> entries = [];

    for (final student in students) {
      final studentData = student.data() as Map<String, dynamic>;
      final studentId = student.id;

      final name = studentData['name'] ?? 'Unknown';
      final roll = studentData['rollNumber'] ?? 'Unknown';
      final dept = studentData['department'] ?? 'Unknown';

      final gatepasses = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .collection('gatepasses')
          .orderBy('timestamp', descending: true)
          .get();

      for (final pass in gatepasses.docs) {
        final passData = pass.data();
        final timestamp = (passData['timestamp'] as Timestamp?)?.toDate();
        final status = passData['status'];
        final scannedStr = passData['scannedData'] ?? '{}';
        final parsed = jsonDecode(scannedStr);

        if (timestamp == null) continue;

        final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);
        final reason = parsed['reason'] ?? 'N/A';

        final existingEntry = entries.firstWhere(
          (e) => e['roll'] == roll && e['date'] == dateKey && e['reason'] == reason,
          orElse: () => {},
        );

        if (existingEntry.isEmpty) {
          entries.add({
            'name': name,
            'roll': roll,
            'department': dept,
            'date': dateKey,
            'reason': reason,
            'inTime': status == 'In' ? DateFormat('hh:mm a').format(timestamp) : '—',
            'outTime': status == 'Out' ? DateFormat('hh:mm a').format(timestamp) : '—',
          });
        } else {
          if (status == 'In') existingEntry['inTime'] = DateFormat('hh:mm a').format(timestamp);
          if (status == 'Out') existingEntry['outTime'] = DateFormat('hh:mm a').format(timestamp);
        }
      }
    }

    return entries;
  }

  // Group entries by date
  Map<String, List<Map<String, dynamic>>> _groupByDate(List<Map<String, dynamic>> entries) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final entry in entries) {
      final date = entry['date'];
      grouped.putIfAbsent(date, () => []).add(entry);
    }
    return grouped;
  }
}

// Helper Widgets
class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text),
    );
  }
}
