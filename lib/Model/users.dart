import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ssh_web/Model/Role.dart';

class Users {
  final int id;
  final String username;
  final String email;
  final List<Role> roles;
  final List<Role> idRoles;

  Users({
    required this.id,
    required this.username,
    required this.email,
    required this.roles,
    required this.idRoles,
  });

  factory Users.fromJson(Map<String, dynamic> json) {
    var roleList = json['roles'] as List;
    List<Role> roles = roleList.map((role) => Role.fromJson(role)).toList();

    return Users(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      roles: roles,
      idRoles: roles,
    );
  }
}

Future<List<Users>> fetchUsers() async {
  try {
    final response = await http.get(Uri.parse('http://localhost:8080/users'));
    print('Fetching users from: http://localhost:8080/users'); // Log URL

    if (response.statusCode == 200) {
      List<dynamic> userList = json.decode(response.body);
      return userList.map((user) => Users.fromJson(user)).toList();
    } else {
      print('Failed to load users: ${response.statusCode} ${response.body}');
      return [];
    }
  } catch (e) {
    print('Error fetching users: $e');
    return [];
  }
}
