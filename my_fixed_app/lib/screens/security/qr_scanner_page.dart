// qr_scanner_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  String scannedData = 'Scan a QR code to get data';
  bool isScanning = true;
  bool isLoading = false;
  Map<String, dynamic>? _scannedStudent;

  Future<void> _showInvalidPassDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid Gatepass'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScan();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _processBarcode(String data) async {
    if (!isScanning || isLoading) return;

    setState(() {
      isLoading = true;
      isScanning = false;
    });

    try {
      final Map<String, dynamic> parsedJson = jsonDecode(data);
      final roll = parsedJson['roll'] ?? parsedJson['rollNumber'];
      final departureStr = parsedJson['departureTime'];
      final returnStr = parsedJson['returnTime'];
      final passId = parsedJson['passId'];

      if (roll == null || departureStr == null || returnStr == null || passId == null) {
        throw const FormatException("Missing required fields in QR code data.");
      }

      final departureTime = DateTime.parse(departureStr).toLocal();
      final returnTime = DateTime.parse(returnStr).toLocal();
      final now = DateTime.now();

      if (now.isBefore(departureTime)) {
        await _showInvalidPassDialog(
          "⏳ Gatepass not yet valid.\nValid from: ${DateFormat('dd-MM-yyyy hh:mm a').format(departureTime)}",
        );
        _resetScan();
        return;
      }

      if (now.isAfter(returnTime)) {
        await _showInvalidPassDialog(
          "⛔ Gatepass has expired.\nValid until: ${DateFormat('dd-MM-yyyy hh:mm a').format(returnTime)}",
        );
        _resetScan();
        return;
      }

      // Check if pass exists in gatepass_requests
      final requestDocSnapshot =
          await FirebaseFirestore.instance.collection('gatepass_requests').doc(passId).get();

      if (!requestDocSnapshot.exists) {
        await _showInvalidPassDialog("❌ Gatepass not found in system.");
        _resetScan();
        return;
      }

      if (mounted) {
        setState(() {
          _scannedStudent = parsedJson;
          scannedData = 'Gatepass for ${parsedJson['studentName'] ?? parsedJson['name']} is valid.';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _resetScan();
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStatus(String action) async {
    if (_scannedStudent == null || isLoading) return;

    setState(() => isLoading = true);

    try {
      final roll = _scannedStudent!['roll'] ?? _scannedStudent!['rollNumber'];
      final passId = _scannedStudent!['passId'];
      final gatepassesCollection = FirebaseFirestore.instance.collection('gatepasses');

      if (roll == null) {
        throw Exception("Roll number missing in scanned data.");
      }

      final now = FieldValue.serverTimestamp(); // Use current server time here

      if (action.toLowerCase() == 'out') {
        // Check if already out without in
        final query = await gatepassesCollection
            .where('rollNumber', isEqualTo: roll)
            .where('status', isEqualTo: 'Out')
            .where('inTime', isNull: true)
            .get();

        if (query.docs.isNotEmpty) {
          await _showInvalidPassDialog("⚠️ Student is already marked OUT and has not returned yet.");
          _resetScan();
          return;
        }

        // Add new "Out" record with current time as outTime
        await gatepassesCollection.add({
          ..._scannedStudent!,
          'status': 'Out',
          'outTime': now,
          'inTime': null,
          'passRequestId': passId,
          'createdAt': now,
          'reason': _scannedStudent!['reason'] ?? '',
        });
      } else if (action.toLowerCase() == 'in') {
        // Find last "Out" record with no inTime
        final query = await gatepassesCollection
            .where('rollNumber', isEqualTo: roll)
            .where('status', isEqualTo: 'Out')
            .where('inTime', isNull: true)
            .orderBy('outTime', descending: true)
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          await _showInvalidPassDialog("⚠️ No OUT record found. Please scan OUT before scanning IN.");
          _resetScan();
          return;
        }

        final docRef = query.docs.first.reference;

        await docRef.update({
          'inTime': now,
          'status': 'In',
        });
      } else {
        throw Exception('Invalid action: $action');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Marked as ${action.toLowerCase()}")),
      );

      await Future.delayed(const Duration(seconds: 2));
      _resetScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving to gatepasses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _resetScan();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _resetScan() {
    setState(() {
      scannedData = 'Scan a QR code to get data';
      isScanning = true;
      _scannedStudent = null;
    });
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout')),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      context.go('/signin');
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner - Security'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
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
                  controller: MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates),
                  onDetect: (barcodeCapture) {
                    final data = barcodeCapture.barcodes.firstOrNull?.rawValue;
                    if (data != null && isScanning) {
                      _processBarcode(data);
                    }
                  },
                ),
              ),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  color: Colors.blue[50],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _scannedStudent != null
                            ? 'Gatepass for ${_scannedStudent!['studentName'] ?? _scannedStudent!['name'] ?? 'N/A'}'
                            : scannedData,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.blueGrey[900]),
                      ),
                      const SizedBox(height: 8),
                      if (_scannedStudent != null) ...[
                        Text(
                          'Roll: ${_scannedStudent!['roll'] ?? _scannedStudent!['rollNumber'] ?? 'N/A'}  Dept: ${_scannedStudent!['department'] ?? _scannedStudent!['dept'] ?? 'N/A'}',
                          style: TextStyle(color: Colors.blueGrey[700]),
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
                      ],
                      TextButton(
                        onPressed: _resetScan,
                        child: const Text('Scan Another QR'),
                      )
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
}
