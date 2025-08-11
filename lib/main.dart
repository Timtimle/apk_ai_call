import 'package:flutter/material.dart';
import 'call.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp (
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

