import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

class UniversalSignIn extends StatefulWidget {
  const UniversalSignIn({super.key});

  @override
  _UniversalSigninState createState() => _UniversalSigninState();
}


class _UniversalSigninState extends State<UniversalSignIn> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'Student';
  String _errorMessage = '';
  int _failedAttempts = 0;
  DateTime? _blockTime;
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_blockTime != null && DateTime.now().isAfter(_blockTime!)) {
        setState(() {
          _errorMessage = '';
          _failedAttempts = 0;
          _blockTime = null;
        });
        timer.cancel();
      } else {
        setState(() {});
      }
    });
  }

  void _handleLogin(BuildContext context) async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (_selectedRole == 'Admin') {
      if (username == 'admin' && password == 'admin123') {
        context.go('/admin');
      } else {
        _setError("Invalid Admin credentials");
      }
    } else if (_selectedRole == 'Security') {
      if (username == 'security' && password == 'sec123') {
        context.go('/qr-scanner');
      } else {
        _setError("Invalid Security credentials");
      }
    } else if (_selectedRole == 'Student') {
      if (_blockTime != null && DateTime.now().isBefore(_blockTime!)) {
        final remaining = _blockTime!.difference(DateTime.now()).inSeconds;
        setState(() {
          _errorMessage = 'Blocked. Try in ${remaining}s';
        });
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('http://192.168.13.144:5000/api/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final student = data['student'];
          if (student != null) {
           context.go(
  '/student-home',
  
  extra: {
    'studentName': student['name'],
    'profileImageUrl': 'http://192.168.13.144:5000${student['profileImage']}',
  },
);

          } else {
            _handleFailure("Invalid Student credentials");
          }
        } else {
          _handleFailure("Login failed");
        }
      } catch (e) {
        _setError("Network error");
      }
    }
  }

  void _handleFailure(String message) {
    setState(() {
      _failedAttempts++;
      _errorMessage = message;
      if (_failedAttempts >= 5) {
        _blockTime = DateTime.now().add(Duration(minutes: 5));
        _startTimer();
      }
    });
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainingTime = _blockTime != null
        ? _blockTime!.difference(DateTime.now()).inSeconds
        : 0;

    return Scaffold(
      appBar: AppBar(title: Text('Universal Sign-In')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _selectedRole,
              onChanged: (newValue) {
                setState(() {
                  _selectedRole = newValue!;
                  _errorMessage = '';
                });
              },
              items: ['Student', 'Admin', 'Security']
                  .map((role) => DropdownMenuItem(
                        value: role,
                        child: Text(role),
                      ))
                  .toList(),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _handleLogin(context),
              child: Text('Login'),
            ),
            if (_errorMessage.isNotEmpty) ...[
              SizedBox(height: 20),
              Text(_errorMessage, style: TextStyle(color: Colors.red)),
              if (_blockTime != null)
                Text('Wait ${remainingTime}s',
                    style: TextStyle(color: Colors.orange)),
            ],
          ],
        ),
      ),
    );
  }
}
