import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/DetailsUser.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<DetailsUser?> _initializationFuture;
  XFile? _pickedImage;
  Uint8List? _webImage;
  late DetailsUser detailsUser;
  File? _image;
  String userName = '';
  String userEmail = '';
  String userId = '';
  String userRole = 'Admin';
  String accessToken = '';
  final _picker = ImagePicker();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController alamatController = TextEditingController();
  final TextEditingController nikController =
      TextEditingController(); // Added NIK controller

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeData();
  }

  Future<DetailsUser?> _initializeData() async {
    try {
      return await fetchUserDetails();
    } catch (e) {
      print('Error initializing data: $e');
      rethrow;
    }
  }

  Future<DetailsUser?> fetchUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('accesToken');

    if (token == null) {
      throw Exception('Access token is null');
    }

    setState(() {
      accessToken = token;
    });

    Map<String, dynamic> payload = JwtDecoder.decode(token);
    String id = payload['sub'].split(',')[0];
    String email = payload['sub'].split(',')[1];
    String name = payload['sub'].split(',')[2];

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/details/user/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse != null) {
          setState(() {
            userId = id;
            userEmail = email;
            userName = name;

            // Update controllers with fetched data
            emailController.text = userEmail;
            nameController.text = userName;
          });

          DetailsUser details = DetailsUser.fromJson(jsonResponse);

          // Update the rest of the controllers
          nikController.text = details.nik.toString();
          alamatController.text = details.alamat;
          phoneController.text = details.nomorTelepon.toString();
          print('Response status: ${response.statusCode}');
          print('Response body: ${response.body}');

          return details;
        }
      } else if (response.statusCode == 404) {
        setState(() {
          userId = id;
          userEmail = email;
          userName = name;
        });
        return null;
      } else {
        throw Exception('Failed to load user details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user details: $e');
      rethrow;
    }
    return null;
  }

  Future<void> _saveProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken == null) {
      print('Access Token not found!');
      return;
    }

    final requestBody = {
      'nik': nikController.text,
      'alamat': alamatController.text,
      'nomor_telepon': phoneController.text,
    };

    final url = Uri.parse('http://localhost:8080/details/$userId');
    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile saved successfully!')),
      );
      await fetchUserDetails(); // Refresh data after saving
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: ${response.body}')),
      );
    }
  }

  // Modified upload function for web
  Future<void> _uploadImage() async {
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
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8080/details/create'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['userId'] = userId
        ..fields['nik'] = nikController.text
        ..fields['alamat'] = alamatController.text
        ..fields['nomor_telepon'] = phoneController.text;
      if (_webImage != null && _pickedImage != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'imageUrl', // match the backend @RequestParam name
            _webImage!,
            filename: _pickedImage!.name,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }
      print('Uploading image of size: ${_webImage?.length ?? 0} bytes');
      print('File name: ${_pickedImage?.name}');
      var response = await request.send();
      var responseData = await http.Response.fromStream(response);

      if (response.statusCode == 200) {
        setState(() {
          _initializationFuture = fetchUserDetails();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
      } else {
        throw Exception('Failed to upload image: ${responseData.body}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
        setState(() {
          _initializationFuture = fetchUserDetails();
        });

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

  // Image fetching function
  Future<Uint8List?> fetchImage(String userImageUrl) async {
    print('imageName : $userImageUrl');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');
    if (accessToken == null) {
      print('Access token tidak ditemukan');
      return null;
    }

    final imageUrl = 'http://localhost:8080/details/image/$userImageUrl';
    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('Gagal mengambil gambar: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Terjadi kesalahan saat mengambil gambar: $e');
      return null;
    }
  }

  Widget _buildProfileImageWithFuture() {
    return FutureBuilder<Uint8List?>(
      future: fetchImage(detailsUser.imageUrl ?? ''),
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

  Future<void> _getImageFromGallery() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _pickedImage = pickedFile;
      setState(() {
        _webImage = File(pickedFile.path).readAsBytesSync();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1200;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder<DetailsUser?>(
            future: _initializationFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 60),
                      SizedBox(height: 16),
                      Text(
                        'Error loading profile\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ],
                  ),
                );
              } else if (!snapshot.hasData) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.person, color: Colors.grey, size: 50),
                      SizedBox(height: 10),
                      Text('No profile data available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16)),
                    ],
                  ),
                );
              } else {
                detailsUser = snapshot.data!;

                return Card(
                  elevation: 10,
                  margin: EdgeInsets.all(8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'Profile picture',
                              style: TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Stack(
                              children: [
                                _buildProfileImageWithFuture(),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.blue,
                                    radius: 18,
                                    child: IconButton(
                                      icon: Icon(Icons.camera_alt,
                                          size: 18, color: Colors.white),
                                      onPressed: _pickImage,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_image != null) ...[
                              SizedBox(height: 20),
                              Text('Preview Image:'),
                              Image.file(
                                _image!,
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _image = null; // Reset pilihan gambar
                                  });
                                },
                                child: Text('Cancel'),
                              ),
                            ],
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 18 : 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  userEmail,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 24,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        Divider(color: Colors.grey),
                        SizedBox(height: 20),
                        _buildInfoRow('Alamat', alamatController),
                        _buildInfoRow('Nik', nikController),
                        _buildInfoRow('Phone', phoneController),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            await _saveProfile();
                          },
                          child: Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            textStyle: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await _pickImage();
                          },
                          child: Text('Change Profile Picture'),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 4),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            ),
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
