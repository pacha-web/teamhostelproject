import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ViewHistoryScreen extends StatelessWidget {
  const ViewHistoryScreen({super.key});
  static const Color appBlue = Colors.blue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View History'),
        backgroundColor: appBlue,
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _fetchGatepassesGroupedByDate(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading gatepasses.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No gatepass history available.'));
          }

          final groupedByDate = snapshot.data!;
          final sortedDates = groupedByDate.keys.toList()
            ..sort((a, b) => b.compareTo(a)); // latest first

          return ListView(
            padding: const EdgeInsets.all(12),
            children: sortedDates.map((date) {
              final passes = groupedByDate[date]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date: $date',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
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
                      ...passes.map((p) {
                        return TableRow(
                          children: [
                            _TableCell(p['name']),
                            _TableCell(p['roll']),
                            _TableCell(p['department']),
                            _TableCell(p['reason']),
                            _TableCell(p['inTime']),
                            _TableCell(p['outTime']),
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
      ),
    );
  }

  /// Fetch gatepasses and group them by date
  Future<Map<String, List<Map<String, dynamic>>>> _fetchGatepassesGroupedByDate() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('gatepasses')
        .orderBy('createdAt', descending: true)
        .get();

    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final name = data['studentName'] ?? data['name'] ?? 'Unknown';
      final roll = data['rollNumber'] ?? data['roll'] ?? 'Unknown';
      final dept = data['department'] ?? data['dept'] ?? 'Unknown';
      final reason = data['reason'] ?? data['purpose'] ?? data['visitReason'] ?? 'N/A';

      final inTime = _formatTime(data['inTime']);
      final outTime = _formatTime(data['outTime']); // Use outTime from Firestore

      final createdAt = _parseDateTime(data['createdAt']);
      final dateKey = createdAt != null
          ? DateFormat('yyyy-MM-dd').format(createdAt)
          : DateFormat('yyyy-MM-dd').format(DateTime.now());

      grouped.putIfAbsent(dateKey, () => []).add({
        'name': name,
        'roll': roll,
        'department': dept,
        'reason': reason,
        'inTime': inTime,
        'outTime': outTime,
      });
    }

    return grouped;
  }

  /// Parse any date format from Firestore
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is String) {
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Format time from Timestamp or String
  String _formatTime(dynamic value) {
    final dt = _parseDateTime(value);
    return dt != null ? DateFormat('hh:mm a').format(dt) : '—';
  }
}

// Table header cell widget
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

// Table data cell widget
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
