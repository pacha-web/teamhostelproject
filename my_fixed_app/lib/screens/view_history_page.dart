import 'package:flutter/material.dart';

class ViewHistoryPage extends StatelessWidget {
  final List<Map<String, dynamic>> passes = [
    // Example data
    {'status': 'In', 'name': 'John Doe', 'date': '2025-04-12'},
    {'status': 'Out', 'name': 'Jane Smith', 'date': '2025-04-12'},
    // Add more data here
  ];

  ViewHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View History'),
        backgroundColor: Colors.blue, // Direct use of Colors.blue
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateSection(),
            const SizedBox(height: 20),
            _buildTypeButton('Gone Home', passes),
            const SizedBox(height: 10),
            _buildTypeButton('Other Activity', passes),
            const SizedBox(height: 20),
            _buildRequestList(passes),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return const Text(
      'Gate Pass Approval Date: 2025-04-12',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.blue, // Using Colors.blue here
      ),
    );
  }

  Widget _buildTypeButton(String label, List<Map<String, dynamic>> passes) {
    return ElevatedButton(
      onPressed: passes.isEmpty ? null : () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: passes.isEmpty ? Colors.grey : Colors.blue, // Using Colors.blue
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> passes) {
    return Expanded(
      child: ListView.builder(
        itemCount: passes.length,
        itemBuilder: (context, index) {
          final pass = passes[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(pass['name']),
              subtitle: Text('Status: ${pass['status']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatusButton('In', pass['status']),
                  const SizedBox(width: 8),
                  _buildStatusButton('Out', pass['status']),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusButton(String status, String currentStatus) {
    Color buttonColor;
    String buttonText;

    // Determine the color based on the current status
    if (status == 'In') {
      // If the current status is 'In', make the 'In' button green, and 'Out' button red
      buttonColor = currentStatus == 'In' ? Colors.green : Colors.red;
      buttonText = 'In';
    } else {
      // If the current status is 'Out', make the 'Out' button green, and 'In' button red
      buttonColor = currentStatus == 'Out' ? Colors.green : Colors.red;
      buttonText = 'Out';
    }

    return ElevatedButton(
      onPressed: () {
        // Here, you can add your backend call or logic to update the status
        // For now, just change the color of the buttons.
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        buttonText,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
