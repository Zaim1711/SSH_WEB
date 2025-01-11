import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Service/NotificatioonService.dart';
import 'package:ssh_web/View/AdminPage/LoginPage.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool isSearching = false;
  @override
  void initState() {
    super.initState();
    notificationService.init();
    notificationService.configureFCM();
    notificationService.getDeviceToken().then((value) {
      print('device token');
    });
    decodeToken();
    print(userEmail);
    print(userRole);
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
            ],
          ),
        ),
      ),
    );
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
