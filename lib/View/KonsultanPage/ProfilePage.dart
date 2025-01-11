import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/DetailsUser.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
    fetchUserDetails();
    print(nameController);
    print(phoneController);
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // Batasi ukuran gambar
      maxHeight: 800,
      imageQuality: 85, // Kompres kualitas gambar
    );

    if (pickedFile != null) {
      final fileSize = await pickedFile.length();
      // Batasi ukuran file (contoh: 2MB)
      if (fileSize > 2 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File too large. Maximum size is 2MB')),
        );
        return;
      }

      setState(() {
        _image = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  // Update fungsi upload image
  Future<void> _uploadImage() async {
    if (_image == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');
    if (accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not authenticated')),
      );
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:8080/details/create'),
      );

      request.headers['Authorization'] = 'Bearer $accessToken';

      // Tambahkan file gambar
      request.files.add(
        await http.MultipartFile.fromPath(
          'imageUrl',
          _image!.path,
        ),
      );

      // Tambahkan data lainnya
      request.fields['userId'] = userId;
      request.fields['nik'] = nikController.text;
      request.fields['alamat'] = alamatController.text;
      request.fields['nomor_telepon'] = phoneController.text;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image uploaded successfully')),
        );
        await fetchUserDetails(); // Refresh data
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $responseBody')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
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

  Future<void> fetchUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken == null) {
      throw Exception('Access token is null');
    }

    Map<String, dynamic> payload = JwtDecoder.decode(accessToken);
    String id = payload['sub'].split(',')[0];
    String email = payload['sub'].split(',')[1];
    String name = payload['sub'].split(',')[2];

    final response = await http.get(
      Uri.parse('http://localhost:8080/details/user/$id'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse != null) {
        setState(() {
          userId = id;
          userEmail = email;
          userName = name;
          detailsUser = DetailsUser.fromJson(jsonResponse);
          accessToken = accessToken;

          // Update controllers with fetched data
          nikController.text = detailsUser.nik.toString();
          alamatController.text = detailsUser.alamat;
          phoneController.text = detailsUser.nomorTelepon;
        });
      }
    } else if (response.statusCode == 404) {
      // Handle case where user details don't exist yet
      setState(() {
        userId = id;
        userEmail = email;
        userName = name;
      });
    } else {
      throw Exception('Failed to load user details: ${response.statusCode}');
    }
  }

  Widget _buildProfileImage(String? imageFileName) {
    // Tentukan gambar default
    const String defaultImage =
        'assets/default_profile.png'; // Pastikan file ini ada di assets

    // Jika ada file gambar yang baru dipilih
    if (_image != null) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: FileImage(_image!),
      );
    }

    // Jika imageUrl null atau kosong, tampilkan gambar default
    if (imageFileName == null || imageFileName.isEmpty) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey[200],
        child: Icon(
          Icons.person,
          size: 50,
          color: Colors.grey[800],
        ),
        // Alternatif menggunakan gambar asset:
        // backgroundImage: AssetImage(defaultImage),
      );
    }

    // Jika ada imageUrl, coba tampilkan dari server
    return CircleAvatar(
      radius: 50,
      backgroundImage: NetworkImage(
        'http://localhost:8080/details/image/$imageFileName',
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ),
      // Jika gagal load gambar dari server, tampilkan default
      onBackgroundImageError: (exception, stackTrace) {
        print('Error loading image: $exception');
      },
    );
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
          child: FutureBuilder(
            future: fetchUserDetails(),
            // Add your API call for fetching the user details here
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
                                _buildProfileImage(detailsUser.imageUrl),
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
                        _buildInfoRow('alamat', alamatController),
                        _buildInfoRow('Email', emailController),
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
