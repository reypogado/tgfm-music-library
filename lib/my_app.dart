import 'package:flutter/material.dart';
import 'package:tgfm_music_library/screens/splash_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TGFM Music Library',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.brown),
      home: const SplashScreen(),
    );
  }
}
