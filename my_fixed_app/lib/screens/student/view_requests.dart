// my_gatepass.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart'; // Clipboard

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

  /// Build JSON payload that will be encoded into the QR code.
  Map<String, dynamic> _buildQrPayload(Map<String, dynamic> data, String passId, String status) {
    final studentName = (data['studentName'] ?? '').toString();
    final rollNumber = (data['rollNumber'] ?? data['roll'] ?? data['username'] ?? '').toString();
    final department = (data['department'] ?? data['dept'] ?? '').toString();
    final reason = (data['reason'] ?? '').toString();
    final departure = (data['departureTime'] ?? '').toString();
    final ret = (data['returnTime'] ?? '').toString();
    final createdAtRaw = data['createdAt'];

    String createdAtIso = '';
    if (createdAtRaw != null) {
      if (createdAtRaw is Timestamp) {
        createdAtIso = (createdAtRaw as Timestamp).toDate().toUtc().toIso8601String();
      } else {
        createdAtIso = createdAtRaw.toString();
      }
    }

    return {
      'passId': passId,
      'studentName': studentName,
      'rollNumber': rollNumber,
      'department': department,
      'reason': reason,
      'departureTime': departure,
      'returnTime': ret,
      'status': status,
      'createdAt': createdAtIso,
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

          // Safely extract fields with fallbacks
          final status = (data['status'] ?? 'Pending').toString();
          final studentName = (data['studentName'] ?? '').toString();
          final rollNumber = (data['rollNumber'] ?? data['roll'] ?? data['username'] ?? '').toString();
          final department = (data['department'] ?? data['dept'] ?? '').toString();
          final reason = (data['reason'] ?? '').toString();
          final departure = (data['departureTime'] ?? '').toString();
          final ret = (data['returnTime'] ?? '').toString();
          final createdAt = data['createdAt'];

          // Build JSON payload and encode to string for QR
          final payloadMap = _buildQrPayload(data, passDoc.id, status);
          final qrData = jsonEncode(payloadMap);

          // Info card
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
                        'Requested: ${createdAt is Timestamp ? (createdAt as Timestamp).toDate().toString() : createdAt.toString()}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          );

          // Common action buttons (copy JSON)
          final actionsRow = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [

                const SizedBox(width: 12),
                // Optional: share button (requires share_plus). See comment below.
                /*Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share QR'),
                    onPressed: () { 
                      // If you want to share the QR image, generate image bytes via QrPainter
                      // and use the share_plus package to share the image file.
                      // See commented example at the end of this file.
                    },
                  ),
                ),*/
              ],
            ),
          );

          // Show different UI depending on status
          final statusLower = status.toLowerCase();
          if (statusLower == 'approved') {
            return SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  infoCard,
                  const SizedBox(height: 8),
                  const Text("Your Gate Pass is Approved!",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  // QR encoding full JSON payload
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 240.0,
                    gapless: true,
                  ),
                  
                ],
              ),
            );
          } else if (statusLower == 'rejected') {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                infoCard,
                const SizedBox(height: 8),
                const Icon(Icons.cancel, color: Colors.red, size: 44),
                const SizedBox(height: 8),
                const Text("Your Gate Pass is Rejected.",
                    style: TextStyle(fontSize: 18, color: Colors.red)),
                const SizedBox(height: 8),
                if (reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Reason: $reason', textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 16),
                actionsRow,
              ],
            );
          } else {
            // Pending or other statuses
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                infoCard,
                const SizedBox(height: 8),
                const Icon(Icons.hourglass_top, color: Colors.orange, size: 44),
                const SizedBox(height: 8),
                const Text("Your request is still pending.",
                    style: TextStyle(fontSize: 18, color: Colors.orange)),
                const SizedBox(height: 8),
                Text("Status: ${status.isNotEmpty ? status : 'Pending'}", style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 16),
                actionsRow,
              ],
            );
          }
        },
      ),
    );
  }
}
