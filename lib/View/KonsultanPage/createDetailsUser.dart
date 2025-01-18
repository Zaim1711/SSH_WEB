import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateDetailsUserPage extends StatefulWidget {
  const CreateDetailsUserPage({super.key});

  @override
  State<CreateDetailsUserPage> createState() => _CreateDetailsUserPageState();
}

class _CreateDetailsUserPageState extends State<CreateDetailsUserPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _nikController = TextEditingController();
  String userId = '';
  bool isLoading = false;
  XFile? _pickedImage;
  Uint8List? _webImage;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  Future<void> _getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');
    if (accessToken != null) {
      try {
        final payload = JwtDecoder.decode(accessToken);
        setState(() {
          userId = payload['sub'].split(',')[0];
        });
      } catch (e) {
        print('Error decoding token: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        // Get the bytes for web
        final bytes = await pickedFile.readAsBytes();

        // Validate file size (max 2MB)
        if (bytes.length > 2 * 1024 * 1024) {
          throw Exception('File too large. Maximum size is 2MB');
        }

        // Validate file type
        final mimeType = pickedFile.mimeType ?? '';
        if (!mimeType.startsWith('image/')) {
          throw Exception('Invalid file type. Please use JPG, JPEG or PNG');
        }

        setState(() {
          _pickedImage = pickedFile;
          _webImage = bytes;
        });

        // Upload immediately after picking
        await _updateProfileImage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _updateProfileImage() async {
    if (_pickedImage == null || _webImage == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accesToken');

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    try {
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8080/details/update-image/$userId'),
      );

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Add image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          _webImage!,
          filename: _pickedImage!.name,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Refresh user details to get updated image URL
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile image updated successfully')),
        );
      } else {
        throw Exception('Failed to update image: ${response.body}');
      }
    } catch (e) {
      print('Error updating profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile image: $e')),
      );
    }
  }

  Future<void> _createUserDetails() async {
    if (_phoneController.text.isEmpty || _imageUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('accesToken');

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/details/user/create'),
        headers: {
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'userId': userId,
          'nik': _nikController.text,
          'alamat': _alamatController.text,
          'nomor_telepon': _phoneController.text,
        }),
      );

      if (response.statusCode == 201) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Details created successfully')),
        );
      } else {
        throw Exception('Failed to create details');
      }
    } catch (e) {
      print('Error creating user details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create user details')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Image fetching function
  Future<Uint8List?> fetchImage() async {}

  Widget _buildProfileImageWithFuture() {
    return FutureBuilder<Uint8List?>(
      future: fetchImage(),
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            radius: 50,
            child: CircularProgressIndicator(), // Show progress indicator
          );
        } else if (snapshot.hasError) {
          return CircleAvatar(
            radius: 50,
            child: Icon(Icons.error, size: 50), // Show error icon
          );
        } else {
          final imageBytes = snapshot.data;
          return CircleAvatar(
            radius: 50,
            backgroundImage:
                imageBytes != null ? MemoryImage(imageBytes) : null,
            child: imageBytes == null
                ? Icon(Icons.person, size: 50) // Default icon if no image
                : null,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create User Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildProfileImageWithFuture(),
            Positioned(
              bottom: 0,
              right: 0,
              child: CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 18,
                child: IconButton(
                  icon: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  onPressed: _pickImage,
                ),
              ),
            ),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter phone number',
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _nikController,
              decoration: InputDecoration(
                labelText: 'Nik',
                hintText: 'Masukan Nik anda',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _alamatController,
              decoration: InputDecoration(
                labelText: 'Alamat',
                hintText: 'Masukan Alamat anda',
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _imageUrlController,
              decoration: InputDecoration(
                labelText: 'Image URL',
                hintText: 'Enter image URL',
              ),
            ),
            SizedBox(height: 32),
            isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _createUserDetails,
                    child: Text('Create Details'),
                  ),
          ],
        ),
      ),
    );
  }
}
