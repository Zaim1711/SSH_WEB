import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ssh_web/View/LoginPage.dart';
import 'package:ssh_web/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Menginisialisasi Firebase untuk platform yang tepat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginPage(),
    );
  }
}
