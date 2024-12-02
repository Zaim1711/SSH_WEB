import 'package:flutter/material.dart';

class MyTextFieldPass extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? Function(String?)? validator; // Validator tambahan
  final void Function(String)? onChanged; // Fungsi onChanged tambahan

  const MyTextFieldPass({
    Key? key,
    required this.controller,
    required this.hintText,
    this.validator, // Tambahkan validator ke konstruktor
    this.onChanged, // Tambahkan onChanged ke konstruktor
  }) : super(key: key);

  @override
  _MyTextFieldState createState() => _MyTextFieldState();
}

class _MyTextFieldState extends State<MyTextFieldPass> {
  bool _isObscure = true; // Variabel untuk mengontrol visibilitas password

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: TextFormField(
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0xFFF4F4F4),
          ),
          controller: widget.controller,
          obscureText: _isObscure, // Menggunakan _isObscure untuk visibilitas
          onChanged: widget.onChanged, // Menggunakan onChanged yang diberikan
          validator: widget.validator, // Menggunakan validator yang diberikan
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            contentPadding: EdgeInsets.all(10.0),
            enabledBorder: OutlineInputBorder(),
            fillColor: Color(0xFFF4F4F4),
            filled: true,
            hintText: widget.hintText,
            suffixIcon: IconButton(
              icon: Icon(
                _isObscure
                    ? Icons.visibility
                    : Icons.visibility_off, // Ikon mata
              ),
              onPressed: () {
                setState(() {
                  _isObscure = !_isObscure; // Toggle visibilitas
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
