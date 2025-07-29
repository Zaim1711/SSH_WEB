import 'dart:async';
import 'dart:convert'; // Untuk jsonDecode
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/DetailsUser.dart';
import 'package:ssh_web/View/AdminPage/AdminChatPage.dart';
import 'package:ssh_web/View/AdminPage/HomePage.dart';
import 'package:ssh_web/View/AdminPage/InformasiHakHukum.dart';
import 'package:ssh_web/View/AdminPage/LoginPage.dart';
import 'package:ssh_web/View/AdminPage/ManageUserPage.dart';
import 'package:ssh_web/View/AdminPage/PengaduanPage.dart';
import 'package:ssh_web/View/AdminPage/RealTimeTrackingSOS.dart';
import 'package:ssh_web/View/AdminPage/SettingPage.dart';
import 'package:ssh_web/View/KonsultanPage/ProfilePage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AdminPanel extends StatefulWidget {
  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  Map<String, dynamic> payload = {};
  String userName = '';
  String userId = '';
  String imageUrl = '';
  int _selectedIndex = 0;
  late WebSocketChannel channel;
  late StreamSubscription _subscription;
  bool isNotificationShown = false;

  @override
  void initState() {
    super.initState();
    channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8080/ws'));

    _subscription = channel.stream.listen((message) {
      print('Pesan diterima: $message');
      try {
        // Menghapus "Message Receive:" jika ada
        String jsonString = message.replaceFirst('Message Receive:', '').trim();

        // Cek jika formatnya adalah JSON yang valid
        if (jsonString.startsWith('{') && jsonString.endsWith('}')) {
          final sosMessage =
              jsonDecode(jsonString); // Mengubah pesan menjadi Map
          // Hanya tampilkan notifikasi jika belum ditampilkan
          if (!isNotificationShown) {
            _showSOSNotification(
                sosMessage, channel); // Menampilkan notifikasi SOS
            isNotificationShown =
                true; // Tandai bahwa notifikasi sudah ditampilkan
          }
        } else {
          print('Pesan yang diterima bukan JSON valid: $jsonString');
        }
      } catch (e) {
        print('Error parsing WebSocket message: $e');
      }
    });
    decodeToken();
    fetchUserDetails();
  }

  @override
  void dispose() {
    _subscription.cancel(); // Stop listening to WebSocket messages
    channel.sink.close(); // Close WebSocket connection
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showSOSNotification(
      Map<String, dynamic> sosMessage, WebSocketChannel channel) {
    final userId = sosMessage['userId'];
    final latitude = sosMessage['latitude'];
    final longitude = sosMessage['longitude'];
    final timestamp = sosMessage['timestamp'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Pesan Darurat Diterima'),
        content: Text(
            'Pengguna $userId mengirim sinyal SOS pada $timestamp di lokasi ($latitude, $longitude).'),
        actions: [
          // Tombol untuk menutup dialog
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              isNotificationShown = false; // Reset flag setelah dialog ditutup
            },
            child: Text('Tutup'),
          ),
          // Tombol untuk membuka halaman RealTimeTrackingSOS
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RealTimeTrackingSOS(),
                ),
              ).then((_) {
                // Reset flag setelah kembali ke halaman utama
                isNotificationShown = false;
              });
            },
            child: Text('Lihat Lokasi'),
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
        String name = payload['sub'].split(',')[2];
        String id = payload['sub'].split(',')[0];
        var roles = payload['roles'];

        if (roles is String) {
          roles = roles.replaceAll('[', '').replaceAll(']', '').split(',');
        }

        if (roles.contains('ROLE_ADMIN')) {
          setState(() {
            userName = name;
            userId = id;
          });
        } else {
          _showAccessDeniedMessage(context);
          Future.delayed(const Duration(seconds: 2), () {
            _navigateToLogOut(context);
          });
        }
      } catch (e) {
        print('Error decoding token: $e');
        _navigateToLogOut(context);
      }
    } else {
      _navigateToLogOut(context);
    }
  }

  void _showAccessDeniedMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Access Denied"),
          content: const Text("You do not have access to this page."),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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

  void _showDataNotFoundDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Profile anda belum lengkap'),
          content: const Text(
              'Data profile anda belum lengkap. Silakan isi data pengguna terlebih dahulu agar dapat melakukan pelaporan.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
                _onItemTapped(6);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Kiri: Judul
            Text(
              'Admin Panel  $userName',
              style: const TextStyle(color: Colors.black),
            ),

            // Kanan: Avatar + Nama + Dropdown
            Row(
              children: [
                _buildProfileAppbar(20),
                const SizedBox(width: 10),
                Text(
                  '$userName',
                  style: const TextStyle(color: Colors.black),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.black,
                  ),
                  onSelected: (String value) async {
                    if (value == 'Logout') {
                      await _showLogoutConfirmationDialog(context);
                      print('Logout selected');
                    } else if (value == 'Profile') {
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
      body: Row(
        children: [
          Container(
            width: 250,
            color: Color(0xFF0D187E),
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                const ListTile(
                  title: Text(
                    'MAIN MENU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.dashboard,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Dashboard',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    _onItemTapped(0);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.report,
                    color: Colors.white,
                  ),
                  title: const Text('Pengaduan',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(1);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.info,
                    color: Colors.white,
                  ),
                  title: const Text('Informasi Hak & Hukum',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(2);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.group,
                    color: Colors.white,
                  ),
                  title: const Text('Manage User',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(4);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.chat,
                    color: Colors.white,
                  ),
                  title: const Text('Chatting',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(5);
                  },
                ),
                const SizedBox(
                  height: 20,
                ),
                const ListTile(
                  title: Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.settings,
                    color: Colors.white,
                  ),
                  title: const Text('Settings',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(3);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                  title: const Text('Profile',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(6);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _getSelectedWidget(),
          ),
        ],
      ),
    );
  }

  Widget _getSelectedWidget() {
    switch (_selectedIndex) {
      case 0:
        return Homepage(onMenuSelected: _onItemTapped);
      case 1:
        return PengaduanPage();
      case 2:
        return InformasiHakHukum();
      case 3:
        return SettingPage();
      case 4:
        return ManageUserPage();
      case 5:
        return AdminChatPage();
      case 6:
        return ProfilePage();
      default:
        return Homepage(onMenuSelected: _onItemTapped);
    }
  }

  void _navigateToLogOut(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }
}
