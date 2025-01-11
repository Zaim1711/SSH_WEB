import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/users.dart';

class ReviewUser extends StatefulWidget {
  final Users users;
  const ReviewUser({super.key, required this.users});

  @override
  State<ReviewUser> createState() => _ReviewUserState();
}

class _ReviewUserState extends State<ReviewUser> {
  late String selectedRoles;
  bool _isLoading = false;
  final Map<String, int> roleIdMap = {
    'ROLE_USER': 1,
    'ROLE_ADMIN': 2,
    'ROLE_KONSULTAN': 3,
  };

  @override
  void initState() {
    super.initState();
    // Menginisialisasi selectedRoles dengan peran pertama dari pengguna
    selectedRoles =
        widget.users.roles.isNotEmpty ? widget.users.roles.first.name : '';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              minWidth: 150.0,
              maxWidth: 920.0,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blueAccent.withOpacity(0.7),
                  Colors.blue.withOpacity(0.6)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.report, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Review User: ${widget.users.username}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow('No:', widget.users.id.toString()),
                  _buildInfoRow('Nama:', widget.users.username),
                  _buildInfoRow('Email:', widget.users.email),
                  _buildInfoRow('IdRole:',
                      widget.users.roles.map((r) => r.id).join(', ')),
                  _buildInfoRow('Role:',
                      widget.users.roles.map((r) => r.name).join(', ')),
                  const SizedBox(height: 20),
                  const Text(
                    'Pilih Update Role:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  DropdownButton<String>(
                    value: selectedRoles,
                    onChanged: (String? newStatus) {
                      if (newStatus != null) {
                        setState(() {
                          selectedRoles = newStatus;
                        });
                      }
                    },
                    items: roleIdMap.keys
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                    dropdownColor: Colors.grey,
                    elevation: 10,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                });

                                int selectedRoleId =
                                    roleIdMap[selectedRoles] ?? 0;

                                bool success = await updateUserRole(
                                    widget.users.id, selectedRoleId.toString());

                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Status berhasil diperbarui menjadi $selectedRoles'),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Gagal memperbarui status'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }

                                setState(() {
                                  _isLoading = false;
                                });

                                Navigator.of(context).pop();
                              },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 25, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Update Status'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            '$label',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> updateUserRole(int id, String selectedRoleId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken != null) {
      try {
        final response = await http.put(
          Uri.parse(
              'http://localhost:8080/users/$id/roles?oldRoleId=${widget.users.roles.map((r) => r.id).join(', ')}&newRoleId=$selectedRoleId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: json.encode({
            'status': selectedRoleId,
          }),
        );

        if (response.statusCode == 200) {
          print('Status berhasil diperbarui menjadi $selectedRoleId');
          return true;
        } else {
          print('Gagal memperbarui status: ${response.statusCode}');
          return false;
        }
      } catch (e) {
        print('Error: $e');
        return false;
      }
    } else {
      print('Token akses tidak ditemukan');
      return false;
    }
  }
}
