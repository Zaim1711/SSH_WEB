import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/UserChat.dart';
import 'package:ssh_web/View/AdminPage/ChatScreen.dart';

class UserService {
  Future<List<User>> fetchUsers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken == null) {
      throw Exception('Access token not found');
    }

    final response = await http.get(
      Uri.parse("http://localhost:8080/users"),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> jsonResponse = json.decode(response.body);
      return jsonResponse.map((user) => User.fromJson(user)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }
}

class UserListChat extends StatefulWidget {
  @override
  _UserListChatState createState() => _UserListChatState();
}

class _UserListChatState extends State<UserListChat> {
  late Future<List<User>> futureUsers;
  String userEmail = '';
  String userId = '';

  @override
  void initState() {
    super.initState();
    futureUsers = UserService().fetchUsers();
    decodeToken();
  }

  Future<void> decodeToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken != null) {
      Map<String, dynamic> payload = JwtDecoder.decode(accessToken);
      setState(() {
        userEmail = payload['sub'].split(',')[1];
        userId = payload['sub'].split(',')[0];
      });
    } else {
      print("Token not found.");
    }
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

  // Future<void> createRoom(User user, String userId) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String? accessToken = prefs.getString('accesToken');

  //   if (accessToken == null) {
  //     print('Access token is null');
  //     showNotification('Access token not found');
  //     return;
  //   }

  //   final url = Uri.parse(ApiConfig.createRoom);
  //   final response = await http.post(url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $accessToken',
  //       },
  //       body: jsonEncode({
  //         'senderId': userId,
  //         'receiverId': user.id,
  //       }));

  //   if (response.statusCode == 201) {
  //     final data = jsonDecode(response.body);
  //     int roomId = data['id'];
  //     navigateToChatScreen(roomId.toString(), user.id.toString(), userId);
  //   } else {
  //     if (response.statusCode == 409) {
  //       showNotification('Chat sudah ada.');
  //     } else {
  //       print('An error occurred: ${response.body}');
  //     }
  //   }
  // }

  void navigateToChatScreen(User user, String userId) {
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

  @override
  Widget build(BuildContext context) {
    const String defaultProfileImagePath = 'lib/image/image.png';

    return Scaffold(
      appBar: AppBar(
        title: Text('Daftar Pengguna'),
      ),
      body: FutureBuilder<List<User>>(
        future: futureUsers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Tidak ada pengguna ditemukan.'));
          }

          List<User> users = snapshot.data!
              .where((user) =>
                  user.email !=
                  userEmail) // Filter out the logged-in user by email
              .where((user) => user.roles.any((role) =>
                  role.name ==
                  'ROLE_KONSULTAN')) // Filter users with ROLE_PSYCOLOGIST
              .toList();

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  child: Text(
                    users[index].username[0].toUpperCase(),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(users[index].email),
                onTap: () => navigateToChatScreen(users[index], userId),
              );
            },
          );
        },
      ),
    );
  }
}
