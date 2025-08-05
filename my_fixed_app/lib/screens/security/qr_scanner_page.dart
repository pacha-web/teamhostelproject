import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  String scannedData = 'Scan a QR code to get data';
  bool isScanning = true;
  bool isLoading = false;

  Future<void> _handleStatus(String status) async {
    if (scannedData == 'Scan a QR code to get data') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan a QR code first')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('gatepasses').add({
        'name': scannedData, // You can replace with actual student name if available
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'uid': user?.uid ?? 'unknown',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as $status')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _resetScan() {
    setState(() {
      scannedData = 'Scan a QR code to get data';
      isScanning = true;
    });
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      context.go('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner - Security'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 4,
                child: MobileScanner(
                  controller: MobileScannerController(
                    detectionSpeed: DetectionSpeed.noDuplicates,
                  ),
                  onDetect: (BarcodeCapture capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final data = barcodes.first.rawValue;
                      if (data != null && isScanning) {
                        setState(() {
                          scannedData = data;
                          isScanning = false;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Scanned: $data')),
                        );
                      }
                    }
                  },
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        scannedData,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statusButton('In', Colors.green),
                          _statusButton('Out', Colors.red),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _resetScan,
                        child: const Text('Scan Another QR'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _statusButton(String label, Color color) {
    return ElevatedButton(
      onPressed: () => _handleStatus(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 18, color: Colors.white)),
    );
  }
}
