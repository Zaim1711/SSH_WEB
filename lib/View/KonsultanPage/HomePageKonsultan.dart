import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    decodeToken();
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
    }
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
                  CircleAvatar(
                    radius: 20, // Menentukan ukuran avatar
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
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
                            CircleAvatar(
                              radius: isSmallScreen ? 50 : 100,
                            ),
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
                                                  '(+62)85648499655',
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
