// qr_scanner_page.dart
import 'dart:convert';
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

  Map<String, dynamic>? _scannedStudent;

  Future<void> _processBarcode(String data) async {
    setState(() {
      scannedData = data;
      isScanning = false;
      isLoading = true;
      _scannedStudent = null;
    });

    Map<String, dynamic>? parsedJson;
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        parsedJson = decoded;
      } else if (decoded is Map) {
        parsedJson = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      parsedJson = null;
    }

    try {
      final studentsCol = FirebaseFirestore.instance.collection('students');

      if (parsedJson != null) {
        final candidateRoll = (parsedJson['rollNumber'] ??
                parsedJson['roll'] ??
                parsedJson['username'] ??
                parsedJson['studentRoll'] ??
                '')
            .toString()
            .trim();
        final candidateUid = (parsedJson['uid'] ?? parsedJson['studentUid'] ?? '').toString().trim();

        if (candidateRoll.isNotEmpty) {
          final byRoll = await studentsCol.where('rollNumber', isEqualTo: candidateRoll).limit(1).get();
          if (byRoll.docs.isNotEmpty) {
            final d = byRoll.docs.first;
            _scannedStudent = {...?d.data(), 'studentDocId': d.id};
          }
        }

        if (_scannedStudent == null && candidateUid.isNotEmpty) {
          final byUid = await studentsCol.where('uid', isEqualTo: candidateUid).limit(1).get();
          if (byUid.docs.isNotEmpty) {
            final d = byUid.docs.first;
            _scannedStudent = {...?d.data(), 'studentDocId': d.id};
          }
        }

        if (_scannedStudent == null && parsedJson.isNotEmpty) {
          _scannedStudent = {
            'name': parsedJson['studentName'] ?? parsedJson['name'] ?? '',
            'roll': parsedJson['rollNumber'] ?? parsedJson['roll'] ?? parsedJson['username'] ?? '',
            'department': parsedJson['department'] ?? parsedJson['dept'] ?? '',
            'extraFromQr': parsedJson,
          };
        }
      } else {
        final docSnap = await studentsCol.doc(data).get();
        if (docSnap.exists) {
          _scannedStudent = {...?docSnap.data(), 'studentDocId': docSnap.id};
        } else {
          var q = await studentsCol.where('uid', isEqualTo: data).limit(1).get();
          if (q.docs.isNotEmpty) {
            final d = q.docs.first;
            _scannedStudent = {...?d.data(), 'studentDocId': d.id};
          } else {
            q = await studentsCol.where('rollNumber', isEqualTo: data).limit(1).get();
            if (q.docs.isNotEmpty) {
              final d = q.docs.first;
              _scannedStudent = {...?d.data(), 'studentDocId': d.id};
            } else {
              q = await studentsCol.where('roll', isEqualTo: data).limit(1).get();
              if (q.docs.isNotEmpty) {
                final d = q.docs.first;
                _scannedStudent = {...?d.data(), 'studentDocId': d.id};
              } else {
                q = await studentsCol.where('email', isEqualTo: data).limit(1).get();
                if (q.docs.isNotEmpty) {
                  final d = q.docs.first;
                  _scannedStudent = {...?d.data(), 'studentDocId': d.id};
                }
              }
            }
          }
        }
      }

      if (!mounted) return;

      if (parsedJson != null) {
        await _showJsonDialog(parsedJson, data);
      } else {
        if (_scannedStudent != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Student found: ${_scannedStudent!['name'] ?? 'Unknown'}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student record not found — saving raw scanned data.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lookup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _showJsonDialog(Map<String, dynamic> jsonMap, String rawData) async {
    final name = (jsonMap['studentName'] ?? jsonMap['name'] ?? '').toString();
    final roll = (jsonMap['rollNumber'] ?? jsonMap['roll'] ?? jsonMap['username'] ?? '').toString();
    final department = (jsonMap['department'] ?? jsonMap['dept'] ?? '').toString();
    final reason = (jsonMap['reason'] ?? '').toString();
    final departure = (jsonMap['departureTime'] ?? '').toString();
    final ret = (jsonMap['returnTime'] ?? '').toString();
    final status = (jsonMap['status'] ?? '').toString();
    final passId = (jsonMap['passId'] ?? '').toString();
    final createdAt = (jsonMap['createdAt'] ?? '').toString();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Gatepass QR Data'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _labelValueRow('Name', name),
                _labelValueRow('Roll No.', roll),
                _labelValueRow('Department', department),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Reason', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(reason),
                ],
                if (departure.isNotEmpty) _labelValueRow('Departure', departure),
                if (ret.isNotEmpty) _labelValueRow('Return', ret),
                if (status.isNotEmpty) _labelValueRow('Status', status),
                if (passId.isNotEmpty) _labelValueRow('Pass ID', passId),
                if (createdAt.isNotEmpty) _labelValueRow('Created At', createdAt),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _labelValueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value.isNotEmpty ? value : '-')),
        ],
      ),
    );
  }

  Future<void> _handleStatus(String status) async {
    if (scannedData == 'Scan a QR code to get data') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan a QR code first')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final securityUser = FirebaseAuth.instance.currentUser;

      final Map<String, dynamic> docData = {
        'scannedData': scannedData,
        'status': status,
        'timestamp': FieldValue.serverTimestamp(),
        'scannedBy': securityUser?.uid ?? 'unknown',
      };

      if (_scannedStudent != null) {
        docData['studentName'] = (_scannedStudent!['name'] ?? '').toString();
        docData['roll'] = (_scannedStudent!['roll'] ?? _scannedStudent!['rollNumber'] ?? '').toString();
        docData['department'] = (_scannedStudent!['department'] ?? _scannedStudent!['dept'] ?? '').toString();
        docData['studentDocId'] = (_scannedStudent!['studentDocId'] ?? '').toString();
        if (_scannedStudent!.containsKey('uid')) {
          docData['uid'] = (_scannedStudent!['uid'] ?? '').toString();
        }
      } else {
        docData['studentName'] = scannedData;
        docData['roll'] = '';
        docData['department'] = '';
        docData['studentDocId'] = '';
        docData['uid'] = securityUser?.uid ?? 'unknown';
      }

      final globalRef = await FirebaseFirestore.instance.collection('gatepasses').add(docData);

      if (_scannedStudent != null && _scannedStudent!['studentDocId'] != null) {
        final studentDocId = _scannedStudent!['studentDocId'];
        final nestedRef = FirebaseFirestore.instance
            .collection('students')
            .doc(studentDocId)
            .collection('gatepasses')
            .doc(globalRef.id);
        await nestedRef.set(docData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as $status')),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            scannedData = 'Scan a QR code to get data';
            isScanning = true;
            _scannedStudent = null;
          });
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
                  onDetect: (BarcodeCapture capture) {
                    final data = capture.barcodes.firstOrNull?.rawValue;
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
                            ? (_scannedStudent!['name'] ?? scannedData).toString()
                            : scannedData,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.blueGrey[900]),
                      ),
                      const SizedBox(height: 8),
                      if (_scannedStudent != null)
                        Text(
                          'Roll: ${_scannedStudent!['roll'] ?? _scannedStudent!['rollNumber'] ?? 'N/A'}   Dept: ${_scannedStudent!['department'] ?? _scannedStudent!['dept'] ?? 'N/A'}',
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
