import 'package:flutter/material.dart';
import '../features/camera/camera_screen.dart';
import 'theme.dart';

class BeautyCameraApp extends StatelessWidget {
  const BeautyCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beauty Camera',
      debugShowCheckedModeBanner: false,
      theme: BeautyAppTheme.darkTheme,
      home: const CameraScreen(),
    );
  }
}
