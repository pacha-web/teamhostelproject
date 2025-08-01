import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:cross_file/cross_file.dart';

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

    var uri = Uri.parse("http://192.168.13.144:5000/api/add-student");
    var request = http.MultipartRequest('POST', uri);

    request.fields['name'] = _nameController.text;
    request.fields['dob'] = _dobController.text;
    request.fields['department'] = _departmentController.text;
    request.fields['address'] = _addressController.text;
    request.fields['phone'] = _phoneController.text;
    request.fields['gender'] = _genderController.text;
    request.fields['guardianName'] = _guardianNameController.text;
    request.fields['guardianPhNo'] = _guardianPhoneController.text;
    request.fields['username'] = _usernameController.text;
    request.fields['password'] = _passwordController.text;

    if (_profileImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'profileImage',
        _profileImage!.path,
      ));
    }

    try {
    var response = await request.send();

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student successfully added!')),
      );
      _clearForm();
    } else {
      final responseBody = await response.stream.bytesToString();
      print("Server error response: $responseBody");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add student.')),
      );
    }
  } catch (e) {
    print("Network or server error: $e");
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
