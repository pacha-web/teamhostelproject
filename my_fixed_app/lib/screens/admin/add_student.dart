// lib/main.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Replace with your Firebase Web config
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'YOUR_API_KEY',
        authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
        projectId: 'YOUR_PROJECT_ID',
        storageBucket: 'YOUR_PROJECT_ID.appspot.com',
        messagingSenderId: 'YOUR_SENDER_ID',
        appId: 'YOUR_APP_ID',
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Add Student (Create Auth + Firestore)',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const AddStudentPage(),
    );
  }
}

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  // Image state
  File? _profileImageFile; // mobile-only
  Uint8List? _profileImageBytes; // web-only
  XFile? _pickedXFile;

  final ImagePicker _picker = ImagePicker();

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _departmentController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _genderController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _usernameController = TextEditingController(); // used as email
  final _passwordController = TextEditingController();
  final _rollNumberController = TextEditingController();

  bool _isLoading = false;

  // --- Image picking & compression ---
  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _profileImageBytes = bytes;
          _profileImageFile = null;
          _pickedXFile = picked;
        });
      } else {
        final file = File(picked.path);
        final compressed = await _compressImage(file);
        setState(() {
          _profileImageFile = compressed;
          _profileImageBytes = null;
          _pickedXFile = picked;
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image pick error: $e')),
        );
      }
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      final outPath = file.path.replaceAll(RegExp(r'\.[^\.]+$'), '_comp.jpg');
      final dynamic result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        outPath,
        quality: 80,
      );
      if (result == null) return file;
      if (result is File) return result;
      if (result is XFile) return File(result.path);
      return file;
    } catch (e) {
      debugPrint('Compression error: $e');
      return file;
    }
  }

  // --- Upload image to Firebase Storage (returns download URL or null) ---
  Future<String?> _uploadImage({File? file, Uint8List? bytes}) async {
    if (file == null && bytes == null) return null;

    final ref = FirebaseStorage.instance
        .ref()
        .child('student_profiles')
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

    try {
      if (kIsWeb) {
        final metadata = SettableMetadata(contentType: 'image/jpeg');
        final uploadTask = ref.putData(bytes!, metadata);
        final snapshot = await uploadTask.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            uploadTask.cancel();
            throw TimeoutException('Image upload timed out');
          },
        );
        if (snapshot.state == TaskState.success) {
          return await ref.getDownloadURL();
        } else {
          throw FirebaseException(
              plugin: 'firebase_storage',
              message: 'Upload failed: ${snapshot.state}');
        }
      } else {
        final metadata = SettableMetadata(contentType: 'image/jpeg');
        final uploadTask = ref.putFile(file!, metadata);
        final snapshot = await uploadTask.timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            uploadTask.cancel();
            throw TimeoutException('Image upload timed out');
          },
        );
        if (snapshot.state == TaskState.success) {
          return await ref.getDownloadURL();
        } else {
          throw FirebaseException(
              plugin: 'firebase_storage',
              message: 'Upload failed: ${snapshot.state}');
        }
      }
    } on TimeoutException {
      rethrow;
    } on FirebaseException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // --- Main submit: create auth user, upload image, save student doc with uid ---
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final dob = _dobController.text.trim();
    final department = _departmentController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final gender = _genderController.text.trim();
    final guardianName = _guardianNameController.text.trim();
    final guardianPhone = _guardianPhoneController.text.trim();
    final email = _usernameController.text.trim();
    final password = _passwordController.text;
    final rollNumber = _rollNumberController.text.trim();

    setState(() => _isLoading = true);

    UserCredential? createdUserCred;
    String? imageUrl;

    try {
      // 1) Create Firebase Auth user using provided email & password
      createdUserCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = createdUserCred.user?.uid;
      if (uid == null) {
        throw Exception('Failed to create user');
      }

      // 2) Upload image (if any)
      try {
        imageUrl = await _uploadImage(file: _profileImageFile, bytes: _profileImageBytes);
      } catch (e) {
        // If image upload fails, we still want to avoid leaving orphan auth user without data.
        // We'll delete the created auth user and rethrow to let admin retry.
        debugPrint('Image upload failed after creating user: $e');
        // Attempt cleanup
        try {
          await createdUserCred.user!.delete();
        } catch (deleteErr) {
          debugPrint('Failed to delete auth user after upload failure: $deleteErr');
        }
        rethrow;
      }

      // 3) Prepare Firestore data (store uid as doc id)
      final data = <String, dynamic>{
        'uid': uid,
        'name': name,
        'dob': dob,
        'department': department,
        'address': address,
        'phone': phone,
        'gender': gender,
        'guardianName': guardianName,
        'guardianPhNo': guardianPhone,
        'username': email, // keep for reference
        'rollNumber': rollNumber,
        'profileImageUrl': imageUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 4) Save to Firestore under doc id = uid (so we can query by uid quickly)
      final studentsCol = FirebaseFirestore.instance.collection('students');
      await studentsCol.doc(uid).set(data);

      // Optional: you may also create a 'users' doc to store role etc.
      final usersCol = FirebaseFirestore.instance.collection('users');
      await usersCol.doc(uid).set({
        'role': 'student',
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student account created successfully')),
        );
        _clearForm();
      }
    } on FirebaseAuthException catch (e) {
      // Common auth errors
      String message = 'Auth error: ${e.code}';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already in use.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } on TimeoutException catch (e) {
      // handle upload timeout or other timeouts
      if (createdUserCred != null) {
        try {
          await createdUserCred.user!.delete();
          debugPrint('Deleted auth user after timeout');
        } catch (delErr) {
          debugPrint('Failed to delete user after timeout: $delErr');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Timeout: ${e.message}')));
      }
    } catch (e, st) {
      debugPrint('Unexpected error creating student: $e\n$st');
      // If we created auth user but failed before finalizing Firestore, attempt cleanup
      if (createdUserCred != null) {
        try {
          await createdUserCred.user!.delete();
        } catch (delErr) {
          debugPrint('Failed to delete user during cleanup: $delErr');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _dobController.clear();
    _departmentController.clear();
    _addressController.clear();
    _phoneController.clear();
    _genderController.clear();
    _guardianNameController.clear();
    _guardianPhoneController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _rollNumberController.clear();
    setState(() {
      _profileImageFile = null;
      _profileImageBytes = null;
      _pickedXFile = null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _departmentController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _genderController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rollNumberController.dispose();
    super.dispose();
  }

  // UI helpers
  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscureText = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return "$label is required.";
          return null;
        },
      ),
    );
  }

  Widget _imagePreview(double radius) {
    if (kIsWeb) {
      if (_profileImageBytes != null) {
        return CircleAvatar(radius: radius, backgroundImage: MemoryImage(_profileImageBytes!));
      }
    } else {
      if (_profileImageFile != null) {
        return CircleAvatar(radius: radius, backgroundImage: FileImage(_profileImageFile!));
      }
    }
    return CircleAvatar(radius: radius, backgroundColor: Colors.grey[200], child: const Icon(Icons.camera_alt));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student (Create Account)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            GestureDetector(onTap: _pickImage, child: _imagePreview(50)),
            const SizedBox(height: 16),
            _buildTextField(_nameController, 'Name'),
            _buildTextField(_dobController, 'Date of Birth (YYYY-MM-DD)', keyboardType: TextInputType.datetime),
            _buildTextField(_rollNumberController, 'Roll Number'),
            _buildTextField(_departmentController, 'Department'),
            _buildTextField(_addressController, 'Address'),
            _buildTextField(_phoneController, 'Phone Number', keyboardType: TextInputType.phone),
            _buildTextField(_genderController, 'Gender'),
            _buildTextField(_guardianNameController, "Guardian's Name"),
            _buildTextField(_guardianPhoneController, "Guardian's Phone", keyboardType: TextInputType.phone),
            // username is used as email for auth
            _buildTextField(_usernameController, 'Email (used as username)', keyboardType: TextInputType.emailAddress),
            _buildTextField(_passwordController, 'Password', obscureText: true),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Text('Create Student Account')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
