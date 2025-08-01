import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'view_history_page.dart'; // Import the ViewHistoryPage here

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Three dots button (PopupMenuButton)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert, // Three dots icon
              color: Colors.blue[800], // Customize the color here
            ),
            onSelected: (String value) {
              if (value == 'View History') {
                // Navigate to the ViewHistoryPage
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ViewHistoryPage()),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'View History',
                child: Text('View History'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(height: 60),

          // Title Section
          Column(
            children: [
              Text(
                'ROCKBOYS',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '-HOSTEL-',
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 30),

              // ✅ Fixed Login Button
              ElevatedButton(
                onPressed: () => context.go('/signin'), // ✅ Use the correct route
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'LOG IN',
                  style: TextStyle(fontSize: 16, color: Colors.white, letterSpacing: 1),
                ),
              ),

              const SizedBox(height: 10),
              Text(
                'CLICK IT TO ENTER',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          // Arrow + Image Section
          Column(
            children: [
              const Icon(Icons.keyboard_arrow_up, size: 30, color: Colors.blueGrey),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Image.asset(
                  'assets/hostel_logo.png',
                  fit: BoxFit.contain,
                  height: MediaQuery.of(context).size.height * 0.4,
                ),
              ),
              const SizedBox(height: 20),
            ],
          )
        ],
      ),
    );
  }
}
