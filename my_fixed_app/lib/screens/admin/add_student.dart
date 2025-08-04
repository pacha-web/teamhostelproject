import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  File? _profileImage;
  final picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _departmentController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _genderController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rollNumberController = TextEditingController();

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final compressedFile = await _compressImage(File(pickedFile.path));
      setState(() {
        _profileImage = compressedFile;
      });
    }
  }

  
Future<File> _compressImage(File file) async {
  if (kIsWeb) {
    // flutter_image_compress does not support web, skip compression
    return file;
  }

  final XFile? result = await FlutterImageCompress.compressAndGetFile(
    file.path,
    file.path.replaceAll(RegExp(r'\.jpg$'), '_compressed.jpg'),
    quality: 80,
  );

  if (result == null) throw Exception('Image compression failed');
  return File(result.path);
}

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      Map<String, dynamic> imageMap = {};

      // Upload image to Firebase Storage
      if (_profileImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('student_profiles')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(_profileImage!);
        final imageUrl = await storageRef.getDownloadURL();
        imageMap = {
          'url': imageUrl,
        };
      }

      // Upload student data to Firestore
      await FirebaseFirestore.instance.collection('students').add({
        'name': _nameController.text,
        'dob': _dobController.text,
        'department': _departmentController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'gender': _genderController.text,
        'guardianName': _guardianNameController.text,
        'uardianPhNo': _guardianPhoneController.text,
        'username': _usernameController.text,
        'password': _passwordController.text,
        'rollNumber': _rollNumberController.text,
        'profileImageUrl': imageMap,
        'createdAt': DateTime.now().toIso8601String(), // string, not timestamp
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student successfully added!')),
      );
      _clearForm();
    } catch (e) {
      print("Firestore error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
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
      _profileImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Student")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : null,
                  child: _profileImage == null
                      ? const Icon(Icons.camera_alt, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(_nameController, "Name"),
              _buildTextField(_dobController, "Date of Birth (YYYY-MM-DD)"),
              _buildTextField(_rollNumberController, "Roll Number"),
              _buildTextField(_departmentController, "Department"),
              _buildTextField(_addressController, "Address"),
              _buildTextField(_phoneController, "Phone Number", keyboardType: TextInputType.phone),
              _buildTextField(_genderController, "Gender"),
              _buildTextField(_guardianNameController, "Guardian's Name"),
              _buildTextField(_guardianPhoneController, "Guardian's Phone", keyboardType: TextInputType.phone),
              _buildTextField(_usernameController, "Username"),
              _buildTextField(_passwordController, "Password", obscureText: true),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text("Add Student"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscureText = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "$label is required.";
          }
          return null;
        },
      ),
    );
  }
}
