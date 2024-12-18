import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ManageUserPage extends StatefulWidget {
  const ManageUserPage({super.key});

  @override
  State<ManageUserPage> createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage>
    with SingleTickerProviderStateMixin {
  List<User> users = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _fetchUsers() async {
    final response = await http.get(Uri.parse('http://localhost:8080/users'));

    if (response.statusCode == 200) {
      List<dynamic> userList = json.decode(response.body);
      setState(() {
        users = userList.map((user) => User.fromJson(user)).toList();
      });
    } else {
      throw Exception('Failed to load users');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'User '),
            Tab(text: 'Admin'),
            Tab(text: 'Konsultan'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _addUser();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList('ROLE_USER'),
          _buildUserList('ROLE_ADMIN'),
          _buildUserList('ROLE_KONSULTAN'),
        ],
      ),
    );
  }

  Widget _buildUserList(String role) {
    final filteredUsers = users.where((user) => user.role == role).toList();

    return ListView.builder(
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(filteredUsers[index].username),
          subtitle: Text(filteredUsers[index].email),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _deleteUser(filteredUsers[index].id);
            },
          ),
        );
      },
    );
  }

  void _addUser() {
    // Logika untuk menambah pengguna baru
    setState(() {
      users.add(User(
          id: users.length + 1,
          username: "New User",
          email: "newuser@gmail.com",
          role: "ROLE_USER")); // Default role
    });
  }

  void _deleteUser(int id) {
    setState(() {
      users.removeWhere((user) => user.id == id);
    });
  }
}

class User {
  final int id;
  final String username;
  final String email;
  final String role; // Tambahkan field role

  User(
      {required this.id,
      required this.username,
      required this.email,
      required this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    String role = json['roles'].isNotEmpty
        ? json['roles'][0][' name']
        : 'Unknown'; // Ambil role pertama
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      role: role, // Ambil role dari JSON
    );
  }
}
