import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum Status { Validation, Approved, Rejected, Done }

class Pengaduan {
  final int id;
  final String name;
  final String jenisKelamin;
  final String pekerjaan;
  final String nik_user;
  final String status_pelapor;
  final String tempat_lahir;
  final String jenisKekerasan;
  final String deskripsiKekerasan;
  final Status status;
  final String tanggalKekerasan;
  final String buktiKekerasan;
  final String userId;

  Pengaduan({
    required this.id,
    required this.name,
    required this.jenisKelamin,
    required this.pekerjaan,
    required this.nik_user,
    required this.status_pelapor,
    required this.tempat_lahir,
    required this.jenisKekerasan,
    required this.deskripsiKekerasan,
    required this.status,
    required this.tanggalKekerasan,
    required this.buktiKekerasan,
    required this.userId,
  });

  factory Pengaduan.fromJson(Map<String, dynamic> json) {
    return Pengaduan(
      id: json['id'] ?? 0, // Pastikan ID ada dan aman
      name: json['name'] ?? '',
      jenisKelamin: json['jenis_kelamin'] ?? '',
      pekerjaan: json['pekerjaan'] ?? '',
      nik_user: json['nik_user']?.toString() ?? '',
      status_pelapor: json['status_pelapor'] ?? '',
      tempat_lahir: json['tempat_lahir'] ?? '',
      jenisKekerasan: json['jenis_kekerasan'] ?? '',
      deskripsiKekerasan: json['deskripsi_kekerasan'] ?? '',
      status: Status.values
          .firstWhere((e) => e.toString() == 'Status.' + json['status']),
      tanggalKekerasan: json['tanggal_kekerasan'] ?? '',
      buktiKekerasan: json['bukti_kekerasan'] ?? '',
      userId: json['userId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'jenis_kelamin': jenisKelamin,
      'pekerjaan': pekerjaan,
      'nik_user': nik_user,
      'status_pelapor': status_pelapor,
      'tempat_lahir': tempat_lahir,
      'jenis_kekerasan': jenisKekerasan,
      'deskripsi_kekerasan': deskripsiKekerasan,
      'status': status.toString().split('.').last,
      'tanggal_kekerasan': tanggalKekerasan,
      'bukti_kekerasan': buktiKekerasan,
      'user_id': userId,
    };
  }
}

Future<List<Pengaduan>> fetchPengaduan() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('accesToken');
  print('Access Token: $accessToken'); // Debug token

  if (accessToken != null) {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/pengaduan'),
        headers: {
          'Content-Type': 'application/json', // Tambahkan header Content-Type
          'Authorization':
              'Bearer $accessToken', // Menambahkan Authorization header
        },
      );

      print('Response Status: ${response.statusCode}'); // Debug status code
      print('Response Body: ${response.body}'); // Debug response body

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((item) => Pengaduan.fromJson(item)).toList();
      } else {
        print('Gagal mengambil data laporan : ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Terjadi error: $e');
      return [];
    }
  } else {
    print('Token akses tidak ditemukan');
    return [];
  }
}

Future<Pengaduan?> fetchPengaduanWithUser(int pengaduanId) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('accesToken');
  print('Access Token: $accessToken'); // Debug token

  if (accessToken != null) {
    try {
      final response = await http.get(
        Uri.parse(
            'http://localhost:8080/pengaduan/$pengaduanId'), // Endpoint untuk mengambil detail pengaduan
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      print('Response Status: ${response.statusCode}'); // Debug status code
      print('Response Body: ${response.body}'); // Debug response body

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        return Pengaduan.fromJson(
            data); // Mengonversi data menjadi objek Pengaduan
      } else {
        print('Gagal mengambil data laporan: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Terjadi error: $e');
      return null;
    }
  } else {
    print('Token akses tidak ditemukan');
    return null;
  }
}
