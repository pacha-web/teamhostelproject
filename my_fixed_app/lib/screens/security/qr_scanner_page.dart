import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

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
      final response = await http.post(
        Uri.parse('https://your-backend-url.com/api/updateStatus'),
        body: {
          'qrData': scannedData,
          'status': status,
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked as $status')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Scanner - Security')),
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
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
