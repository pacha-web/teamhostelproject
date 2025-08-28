// universal_signin.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UniversalSignIn extends StatefulWidget {
  const UniversalSignIn({super.key});

  @override
  State<UniversalSignIn> createState() => _UniversalSignInState();
}

class _UniversalSignInState extends State<UniversalSignIn> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(); // used as roll number for students
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedRole = 'Student';
  String _errorMessage = '';
  int _failedAttempts = 0;
  DateTime? _blockTime;
  Timer? _timer;

  bool _isLoading = false;
  bool _obscurePassword = true;

  /// MUST MATCH the domain used when creating students in AddStudentPage
  static const String _studentEmailDomain = 'students.mygate';

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  Future<void> _handleLogin(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    String input = _usernameController.text.trim();
    final password = _passwordController.text;

    if (_blockTime != null && DateTime.now().isBefore(_blockTime!)) {
      final remaining = _blockTime!.difference(DateTime.now()).inSeconds;
      _setError('Blocked. Try again in ${remaining}s');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String authEmailToUse;

      if (_selectedRole.toLowerCase() == 'student') {
        // For students, username is roll number. Build the synthetic email.
        if (input.isEmpty) {
          _handleFailure('Enter roll number');
          return;
        }
        authEmailToUse = '${input.toLowerCase()}@$_studentEmailDomain';
      } else {
        // For Admin / Security assume they supply a real email as username
        authEmailToUse = input;
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: authEmailToUse,
        password: password,
      );

      final user = userCredential.user;

      if (user == null) {
        _handleFailure('Authentication failed');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || !doc.data()!.containsKey('role')) {
        _handleFailure('User role not found');
        return;
      }

      final role = (doc.data()!['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase(); // Firestore role
      final selectedRole = _selectedRole.trim().toLowerCase(); // Dropdown role

      // ✅ strict match: Firestore role must match dropdown exactly
      if (role != selectedRole) {
        _handleFailure('Incorrect role selected for this account');
        return;
      }

      // ✅ role-based navigation
      switch (role) {
        case 'admin':
          context.go('/admin');
          break;
        case 'security':
          context.go('/qr-scanner');
          break;
        case 'student':
          // Find student document. Prefer lookup by uid, fallback to username (rollNumber)
          DocumentSnapshot<Map<String, dynamic>>? studentDoc;

          final studentByUidQuery = await FirebaseFirestore.instance
              .collection('students')
              .where('uid', isEqualTo: user.uid)
              .limit(1)
              .get();

          if (studentByUidQuery.docs.isNotEmpty) {
            studentDoc = studentByUidQuery.docs.first;
          } else {
            // Lookup by roll number (username) using the roll number provided in the login field
            final byUsername = await FirebaseFirestore.instance
                .collection('students')
                .where('username', isEqualTo: _usernameController.text.trim())
                .limit(1)
                .get();

            if (byUsername.docs.isNotEmpty) {
              studentDoc = byUsername.docs.first;
            } else {
              // As last fallback, try matching authEmail (if you stored it)
              final authEmail =
                  '${_usernameController.text.trim().toLowerCase()}@$_studentEmailDomain';
              final byAuthEmail = await FirebaseFirestore.instance
                  .collection('students')
                  .where('authEmail', isEqualTo: authEmail)
                  .limit(1)
                  .get();
              if (byAuthEmail.docs.isNotEmpty) {
                studentDoc = byAuthEmail.docs.first;
              }
            }
          }

          if (studentDoc == null) {
            _handleFailure('Student record not found. Contact admin.');
            return;
          }

          final sdata = studentDoc.data()!;
          final studentName = (sdata['name'] ?? '').toString();
          final profileImageUrl = (sdata['profileImageUrl'] ?? '').toString();

          context.go('/student-home', extra: {
            'studentName': studentName,
            'profileImageUrl': profileImageUrl,
            'studentDocId': studentDoc.id,
            'uid': user.uid,
          });
          break;
        default:
          _handleFailure('Unrecognized role');
      }
    } on FirebaseAuthException catch (e) {
      _handleFailure(_getErrorMessage(e.code));
    } catch (e) {
      _setError('Unexpected error: $e');
    }

    setState(() => _isLoading = false);
  }

  void _handleFailure(String message) {
    setState(() {
      _failedAttempts++;
      _errorMessage = message;
      if (_failedAttempts >= 5) {
        _blockTime = DateTime.now().add(const Duration(minutes: 5));
        _startTimer();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'Account disabled';
      case 'user-not-found':
        return 'No account found';
      case 'wrong-password':
        return 'Wrong password';
      default:
        return 'Login failed: $code';
    }
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

    final isStudent = _selectedRole.toLowerCase() == 'student';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Universal Sign-In',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Go to Home',
            onPressed: () {
              context.go('/');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                keyboardType: isStudent
                    ? TextInputType.text
                    : TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: isStudent ? 'Roll Number' : 'Email',
                  border: const OutlineInputBorder(),
                  hintText: isStudent ? 'Enter roll number' : 'Enter email',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return isStudent ? 'Enter roll number' : 'Enter email';
                  }
                  if (!isStudent && !value.contains('@')) {
                    return 'Enter valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter password' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _handleLogin(context),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Login'),
              ),
              if (_blockTime != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Blocked for ${remainingTime}s',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
