import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:device_preview/device_preview.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    DevicePreview(
      enabled: true, // aktifkan mode preview
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true, // penting agar DevicePreview berfungsi
      debugShowCheckedModeBanner: false,
      locale: DevicePreview.locale(context), // ambil locale dari DevicePreview
      builder: DevicePreview.appBuilder, // gunakan builder dari DevicePreview
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}
