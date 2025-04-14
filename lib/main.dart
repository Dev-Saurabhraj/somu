import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'sensor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MPU6050 Monitor',
      theme: ThemeData(primarySwatch: Colors.green),
      home: SensorScreen(),
    );
  }
}
