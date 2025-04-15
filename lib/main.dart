import 'package:flutter/material.dart';

import 'package:somu/sensor_screen.dart';
void main() {
  runApp(const HealthMonitorApp());
}


class HealthMonitorApp extends StatelessWidget {
  const HealthMonitorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFF7A00),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7A00),
          secondary: const Color(0xFFFF9A3D),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        fontFamily: 'Poppins',
      ),
      home: const HomeScreen(),
    );
  }
}
