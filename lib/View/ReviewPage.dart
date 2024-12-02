import 'dart:convert';

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
  late String selectedStatus;
  bool _isLoading = false; // Indikator loading
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Inisialisasi status dengan status pengaduan yang ada
    selectedStatus = widget.pengaduan.status.toString().split('.').last;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Material(
        color: Colors.transparent,
        child: Container(
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan judul yang lebih besar dan ikon
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

                // Info pengaduan dengan desain baru
                _buildInfoRow('Nama Pelapor:', widget.pengaduan.name),
                _buildInfoRow('Nik Pelapor:', widget.pengaduan.nik_user),
                _buildInfoRow('Jenis Kelamin:', widget.pengaduan.jenisKelamin),
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

                SizedBox(height: 20),

                // Pilihan Status menggunakan DropdownButton yang lebih stylish
                Text(
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
                        selectedStatus =
                            newStatus; // Memperbarui status yang dipilih
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

                // Tombol untuk menyimpan perubahan status dengan desain modern dan animasi
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              // Menambahkan indikator loading
                              setState(() {
                                _isLoading = true;
                              });

                              // Update status pengaduan dengan status yang dipilih
                              bool success = await updatePengaduanStatus(
                                  widget.pengaduan.id, selectedStatus);

                              if (success) {
                                // Kirim notifikasi ke pengguna setelah status berhasil diperbarui
                                await _notificationService.sendNotification(
                                  widget.pengaduan
                                      .userId, // ID pengguna yang akan menerima notifikasi
                                  'Laporan Anda $selectedStatus', // Judul notifikasi
                                  'Status pengaduan ${widget.pengaduan.jenisKekerasan} Anda telah diperbarui menjadi $selectedStatus.', // Isi notifikasi
                                  // ID chat room atau pengaduan
                                );

                                // Menampilkan pesan berhasil
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Status berhasil diperbarui menjadi $selectedStatus'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } else {
                                // Menampilkan pesan gagal
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal memperbarui status'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }

                              // Menghentikan indikator loading
                              setState(() {
                                _isLoading = false;
                              });

                              Navigator.of(context).pop(); // Menutup dialog
                            },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blueAccent,
                        padding:
                            EdgeInsets.symmetric(horizontal: 25, vertical: 12),
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
    );
  }

// Membuat row untuk informasi dengan desain baru
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

  // Fungsi untuk memperbarui status pengaduan
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
