import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ssh_web/Model/user.dart';
import 'package:ssh_web/View/AdminPanel.dart';
import 'package:ssh_web/component/My_TextField.dart';
import 'package:ssh_web/component/my_button.dart';
import 'package:ssh_web/component/password_TextField.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  User user = User("", "");
  String url =
      "http://localhost:8080/auth/login"; // Ganti dengan URL backend Anda
  final FocusNode _focusNode = FocusNode();

  Future<void> save(BuildContext context) async {
    if (user.email.isEmpty) {
      _showErrorDialog(context, 'Email tidak boleh kosong.');
      return; // Hentikan eksekusi jika email kosong
    }

    if (user.password.isEmpty) {
      _showErrorDialog(context, 'Password tidak boleh kosong.');
      return; // Hentikan eksekusi jika password kosong
    }

    final uri = Uri.parse(url);
    final Map<String, dynamic> requestData = {
      'email': user.email,
      'password': user.password,
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(requestData),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final accessToken = responseData['accesToken'];

      if (accessToken != null && accessToken is String) {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(accessToken);
        print('Token payload: $decodedToken');

        final prefs = await SharedPreferences.getInstance();
        prefs.setString('accesToken', accessToken);

        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (context) => AdminPanel()),
        );
      } else {
        _showErrorDialog(
            context, 'Format token tidak valid. Silakan coba lagi.');
      }
    } else {
      String errorMessage;
      switch (response.statusCode) {
        case 400:
          errorMessage =
              'Permintaan tidak valid. Periksa email dan kata sandi Anda.';
          break;
        case 401:
          errorMessage = 'Email atau kata sandi salah.';
          break;
        case 500:
          errorMessage =
              'Terjadi kesalahan di server. Silakan coba lagi nanti.';
          break;
        default:
          errorMessage = 'Gagal mengirim data: ${response.statusCode}';
      }
      print(errorMessage);
      _showErrorDialog(context, errorMessage);
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kesalahan'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      // const CircleAvatar(
                      //   radius: 50,
                      //   backgroundImage: AssetImage('assets/logo.png'),
                      // ),
                      const SizedBox(height: 20),

                      // Judul Halaman
                      const Text(
                        'Selamat Datang!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 10),

                      const Text(
                        'Masuk untuk melanjutkan',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 30),

                      // Input Email
                      MyTextField(
                        controller: TextEditingController(text: user.email),
                        onChanged: (val) {
                          user.email = val;
                        },
                        hintText: 'Masukkan Email Anda',
                        obsecureText: false,
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Alamat Email harus diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Input Password
                      MyTextFieldPass(
                        controller: TextEditingController(text: user.password),
                        onChanged: (val) {
                          user.password = val;
                        },
                        hintText: 'Masukkan Kata Sandi Anda',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Silakan masukkan kata sandi!';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Tombol Lupa Kata Sandi
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // Aksi lupa kata sandi
                          },
                          child: const Text(
                            'Lupa Kata Sandi?',
                            style: TextStyle(color: Colors.blueAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tombol Login
                      MyButton(
                        focusNode: _focusNode,
                        onTap: () {
                          save(context);
                        },
                      ),

                      const SizedBox(height: 20),

                      // Teks Daftar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Belum punya akun?'),
                          TextButton(
                            onPressed: () {
                              // Aksi daftar
                            },
                            child: const Text(
                              'Daftar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
