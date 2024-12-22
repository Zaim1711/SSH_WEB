import 'dart:core';

import 'package:flutter/material.dart';
import 'package:ssh_web/Model/Role.dart';
import 'package:ssh_web/Model/users.dart';
import 'package:ssh_web/View/ReviewUser.dart';

class ManageUserPage extends StatefulWidget {
  const ManageUserPage({super.key});

  @override
  State<ManageUserPage> createState() => _ManageUserPageState();
}

class _ManageUserPageState extends State<ManageUserPage>
    with SingleTickerProviderStateMixin {
  late Future<List<Users>> _fetchUser;
  late TabController _tabController;
  List<Users> users = [];

  @override
  void initState() {
    super.initState();
    _fetchUser = fetchUsers();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D187E),
        title: const Text('Manage User',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'User  '),
            Tab(icon: Icon(Icons.person_2), text: 'Admin'),
            Tab(icon: Icon(Icons.person_3), text: 'Konsultan'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addUser,
          ),
        ],
      ),
      body: FutureBuilder<List<Users>>(
        future: _fetchUser,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Tidak ada Users'));
          } else {
            final userList = snapshot.data!;
            return TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(userList, 'ROLE_USER'),
                _buildUserList(userList, 'ROLE_ADMIN'),
                _buildUserList(userList, 'ROLE_KONSULTAN'),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildUserList(List<Users> userList, String role) {
    final filteredUsers = userList
        .where((user) => user.roles.any((r) => r.name == role))
        .toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 8,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: DataTable(
              columns: const [
                DataColumn(
                    label: Text('ID',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Nama',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Email',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Role',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(
                    label: Text('Review',
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: filteredUsers.map((user) {
                return DataRow(cells: [
                  DataCell(Text(user.id.toString())),
                  DataCell(Text(user.username)),
                  DataCell(Text(user.email)),
                  DataCell(Text(user.roles.map((r) => r.name).join(', '))),
                  DataCell(
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D187E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        elevation: 5,
                        shadowColor: Colors.tealAccent.withOpacity(0.5),
                        side: const BorderSide(
                          color: Color(0xFF0D187E),
                          width: 1.5,
                        ),
                      ),
                      onPressed: () {
                        _onReviewButtonPressed(
                            user); // Menggunakan objek user langsung
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rate_review, size: 18),
                          SizedBox(width: 8),
                          Text('Review'),
                        ],
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _addUser() {
    setState(() {
      List<Role> defaultRoles = [
        Role(id: 1, name: "ROLE_USER"),
      ];

      users.add(Users(
        id: users.length + 1,
        username: "New User ${users.length + 1}",
        email: "newuser${users.length + 1}@gmail.com",
        roles: defaultRoles,
        idRoles: defaultRoles,
      ));
    });
  }

  void _deleteUser(int id) {
    setState(() {
      users.removeWhere((user) => user.id == id);
    });
  }

  void _onReviewButtonPressed(Users user) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.5,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Review Pengaduan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ReviewUser(
                      users: user), // Menggunakan objek user yang dipilih
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Tutup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then(
      (_) {
        setState(() {
          _fetchUser = fetchUsers();
        });
      },
    );
  }
}
