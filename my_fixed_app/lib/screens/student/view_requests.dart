import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyGatePass extends StatelessWidget {
  const MyGatePass({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No gate pass found."));
          }

          var pass = snapshot.data!.docs.first;
          var status = pass['status'];

          if (status == "Approved") {
            // You can encode the passId or all details
            String qrData = pass.id; // OR jsonEncode(pass.data())

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Your Gate Pass is Approved!",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                  const SizedBox(height: 10),
                  Text("Scan this QR at the gate", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          } else if (status == "Rejected") {
            return const Center(
              child: Text("Your Gate Pass is Rejected.",
                  style: TextStyle(fontSize: 18, color: Colors.red)),
            );
          } else {
            return const Center(
              child: Text("Your request is still pending.",
                  style: TextStyle(fontSize: 18, color: Colors.orange)),
            );
          }
        },
      ),
    );
  }
}
