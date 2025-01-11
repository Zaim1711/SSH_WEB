import 'dart:async';
import 'dart:convert'; // Untuk jsonDecode

import 'package:flutter/material.dart';
import 'package:ssh_web/View/AdminPage/AdminChatPage.dart';
import 'package:ssh_web/View/AdminPage/LoginPage.dart';
import 'package:ssh_web/View/AdminPage/RealTimeTrackingSOS.dart';
import 'package:ssh_web/View/AdminPage/SettingPage.dart';
import 'package:ssh_web/View/KonsultanPage/HomePageKonsultan.dart';
import 'package:ssh_web/View/KonsultanPage/ProfilePage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class KonsultanPanel extends StatefulWidget {
  @override
  _KonsultanPanelState createState() => _KonsultanPanelState();
}

class _KonsultanPanelState extends State<KonsultanPanel> {
  Map<String, dynamic> payload = {};
  String userName = '';
  String userId = '';
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

    // decodeToken();
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

  // Future<void> decodeToken() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String? accessToken = prefs.getString('accesToken');

  //   if (accessToken != null) {
  //     try {
  //       payload = JwtDecoder.decode(accessToken);
  //       String name = payload['sub'].split(',')[2];
  //       String id = payload['sub'].split(',')[0];
  //       var roles = payload['roles'];

  //       if (roles is String) {
  //         roles = roles.replaceAll('[', '').replaceAll(']', '').split(',');
  //       }

  //       if (roles.contains('ROLE_KONSULTAN')) {
  //         setState(() {
  //           userName = name;
  //           userId = id;
  //         });
  //       } else {
  //         _showAccessDeniedMessage(context);
  //         Future.delayed(const Duration(seconds: 2), () {
  //           _navigateToLogOut(context);
  //         });
  //       }
  //     } catch (e) {
  //       print('Error decoding token: $e');
  //       _navigateToLogOut(context);
  //     }
  //   } else {
  //     _navigateToLogOut(context);
  //   }
  // }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Konsultan Panel $userName'),
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
                    'MAIN MENU ',
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
                    Icons.chat,
                    color: Colors.white,
                  ),
                  title: const Text('Chatting',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(1);
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
                    _onItemTapped(3);
                  },
                ),
                ListTile(
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
                    _onItemTapped(2);
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
        return HomePageKonsultan();
      case 2:
        return SettingPage();
      case 1:
        return AdminChatPage();
      case 3:
        return ProfilePage();
      default:
        return HomePageKonsultan();
    }
  }

  void _navigateToLogOut(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }
}
