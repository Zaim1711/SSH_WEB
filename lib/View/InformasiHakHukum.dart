import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InformasiHakHukum extends StatefulWidget {
  const InformasiHakHukum({super.key});

  @override
  State<InformasiHakHukum> createState() => _InformasiHakHukumState();
}

class _InformasiHakHukumState extends State<InformasiHakHukum> {
  List<dynamic> _data = [];
  bool _isLoading = true;
  Map<String, dynamic> payload = {};
  String userId = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
    decodeToken();
  }

  Future<void> decodeToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken != null) {
      payload = JwtDecoder.decode(accessToken);
      String id = payload['sub'].split(',')[0];
      setState(() {
        userId = id;
        print(userId);
      });
    }
  }

  Future<void> _fetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    // Membuat header dengan token akses
    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken', // Menggunakan Bearer token
    };

    final response = await http.get(
      Uri.parse('http://localhost:8080/informasiHakHukum'),
      headers: headers, // Menambahkan header ke permintaan
    );

    if (response.statusCode == 200) {
      setState(() {
        _data = json.decode(response.body);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false; // Set loading ke false jika gagal
      });
      throw Exception('Failed to load data');
    }
  }

  Future<void> _deleteItem(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    // Membuat header dengan token akses
    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken', // Menggunakan Bearer token
    };

    final response = await http.delete(
      Uri.parse('http://localhost:8080/informasiHakHukum/$id'),
      headers: headers,
    );

    if (response.statusCode == 204) {
      // Jika berhasil, ambil data lagi
      await _fetchData(); // Pastikan untuk menunggu fetch data
    } else {
      throw Exception('Failed to delete item');
    }
  }

  Future<void> _createItem(String judul, String deskripsi) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    // Membuat header dengan token akses
    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken', // Menggunakan Bearer token
      'Content-Type': 'application/json', // Menentukan tipe konten
    };

    final response = await http.post(
      Uri.parse('http://localhost:8080/informasiHakHukum'),
      headers: headers,
      body: json.encode({
        'judul': judul,
        'deskripsi': deskripsi,
      }),
    );

    if (response.statusCode == 201) {
      // Jika berhasil, ambil data lagi
      await _fetchData(); // Pastikan untuk menunggu fetch data
    } else {
      throw Exception('Failed to create item');
    }
  }

  void _showDetail(int id) {
    // Tampilkan detail item (misalnya dengan dialog)
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detail Item ID: $id'),
          content: Text('Tampilkan detail untuk item dengan ID: $id'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateDialog() {
    String judul = '';
    String deskripsi = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Informasi Hak Hukum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) {
                  judul = value;
                },
                decoration: const InputDecoration(labelText: 'Judul'),
              ),
              TextField(
                onChanged: (value) {
                  deskripsi = value;
                },
                decoration: const InputDecoration(labelText: 'Deskripsi'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                await _createItem(judul, deskripsi);
                Navigator.of(context).pop();
              },
              child: const Text('Simpan'),
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
        backgroundColor:
            Color(0xFF0D187E), // Ubah warna AppBar agar lebih menarik
        title: const Text('Informasi Hak dan Hukum',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? const Center(child: Text('Tidak ada data.'))
              : ListView.builder(
                  itemCount: _data.length,
                  itemBuilder: (context, index) {
                    final item = _data[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(item['judul']),
                        subtitle: Text(item['deskripsi']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                await _deleteItem(item['id']);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.info),
                              onPressed: () {
                                _showDetail(item['id']);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
