import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/Pengaduan.dart';
import 'package:ssh_web/Service/NotificatioonService.dart';

class ReviewPage extends StatefulWidget {
  final Pengaduan pengaduan;

  ReviewPage({required this.pengaduan});

  @override
  _ReviewPageState createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  Uint8List? _imageBytes;
  late String selectedStatus;
  bool _isLoading = false;
  bool _showImage = false; // Flag untuk mengontrol tampilan gambar
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.pengaduan.status.toString().split('.').last;
  }

  Future<Uint8List?> fetchImage(String imageName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');
    if (accessToken == null) {
      print('Access token tidak ditemukan');
      return null;
    }

    final imageUrl = 'http://localhost:8080/pengaduan/image/$imageName';
    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        print('Gagal mengambil gambar: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Terjadi kesalahan saat mengambil gambar: $e');
      return null;
    }
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
                      Icon(Icons.report, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Review Pengaduan: ${widget.pengaduan.jenisKekerasan}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  _buildInfoRow('Nama Pelapor:', widget.pengaduan.name),
                  _buildInfoRow('Nik Pelapor:', widget.pengaduan.nik_user),
                  _buildInfoRow(
                      'Jenis Kelamin:', widget.pengaduan.jenisKelamin),
                  _buildInfoRow('Pekerjaan:', widget.pengaduan.pekerjaan),
                  _buildInfoRow(
                      'Status Pelapor:', widget.pengaduan.status_pelapor),
                  _buildInfoRow('Tempat Lahir:', widget.pengaduan.tempat_lahir),
                  _buildInfoRow(
                      'Jenis Kekerasan:', widget.pengaduan.jenisKekerasan),
                  _buildInfoRow(
                      'Deskripsi:', widget.pengaduan.deskripsiKekerasan),
                  _buildInfoRow(
                      'Tanggal Lahir:', widget.pengaduan.tanggalKekerasan),
                  _buildInfoRow(
                      'Tanggal Laporan:', widget.pengaduan.tanggalKekerasan),
                  const SizedBox(height: 20),

                  // Tombol untuk melihat bukti kekerasan
                  ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        _showImage = !_showImage; // Toggle tampilan gambar
                      });
                    },
                    child: Text(_showImage
                        ? 'Sembunyikan Bukti'
                        : 'Lihat Bukti Kekerasan'),
                  ),

                  // Menampilkan gambar jika tombol ditekan
                  if (_showImage)
                    FutureBuilder<Uint8List?>(
                      future: fetchImage(widget.pengaduan.buktiKekerasan),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError || snapshot.data == null) {
                          return Center(child: Text('Gambar tidak tersedia'));
                        } else {
                          return Center(
                            child: Image.memory(
                              snapshot.data!,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                      },
                    ),

                  // Pilihan Status menggunakan DropdownButton
                  const Text(
                    'Pilih Status Pengaduan:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  DropdownButton<String>(
                    value: selectedStatus,
                    onChanged: (String? newStatus) {
                      if (newStatus != null) {
                        setState(() {
                          selectedStatus = newStatus;
                        });
                      }
                    },
                    items: ['Validation', 'Approved', 'Rejected']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                    dropdownColor: Colors.grey,
                    elevation: 10,
                    style: TextStyle(color: Colors.black),
                  ),

                  SizedBox(height: 20),

                  // Tombol untuk memperbarui status
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

                                bool success = await updatePengaduanStatus(
                                    widget.pengaduan.id, selectedStatus);

                                if (success) {
                                  await _notificationService.sendNotification(
                                    widget.pengaduan.userId,
                                    'Laporan Anda $selectedStatus',
                                    'Status pengaduan ${widget.pengaduan.jenisKekerasan} Anda telah diperbarui menjadi $selectedStatus.',
                                  );

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Status berhasil diperbarui menjadi $selectedStatus'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
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
                          padding: EdgeInsets.symmetric(
                              horizontal: 25, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Update Status'),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
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

  Future<bool> updatePengaduanStatus(int id, String status) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accesToken');

    if (accessToken != null) {
      try {
        final response = await http.put(
          Uri.parse('http://localhost:8080/pengaduan/$id/status'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: json.encode({
            'status': status,
          }),
        );

        if (response.statusCode == 200) {
          print('Status berhasil diperbarui menjadi $status');
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
