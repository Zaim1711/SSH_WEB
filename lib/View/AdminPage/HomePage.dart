import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/DetailsUser.dart';
import 'package:ssh_web/Model/Pengaduan.dart';
import 'package:ssh_web/Service/NotificatioonService.dart';
import 'package:ssh_web/View/AdminPage/LoginPage.dart';
import 'package:ssh_web/View/AdminPage/ReviewPage.dart';

class Homepage extends StatefulWidget {
  final Function(int) onMenuSelected;

  const Homepage({super.key, required this.onMenuSelected});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  NotificationService notificationService = NotificationService();
  Map<String, dynamic> payload = {};
  String _selectedOption = 'Profile'; // Opsi yang terpilih di dropdown
  String userName = '';
  String userId = '';
  String userRole = '';
  String userEmail = '';
  String phoneNumber = '';
  String imageUrl = '';
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool isSearching = false;
  late Future<List<Pengaduan>> _pengaduanList;

  @override
  void initState() {
    super.initState();
    notificationService.init();
    notificationService.configureFCM();
    notificationService.getDeviceToken().then((value) {
      print('device token');
    });
    decodeToken();
    fetchUserDetails();
    _pengaduanList = fetchPengaduan();
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
        }
      } catch (e) {
        print('Error decoding token: $e');
      }
    } else {}
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
    final isSmallScreen = screenWidth < 1200;
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
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                              'Detail Admin',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                                ? _buildProfileAppbar(50)
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
                                        fontSize: isSmallScreen ? 16 : 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
                                                  '(+62)85648499655',
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
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Data Pengaduan belum Divalidasi',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                      FutureBuilder<List<Pengaduan>>(
                        future: _pengaduanList,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          } else if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return Center(
                                child: Text('Tidak ada data pengaduan.'));
                          } else {
                            final pengaduanList = snapshot.data!;

                            final validationData = pengaduanList
                                .where((pengaduan) =>
                                    pengaduan.status
                                        .toString()
                                        .split('.')
                                        .last ==
                                    'Validation')
                                .toList();

                            if (validationData.isNotEmpty) {
                              return isSmallScreen
                                  ? Container(
                                      padding: const EdgeInsets.all(16.0),
                                      child: _buildDataTable(validationData),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16.0),
                                      child: _buildDataTable(validationData),
                                    );
                            } else {
                              return Center(
                                  child: Text(
                                      'Tidak ada data pengaduan yang belum divalidasi.'));
                            }
                          }
                        },
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable(List<Pengaduan> pengaduanData) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Nama')),
                DataColumn(label: Text('Jenis Kekerasan')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Aksi')),
              ],
              rows: pengaduanData.map((pengaduan) {
                return DataRow(cells: [
                  DataCell(Text(pengaduan.id.toString())),
                  DataCell(Text(pengaduan.name)),
                  DataCell(Text(pengaduan.jenisKekerasan)),
                  DataCell(Text(pengaduan.status.toString().split('.').last)),
                  DataCell(
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0D187E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        elevation: 5,
                        shadowColor: Colors.tealAccent.withOpacity(0.5),
                        side: const BorderSide(
                          color: Color(0xFF0D187E),
                          width: 1.5,
                        ),
                      ),
                      onPressed: () {
                        _onReviewButtonPressed(pengaduan);
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rate_review, size: 18),
                          SizedBox(width: 8),
                          Text('Review'),
                        ],
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _onReviewButtonPressed(Pengaduan pengaduan) async {
    print('Tombol Review ditekan untuk Pengaduan ID: ${pengaduan.id}');

    try {
      // Memanggil fungsi fetchPengaduanWithUser   dengan mengirimkan pengaduan.id
      Pengaduan? selectedPengaduan = await fetchPengaduanWithUser(pengaduan.id);

      if (selectedPengaduan != null) {
        print('Pengaduan ditemukan: ${selectedPengaduan.name}');

        // Tampilkan dialog sebagai pop-up
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width *
                      0.5, // Maksimal lebar 80% dari lebar layar
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review Pengaduan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Menampilkan konten ReviewPage yang membutuhkan objek Pengaduan
                      ReviewPage(pengaduan: selectedPengaduan),

                      const SizedBox(height: 20),

                      // Tombol untuk menutup dialog
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(); // Menutup dialog
                          },
                          child: const Text('Tutup'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ).then((_) {
          // Menjalankan setState setelah dialog ditutup
          setState(() {
            _pengaduanList =
                fetchPengaduan(); // Memanggil ulang fetchPengaduan untuk memuat data terbaru
          });
        });
      } else {
        print('Pengaduan tidak ditemukan!');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Widget _buildInfoColumn(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: isSmallScreen ? 12 : 24,
                ),
              ),
              SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 12 : 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blueAccent),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.all(8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 30, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward, color: Colors.blueAccent),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLogOut(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }
}
