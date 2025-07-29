import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/DetailsUser.dart';
import 'package:ssh_web/Model/UserChat.dart';
import 'package:ssh_web/Service/NotificatioonService.dart';
import 'package:ssh_web/Service/UserService.dart';
import 'package:ssh_web/View/AdminPage/ChatScreen.dart';
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
  final NotificationService _notificationService = NotificationService();
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

  Future<void> _showChatConfirmation(
      BuildContext context, Map<String, dynamic> konsultasi) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Chat'),
          content:
              const Text('Apakah Anda yakin ingin memulai chat konsultasi?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog

                User user =
                    await UserService().fetchUser(konsultasi['senderId']);

                await _updateStatus(konsultasi['id']
                    .toString()); // Panggil fungsi _updateStatus

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Chatscreen(
                      user: user,
                      senderId: userId,
                    ),
                  ),
                );
              },
              child: const Text('Ya, Mulai Chat'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateStatus(String id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? accessToken = prefs.getString('accesToken');

      if (accessToken == null) {
        print('Access token tidak ditemukan');
        print(id);
        return;
      }

      final url = Uri.parse('http://localhost:8080/Konsultasi/update/$id');
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode([
          {'status_konsul': 'Accepted'}
        ]),
      );

      if (response.statusCode == 200) {
        print('Status berhasil diupdate');
      } else {
        print('Gagal mengupdate status');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void navigateToChatScreen(BuildContext context, User user, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Chatscreen(
          user: user,
          senderId: userId,
        ),
      ),
    );
  }

  void showNotification(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
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

  Future<List<dynamic>> _getKonsultasiRiwayat() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');
    final response = await http.get(
      Uri.parse("http://localhost:8080/Konsultasi"),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('accesToken');
  }

  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Konfirmasi Logout',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Apakah Anda yakin ingin keluar?',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Tidak',
                  style: TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ),
              ElevatedButton(
                  onPressed: () async {
                    await _deleteFcmToken();
                    await _logout();
                    _navigateToLogOut(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: Text(
                    'Ya',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ))
            ],
          );
        });
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
              Card(
                child: Expanded(
                  child: FutureBuilder(
                    future: _getKonsultasiRiwayat(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        // Filter data, hanya ambil yang status_konsul-nya 'waiting'
                        final filteredData = snapshot.data!
                            .where(
                                (item) => item['status_konsul'] == 'Waitting')
                            .toList();

                        // Cek jika filteredData kosong
                        if (filteredData.isEmpty) {
                          return Center(
                            child: Text(
                              "Belum ada konsultasi",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredData.length,
                          itemBuilder: (context, index) {
                            return FutureBuilder(
                              future: UserService()
                                  .fetchUser(filteredData[index]['senderId']),
                              builder: (context, userSnapshot) {
                                if (userSnapshot.hasData) {
                                  User user = userSnapshot.data!;
                                  return Card(
                                    elevation: 5,
                                    margin: const EdgeInsets.all(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Nama : ${user.username}',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey),
                                          ),
                                          Text(
                                            'Email : ${user.email}',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey),
                                          ),
                                          Text(
                                            'Pesan Konsultasi: ${filteredData[index]['message']}',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            'Status: ${filteredData[index]['status_konsul']}',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey),
                                          ),
                                          SizedBox(height: 10),
                                          ElevatedButton(
                                            onPressed: () =>
                                                _showChatConfirmation(
                                              context,
                                              filteredData[index],
                                            ),
                                            child: Text('Mulai Chat'),
                                            style: ElevatedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              backgroundColor: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else if (userSnapshot.hasError) {
                                  return Text('Error: ${userSnapshot.error}');
                                } else {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                              },
                            );
                          },
                        );
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                    },
                  ),
                ),
              )
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
