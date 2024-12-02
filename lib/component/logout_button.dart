import 'package:flutter/material.dart';

class MyButtonLogout extends StatelessWidget {
  final Function()? onTap;
  const MyButtonLogout({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(25),
        margin: const EdgeInsets.symmetric(horizontal: 25),
        decoration: BoxDecoration(
          color: Color(0xFF0D187E),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2), // Shadow color
              spreadRadius: 2, // How much the shadow spreads
              blurRadius: 5, // How blurry the shadow is
              offset:
                  Offset(0, 3), // Offset in (x,y) to control shadow position
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Log Out',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
