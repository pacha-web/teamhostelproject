import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewHistoryPage extends StatelessWidget {
  const ViewHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('View History'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gatepasses')
            .where('uid', isEqualTo: currentUser?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error loading data'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text('No history available'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unknown';
              final status = data['status'] ?? 'Unknown';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final formattedTime = timestamp != null
                  ? DateFormat('yyyy-MM-dd – hh:mm a').format(timestamp)
                  : 'Time not available';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(name),
                  subtitle: Text('Status: $status\nTime: $formattedTime'),
                  trailing: Icon(
                    status == 'In' ? Icons.login : Icons.logout,
                    color: status == 'In' ? Colors.green : Colors.red,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
