import 'package:flutter/material.dart';

import 'screens/home/home_shell.dart';

class WithFamApp extends StatelessWidget {
  const WithFamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WithFam Maps',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}
