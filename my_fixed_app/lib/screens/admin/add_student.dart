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
import 'package:intl/intl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
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
      theme: ThemeData(primarySwatch: Colors.blue),
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
  File? _profileImageFile;
  Uint8List? _profileImageBytes;
  XFile? _pickedXFile;

  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _departmentController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedGender;
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rollNumberController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  static const String _studentEmailDomain = 'students.mygate';

  // Pick Image
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

  // Upload Image
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
        }
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  // Submit Form
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final dob = _dobController.text.trim();
    final department = _departmentController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final gender = _selectedGender ?? '';
    final guardianName = _guardianNameController.text.trim();
    final guardianPhone = _guardianPhoneController.text.trim();
    final password = _passwordController.text;
    final rollNumber = _rollNumberController.text.trim();

    setState(() => _isLoading = true);

    UserCredential? createdUserCred;
    String? imageUrl;

    try {
      final authEmail = '${rollNumber.toLowerCase()}@$_studentEmailDomain';
      createdUserCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: authEmail, password: password);

      final uid = createdUserCred.user?.uid;
      if (uid == null) throw Exception('Failed to create user');

      imageUrl =
          await _uploadImage(file: _profileImageFile, bytes: _profileImageBytes);

      final data = {
        'uid': uid,
        'name': name,
        'dob': dob,
        'department': department,
        'address': address,
        'phone': phone,
        'gender': gender,
        'guardianName': guardianName,
        'guardianPhNo': guardianPhone,
        'username': rollNumber,
        'authEmail': authEmail,
        'rollNumber': rollNumber,
        'profileImageUrl': imageUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('students').doc(uid).set(data);

      await FirebaseFirestore.instance.collection('users').doc(rollNumber).set({
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student account created successfully')),
        );
        _clearForm();
      }
    } catch (e) {
      if (createdUserCred != null) {
        await createdUserCred.user?.delete();
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
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
    _selectedGender = null;
    _guardianNameController.clear();
    _guardianPhoneController.clear();
    _passwordController.clear();
    _rollNumberController.clear();
    setState(() {
      _profileImageFile = null;
      _profileImageBytes = null;
      _pickedXFile = null;
    });
  }

  // Build Input Field
  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscureText = false,
      TextInputType? keyboardType,
      String? Function(String?)? validator,
      Widget? suffixIcon,
      bool readOnly = false,
      VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: suffixIcon,
        ),
        validator: validator ??
            (value) {
              if (value == null || value.trim().isEmpty) {
                return "$label is required.";
              }
              return null;
            },
      ),
    );
  }

  // Image Preview
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

            // DOB Date Picker
            _buildTextField(
              _dobController,
              'Date of Birth',
              readOnly: true,
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(2000),
                  firstDate: DateTime(1970),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
                }
              },
            ),

            _buildTextField(_rollNumberController, 'Roll Number'),
            _buildTextField(_departmentController, 'Department'),
            _buildTextField(_addressController, 'Address'),

            // Phone validation
            _buildTextField(
              _phoneController,
              'Phone Number',
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return "Phone number is required.";
                if (!RegExp(r'^\d{10}$').hasMatch(value)) return "Enter a valid 10-digit phone number.";
                return null;
              },
            ),

            // Gender Dropdown
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: DropdownButtonFormField<String>(
                value: _selectedGender,
                items: ['Male', 'Female', 'Other']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedGender = val),
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? 'Please select a gender' : null,
              ),
            ),

            _buildTextField(_guardianNameController, "Guardian's Name"),
            _buildTextField(
              _guardianPhoneController,
              "Guardian's Phone",
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) return "Guardian's phone is required.";
                if (!RegExp(r'^\d{10}$').hasMatch(value)) return "Enter a valid 10-digit phone number.";
                return null;
              },
            ),

            // Password with Eye Icon
            _buildTextField(
              _passwordController,
              'Password',
              obscureText: !_isPasswordVisible,
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() => _isPasswordVisible = !_isPasswordVisible);
                },
              ),
            ),

            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text('Create Student Account'),
                      ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
