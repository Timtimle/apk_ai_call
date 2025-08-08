import 'package:flutter/material.dart';
import 'call.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title : Text('Bao'),
      ),
      body: Center(
        child: ElevatedButton (
          child: Text('Open Camera'),
          onPressed: () {
            Navigator.push (
              context,
              MaterialPageRoute(builder: (context) => CallPage()),
            );
          },
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget  {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bao',
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

void main() {
  runApp(MyApp());
}

