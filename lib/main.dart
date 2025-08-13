import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'sell_service_page.dart';
import 'email_login_page.dart';
import 'service_details_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NearMe Services',
      debugShowCheckedModeBanner: false,
      initialRoute: FirebaseAuth.instance.currentUser == null
          ? '/login'
          : '/home',
      routes: {
        '/login': (context) => const EmailLoginPage(),
        '/home': (context) => const HomePage(),
        '/sell-service': (context) => const SellServicePage(),
      },
    );
  }
}
