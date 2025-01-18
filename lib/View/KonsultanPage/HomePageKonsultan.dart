import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/DetailsUser.dart';
import 'package:ssh_web/View/AdminPage/LoginPage.dart';

class HomePageKonsultan extends StatefulWidget {
  const HomePageKonsultan({super.key});

  @override
  State<HomePageKonsultan> createState() => _HomePageKonsultanState();
}

class _HomePageKonsultanState extends State<HomePageKonsultan> {
  Map<String, dynamic> payload = {};
  String userName = '';
  String userId = '';
  String userRole = '';
  String userEmail = '';
  String phoneNumber = '';
  String imageUrl = '';
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    decodeToken();
  }

  Future<DetailsUser?> fetchUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('accesToken');

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/details/user/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse != null) {
          setState(() {});

          DetailsUser details = DetailsUser.fromJson(jsonResponse);

          // Update the rest of the controllers
          phoneNumber = details.nomorTelepon.toString();
          imageUrl = details.imageUrl ?? '';
          print('Response status: ${response.statusCode}');

          return details;
        }
      } else if (response.statusCode == 404) {
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

  Widget _buildInfoColumn(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: isSmallScreen ? 10 : 18,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 12 : 24,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Future<void> decodeToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken != null) {
      try {
        payload = JwtDecoder.decode(accessToken);
        String email = payload['sub'].split(',')[1];
        String name = payload['sub'].split(',')[2];
        String id = payload['sub'].split(',')[0];
        var roles = payload['roles'];
        if (roles is String) {
          roles = roles
              .replaceAll('[', '')
              .replaceAll('ROLE_', '')
              .replaceAll(']', '')
              .split(',');
          setState(() {
            userRole = roles[0];
            userName = name;
            userId = id;
            userEmail = email;
          });
        } else {}
      } catch (e) {
        print('Error decode Token: $e');
      }
      fetchUserDetails();
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

  Widget _buildProfileAppbar(double radius) {
    return FutureBuilder<Uint8List?>(
      future: fetchImage(imageUrl),
      builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircleAvatar(
            radius: radius,
            child: CircularProgressIndicator(), // Show progress indicator
          );
        } else if (snapshot.hasError) {
          return CircleAvatar(
            radius: radius,
            child: Icon(Icons.error, size: radius), // Show error icon
          );
        } else {
          final imageBytes = snapshot.data;
          return CircleAvatar(
            radius: radius,
            backgroundImage:
                imageBytes != null ? MemoryImage(imageBytes) : null,
            child: imageBytes == null
                ? Icon(Icons.person, size: radius) // Default icon if no image
                : null,
          );
        }
      },
    );
  }

  Future<void> _deleteFcmToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');
    String url = 'http://localhost:8080/api/tokens/$userId';

    if (accessToken != null) {
      Dio dio = Dio();
      dio.options.headers['Authorization'] = 'Bearer $accessToken';

      try {
        await dio.delete(url);
        print('FCM token deleted successfully');
      } catch (e) {
        print('Error deleting FCM token: $e');
      }
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('accesToken');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1365;
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 300,
                height: 50,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    // Menambahkan ikon di akhir TextField
                  ),
                  style: const TextStyle(color: Colors.black),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                ),
              ),
              // Avatar circular di kanan
              Row(
                children: [
                  _buildProfileAppbar(20.0),
                  const SizedBox(width: 10), // Jarak antara avatar dan teks
                  Text('$userName', style: TextStyle(color: Colors.black)),

                  // Ikon dropdown yang menampilkan menu saat diklik
                  PopupMenuButton<String>(
                    icon: Icon(Icons.arrow_drop_down, color: Colors.black),
                    onSelected: (String value) async {
                      if (value == 'Logout') {
                        // Aksi ketika memilih Logout
                        await _deleteFcmToken();
                        await _logout();
                        _navigateToLogOut(context);
                        print('Logout selected');
                      } else if (value == 'Profile') {
                        // Aksi ketika memilih Profile
                        print('Profile selected');
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return {'Profile', 'Logout'}.map((String choice) {
                        return PopupMenuItem<String>(
                          value: choice,
                          child: Text(choice),
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                color: Color(0xFF0D187E),
                elevation: 10,
                margin: const EdgeInsets.all(8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          VerticalDivider(
                            thickness: 10,
                            color: Colors.black,
                            width: 20,
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Text(
                              'Detail Konsultan',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14 : 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            isSmallScreen
                                ? _buildProfileAppbar(50.0)
                                : _buildProfileAppbar(100),
                            SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$userName',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 16 : 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    isSmallScreen
                                        ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildInfoColumn(
                                                  'Role',
                                                  '$userRole'.toLowerCase(),
                                                  isSmallScreen),
                                              SizedBox(
                                                width: 20,
                                              ),
                                              _buildInfoColumn(
                                                  'Phone Number',
                                                  '(+62)$phoneNumber',
                                                  isSmallScreen),
                                              SizedBox(
                                                width: 20,
                                              ),
                                              _buildInfoColumn('Email Address',
                                                  '$userEmail', isSmallScreen),
                                            ],
                                          )
                                        : Row(
                                            children: [
                                              _buildInfoColumn(
                                                  'Role',
                                                  '$userRole'.toLowerCase(),
                                                  isSmallScreen),
                                              SizedBox(
                                                width: 20,
                                              ),
                                              _buildInfoColumn(
                                                  'Phone Number',
                                                  '(+62)$phoneNumber',
                                                  isSmallScreen),
                                              SizedBox(
                                                width: 20,
                                              ),
                                              _buildInfoColumn('Email Address',
                                                  '$userEmail', isSmallScreen),
                                            ],
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _navigateToLogOut(BuildContext context) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => LoginPage()),
  );
}
