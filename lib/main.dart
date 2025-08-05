import 'package:flutter/material.dart';
import 'Screens/login_screen.dart';  // Import your login screen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manhwa Reader',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const ManhwaLoginScreen(),  // Use your login screen as home
      debugShowCheckedModeBanner: false,
    );
  }
}