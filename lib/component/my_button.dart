import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for RawKeyboardListener

class MyButton extends StatelessWidget {
  final VoidCallback? onTap; // Use VoidCallback for better type safety
  final FocusNode focusNode;

  const MyButton({
    Key? key,
    required this.focusNode,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKey: (FocusNode node, RawKeyEvent event) {
        // Check if the event is a key down event and the key is Enter
        if (event is RawKeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          onTap?.call(); // Call the onTap function
          return KeyEventResult
              .handled; // Indicate that the event has been handled
        }
        return KeyEventResult
            .ignored; // Indicate that the event has not been handled
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(25),
          margin: const EdgeInsets.symmetric(horizontal: 25),
          decoration: BoxDecoration(
            color: const Color(0xFF0D187E),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Sign In',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
