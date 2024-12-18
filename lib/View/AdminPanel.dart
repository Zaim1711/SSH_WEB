import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/View/HomePage.dart';
import 'package:ssh_web/View/InformasiHakHukum.dart';
import 'package:ssh_web/View/LoginPage.dart';
import 'package:ssh_web/View/ManageUserPage.dart';
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('accesToken');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel $userName'),
      ),
      body: Row(
        children: [
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
                  title: const Text('Informasi Hak & Hukum',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(2);
                  },
                ),
                ListTile(
                  title: const Text('Manage User',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(4);
                  },
                ),
                ListTile(
                  title: const Text('Settings',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _onItemTapped(3);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: MyButtonLogout(
                    onTap: () async {
                      await _logout();
                      _navigateToLogOut(context);
                    },
                  ),
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
        return Homepage(onMenuSelected: _onItemTapped); // Pass callback
      case 1:
        return PengaduanPage(); // Halaman Pengaduan
      case 2:
        return InformasiHakHukum(); // Halaman Informasi Hak & Hukum
      case 3:
        return SettingPage(); // Halaman Settings
      case 4:
        return ManageUserPage();
      default:
        return Homepage(onMenuSelected: _onItemTapped);
    }
  }

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
      (Route<dynamic> route) => false,
    );
  }
}
