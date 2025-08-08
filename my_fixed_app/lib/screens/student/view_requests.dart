// my_gate_pass.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

class MyGatePass extends StatelessWidget {
  const MyGatePass({super.key});

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value.isNotEmpty ? value : '-')),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildQrPayload(Map<String, dynamic> data, String passId) {
    final studentName = (data['studentName'] ?? '').toString();
    final rollNumber = (data['rollNumber'] ?? data['roll'] ?? data['username'] ?? '').toString();
    final department = (data['department'] ?? data['dept'] ?? '').toString();
    final departure = (data['departureTime'] ?? '').toString();
    final ret = (data['returnTime'] ?? '').toString();
    final studentDocId = (data['studentDocId'] ?? '').toString();
    final uid = (data['uid'] ?? '').toString();

    return {
      'passId': passId, 
      'studentName': studentName,
      'rollNumber': rollNumber,
      'department': department,
      'departureTime': departure,
      'returnTime': ret,
      'studentDocId': studentDocId,
      'uid': uid,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("My Gate Pass"), backgroundColor: Colors.blue),
        body: const Center(child: Text('Not signed in')),
      );
    }

    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Gate Pass"),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gatepass_requests')
            .where('uid', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No gate pass found."));
          }

          final passDoc = snapshot.data!.docs.first;
          final data = passDoc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? 'Pending').toString();
          final statusLower = status.toLowerCase();

          final returnTimeStr = data['returnTime'] as String? ?? '2000-01-01T00:00:00.000';
          final isExpired = DateTime.now().isAfter(DateTime.parse(returnTimeStr));
          final isUsed = (statusLower == 'in' || statusLower == 'returned');

          final studentName = (data['studentName'] ?? '').toString();
          final rollNumber = (data['rollNumber'] ?? data['roll'] ?? data['username'] ?? '').toString();
          final department = (data['department'] ?? data['dept'] ?? '').toString();
          final reason = (data['reason'] ?? '').toString();
          final departure = (data['departureTime'] ?? '').toString();
          final ret = (data['returnTime'] ?? '').toString();
          final createdAt = data['createdAt'];

          final payloadMap = _buildQrPayload(data, passDoc.id);
          final qrData = jsonEncode(payloadMap);
          
          final infoCard = Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Name', studentName),
                  _infoRow('Roll No.', rollNumber),
                  _infoRow('Department', department),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Reason', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(reason),
                  ],
                  if (departure.isNotEmpty || ret.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoRow('Departure', departure),
                    _infoRow('Return', ret),
                  ],
                  if (createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Requested: ${createdAt is Timestamp ? DateFormat('dd-MM-yyyy hh:mm a').format(createdAt.toDate()) : createdAt.toString()}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          );

          return SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                infoCard,
                if (statusLower == 'approved' && !isExpired)
                  _buildStatusWidget(
                    icon: Icons.check_circle,
                    color: Colors.green,
                    message: "Your Gate Pass is Approved!",
                    subMessage: "Status: Valid until ${ret.substring(0, 16).replaceAll('T', ' ')}",
                    qrData: qrData,
                    showQr: true,
                  )
                else if (statusLower == 'out' && !isExpired)
                  _buildStatusWidget(
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                    message: "You are currently Out of Campus.",
                    subMessage: "Please return before ${ret.substring(0, 16).replaceAll('T', ' ')}",
                    qrData: qrData,
                    showQr: true,
                  )
                else if (isUsed || isExpired)
                  _buildStatusWidget(
                    icon: Icons.lock,
                    color: Colors.grey,
                    message: isExpired ? "Your Gate Pass has Expired." : "Your Gate Pass has been Used.",
                    subMessage: isUsed ? "Status: ${status}" : "",
                    showQr: false,
                  )
                else if (statusLower == 'rejected')
                  _buildStatusWidget(
                    icon: Icons.cancel,
                    color: Colors.red,
                    message: "Your Gate Pass is Rejected.",
                    subMessage: reason.isNotEmpty ? 'Reason: $reason' : '',
                    showQr: false,
                  )
                else
                  _buildStatusWidget(
                    icon: Icons.hourglass_top,
                    color: Colors.orange,
                    message: "Your request is still pending.",
                    subMessage: "Status: ${status}",
                    showQr: false,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusWidget({
    required IconData icon,
    required Color color,
    required String message,
    String subMessage = '',
    String qrData = '',
    bool showQr = false,
  }) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(message, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 8),
        Icon(icon, color: color, size: 44),
        const SizedBox(height: 8),
        if (subMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(subMessage, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
          ),
        if (showQr) ...[
          const SizedBox(height: 20),
          QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 240.0,
            gapless: true,
          ),
          const SizedBox(height: 10),
          const Text(
            "Scan this QR at the gate to go out or return.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ],
    );
  }
}