import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/View/HomePage.dart';
import 'package:ssh_web/View/LoginPage.dart';
import 'package:ssh_web/View/PengaduanPage.dart';
import 'package:ssh_web/View/SettingPage.dart';
import 'package:ssh_web/component/logout_button.dart';

class AdminPanel extends StatefulWidget {
  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  Map<String, dynamic> payload = {};
  String userName = '';
  String userId = '';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    decodeToken();
  }

  // Fungsi untuk mengganti halaman saat menu dipilih
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Fungsi untuk menghapus token dan data lainnya
  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('accesToken'); // Hapus token akses
  }

  Future<void> decodeToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken != null) {
      try {
        // Decode token JWT
        payload = JwtDecoder.decode(accessToken);

        String name = payload['sub'].split(',')[2];
        String id = payload['sub'].split(',')[0];

        // Ambil peran (roles) dari payload
        var roles = payload['roles']; // Ambil roles

        // Jika roles berupa string dalam format "[ROLE_USER]", hapus tanda kurung
        if (roles is String) {
          roles = roles.replaceAll('[', '').replaceAll(']', '').split(',');
        }

        // Periksa apakah peran adalah 'ROLE_ADMIN'
        if (roles.contains('ROLE_ADMIN')) {
          // Peran adalah ROLE_ADMIN, lanjutkan ke halaman admin
          setState(() {
            userName = name;
            userId = id;
          });
        } else {
          // Jika peran bukan 'ROLE_ADMIN', tampilkan pesan akses ditolak dan logout
          _showAccessDeniedMessage(context);
          // Tunggu beberapa detik, kemudian logout
          Future.delayed(const Duration(seconds: 2), () {
            _navigateToLogOut(context);
          });
        }
      } catch (e) {
        print('Error decoding token: $e');
        _navigateToLogOut(context); // Jika terjadi error pada token, logout
      }
    } else {
      // Jika token tidak ada, arahkan ke halaman login
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel $userName'),
      ),
      body: Row(
        children: [
          // Sidebar tetap terlihat di sebelah kiri
          Container(
            width: 250,
            color: Color(0xFF0D187E),
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                const DrawerHeader(
                  decoration: BoxDecoration(
                    color: Color(0xFF0D187E),
                  ),
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                ListTile(
                  title: const Text(
                    'Dashboard',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    _onItemTapped(0);
                  },
                ),
                ListTile(
                  title: const Text('Pengaduan',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(1);
                  },
                ),
                ListTile(
                  title: const Text('Settings',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(2);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: MyButtonLogout(
                    onTap: () async {
                      await _logout(); // Panggil fungsi logout
                      _navigateToLogOut(context); // Navigasi ke halaman login
                    },
                  ),
                ),
              ],
            ),
          ),
          // Bagian Konten yang berubah sesuai pilihan
          Expanded(
            child: _getSelectedWidget(),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk menampilkan halaman sesuai menu yang dipilih
  Widget _getSelectedWidget() {
    switch (_selectedIndex) {
      case 0:
        return HomePage(); // Halaman Dashboard
      case 1:
        return PengaduanPage(); // Halaman Pengaduan
      case 2:
        return SettingPage(); // Halaman Settings
      default:
        return HomePage();
    }
  }

  // Fungsi navigasi ke halaman logout
  void _navigateToLogOut(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: LoginPage(),
        ),
      ),
      (Route<dynamic> route) => false, // Hapus semua route sebelumnya
    );
  }
}
