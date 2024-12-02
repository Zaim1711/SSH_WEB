import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obsecureText;
  final String? Function(String?)? validator; // Validator tambahan
  final void Function(String)? onChanged; // Fungsi onChanged tambahan

  const MyTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.obsecureText,
    this.validator, // Tambahkan validator ke konstruktor
    this.onChanged, // Tambahkan onChanged ke konstruktor
  }) : super(key: key);

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
          // Ganti dengan TextFormField
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0xFFF4F4F4),
          ),
          controller: controller,
          obscureText: obsecureText,
          onChanged: onChanged, // Gunakan onChanged yang diberikan
          validator: validator, // Gunakan validator yang diberikan
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            contentPadding: EdgeInsets.all(10.0),
            enabledBorder: OutlineInputBorder(),
            fillColor: Color(0xFFF4F4F4),
            filled: true,
            hintText: hintText,
          ),
        ),
      ),
    );
  }
}
