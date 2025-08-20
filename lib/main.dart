import 'package:flutter/material.dart';
import 'package:flutterreader/Screens/main_shell.dart';

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
      home: const MainShell(),
      //home: const ManhwaLoginScreen(),  
      debugShowCheckedModeBanner: false,
    );
  }
}