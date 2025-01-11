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

  Future<void> _editItem(int id, String judul, String deskripsi) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    // Membuat header dengan token akses
    Map<String, String> headers = {
      'Authorization': 'Bearer $accessToken', // Menggunakan Bearer token
      'Content-Type': 'application/json', // Menentukan tipe konten
    };

    final response = await http.put(
      Uri.parse('http://localhost:8080/informasiHakHukum/$id'),
      headers: headers,
      body: json.encode({
        'judul': judul,
        'deskripsi': deskripsi,
      }),
    );

    if (response.statusCode == 200) {
      // Jika berhasil, ambil data lagi
      await _fetchData(); // Pastikan untuk menunggu fetch data
    } else {
      throw Exception('Failed to edit item');
    }
  }

  void _showEditDialog(int id, String currentJudul, String currentDeskripsi) {
    String judul = currentJudul;
    String deskripsi = currentDeskripsi;

    // Menggunakan TextEditingController untuk mengisi nilai awal
    TextEditingController judulController =
        TextEditingController(text: currentJudul);
    TextEditingController deskripsiController =
        TextEditingController(text: currentDeskripsi);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Informasi Hak Hukum'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: judulController,
                onChanged: (value) {
                  judul = value;
                },
                decoration: const InputDecoration(labelText: 'Judul'),
              ),
              TextField(
                controller: deskripsiController,
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
                try {
                  await _editItem(id, judul, deskripsi);
                  Navigator.of(context).pop();
                } catch (e) {
                  // Tampilkan pesan kesalahan jika ada
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal mengedit item: $e')),
                  );
                }
              },
              child: const Text('Simpan'),
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

  void _showDetail(int id) {
    // Tampilkan detail item (misalnya dengan dialog)
    showDialog(
      context: context,
      builder: (context) {
        // Anda bisa menambahkan logika untuk mengambil detail item berdasarkan ID
        // Misalnya, Anda bisa menampilkan detail dari _data yang sudah diambil
        final item = _data.firstWhere((element) => element['id'] == id);
        return AlertDialog(
          title: Text('Detail Item ID: $id'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Judul: ${item['judul']}'),
              Text('Deskripsi: ${item['deskripsi']}'),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0D187E),
        title: const Text(
          'Informasi Hak dan Hukum',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add,
              color: Colors.white,
            ),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _data.isEmpty
              ? const Center(child: Text('Tidak ada data.'))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Judul')),
                            DataColumn(label: Text('Deskripsi')),
                            DataColumn(label: Text('Aksi')),
                          ],
                          rows: _data.map((item) {
                            return DataRow(cells: [
                              DataCell(Text(item['judul'])),
                              DataCell(Text(item['deskripsi'])),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        _showEditDialog(
                                          item['id'],
                                          item['judul'],
                                          item['deskripsi'],
                                        );
                                      },
                                    ),
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
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
