import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/TrackingUserDetail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class UserLocation {
  final String userId;
  final LatLng location;
  final String name;
  DateTime lastUpdate; // Menambahkan waktu update terakhir

  UserLocation({
    required this.userId,
    required this.location,
    this.name = '',
    DateTime? lastUpdate,
  }) : lastUpdate = lastUpdate ?? DateTime.now();
}

class RealTimeTrackingSOS extends StatefulWidget {
  @override
  _RealTimeTrackingSOSState createState() => _RealTimeTrackingSOSState();
}

class _RealTimeTrackingSOSState extends State<RealTimeTrackingSOS>
    with SingleTickerProviderStateMixin {
  final Map<String, TrackingUserDetail> _userDetails = {};
  late WebSocketChannel channel;
  late MapController _mapController;
  final Map<String, UserLocation> _userLocations = {};
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  Timer? _cleanupTimer; // Timer untuk membersihkan user tidak aktif
  double _currentZoom = 18.0;
  bool _mounted = true;
  static const userTimeout =
      Duration(seconds: 10); // Timeout untuk user tidak aktif

  @override
  void initState() {
    super.initState();

    channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8080/ws'),
    );

    channel.stream.listen(
      (message) {
        if (!_mounted) return;

        print('Pesan diterima: $message');
        final cleanMessage = message.replaceFirst("Message Receive:", "");

        try {
          final data = jsonDecode(cleanMessage);
          print('Data JSON: $data');
          if (_mounted) {
            setState(() {
              final userId = data['userId'] as String;
              final newLocation = LatLng(
                data['latitude'] as double,
                data['longitude'] as double,
              );

              _userLocations[userId] = UserLocation(
                userId: userId,
                location: newLocation,
                name: data['name'] ?? 'User $userId',
                lastUpdate: DateTime.now(),
              );
            });
          }
        } catch (e) {
          print('Error decoding JSON: $e');
        }
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
      cancelOnError: true,
    );

    _mapController = MapController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _opacityAnimation =
        Tween<double>(begin: 1.0, end: 0.3).animate(_animationController);

    // Menambahkan timer untuk membersihkan user tidak aktif
    _cleanupTimer = Timer.periodic(Duration(seconds: 1), (_) {
      _cleanupInactiveUsers();
    });
  }

  void _cleanupInactiveUsers() {
    if (!_mounted) return;

    final now = DateTime.now();
    final inactiveUserIds = _userLocations.keys.where((userId) {
      final user = _userLocations[userId]!;
      return now.difference(user.lastUpdate) > userTimeout;
    }).toList();

    if (inactiveUserIds.isNotEmpty) {
      setState(() {
        for (final userId in inactiveUserIds) {
          _userLocations.remove(userId);
        }
      });
    }
  }

  Future<Map<String, dynamic>> fetchUserData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token =
        prefs.getString('accesToken'); // Ambil token dari SharedPreferences

    if (token == null) {
      throw Exception('Token not found');
    }

    final response = await http.get(
      Uri.parse('http://localhost:8080/users/$userId'),
      headers: {
        'Authorization': 'Bearer $token', // Sertakan token dalam header
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load user data');
    }
  }

  Future<Map<String, dynamic>> fetchUserDetails(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token =
        prefs.getString('accesToken'); // Ambil token dari SharedPreferences

    if (token == null) {
      throw Exception('Token not found');
    }

    final response = await http.get(
      Uri.parse('http://localhost:8080/details/user/$userId'),
      headers: {
        'Authorization': 'Bearer $token', // Sertakan token dalam header
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load user details');
    }
  }

  Future<void> fetchAndStoreUserData(String userId) async {
    try {
      final userData = await fetchUserData(userId);
      final userDetails = await fetchUserDetails(userId);

      print('UserData: $userData');
      print('UserDetails: $userDetails');

      setState(() {
        _userDetails[userId] = TrackingUserDetail(
          username: userData['username'] ?? 'Unknown',
          email: userData['email'] ?? 'Unknown',
          address: userDetails['alamat'] ?? 'No Address',
          phoneNumber:
              int.tryParse(userDetails['nomor_telepon'].toString()) ?? 0,
          nik: int.tryParse(userDetails['nik'].toString()) ?? 0,
        );
      });
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  // Fungsi untuk fokus ke lokasi user
  void _focusOnUser(UserLocation user) {
    _mapController.move(user.location, _currentZoom);
  }

  Color getMarkerColor(String userId) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];

    return colors[userId.hashCode % colors.length];
  }

  void _showLocationDetails(UserLocation userLocation) async {
    // Fetch the address from latitude and longitude
    List<Placemark> placemarks = await placemarkFromCoordinates(
      userLocation.location.latitude,
      userLocation.location.longitude,
    );

    // Get the first placemark
    Placemark placemark = placemarks.isNotEmpty ? placemarks[0] : Placemark();

    // Create the address string
    String address =
        '${placemark.street}, ${placemark.locality}, ${placemark.country}';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('User  ID: ${userLocation.userId}'),
              Text('Name: ${userLocation.name}'),
              Text('Latitude: ${userLocation.location.latitude}'),
              Text('Longitude: ${userLocation.location.longitude}'),
              Text('Address: $address'), // Display the address
              Text('Last Updated: ${userLocation.lastUpdate}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text('Close'),
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
        title: const Text('Real Time Tracking SOS'),
      ),
      body: Row(
        children: [
          // Sidebar untuk user yang mengirim SOS
          Container(
            width: 200,
            color: Colors.grey[200],
            child: ListView.builder(
              itemCount: _userLocations.length,
              itemBuilder: (context, index) {
                final userId = _userLocations.keys.elementAt(index);
                final userDetail = _userDetails[userId];
                print(index);

                // Memuat data jika belum tersedia
                if (userDetail == null) {
                  fetchAndStoreUserData(userId);
                  return ListTile(
                    title: Text('Loading...'),
                  );
                }

                return GestureDetector(
                  onTap: () => _focusOnUser(_userLocations[userId]!),
                  child: Card(
                    margin: EdgeInsets.all(8),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_pin_circle,
                                color: getMarkerColor(
                                    userId), // Dynamically set the color
                              ),
                              SizedBox(width: 8),
                              Text(
                                userDetail.username,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text('Email: ${userDetail.email}'),
                          Text('Alamat: ${userDetail.address}'),
                          Text('Telepon: ${userDetail.phoneNumber}'),
                          Text('NIK: ${userDetail.nik}'),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Peta
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(-6.914744, 107.609810),
                initialZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: _userLocations.entries.map((entry) {
                    return Marker(
                      point: entry.value.location,
                      width: 120.0,
                      height: 115.0,
                      child: GestureDetector(
                        onTap: () {
                          _showLocationDetails(
                              entry.value); // Call the function to show details
                        },
                        child: Icon(
                          Icons.location_pin,
                          size: 50,
                          color: getMarkerColor(
                              entry.key), // Color of the icon inside the marker
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mounted = false;
    _cleanupTimer?.cancel();
    channel.sink.close();
    _animationController.dispose();
    super.dispose();
  }
}
