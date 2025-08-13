import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_choice_page.dart';
import 'email_login_page.dart';
import 'home_page.dart';
import 'sell_service_page.dart';
import 'create_account_page.dart';

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
      // Show LoginChoicePage first
      initialRoute: '/',
      routes: {
        '/': (context) {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            // Not logged in → show login choice
            return const LoginChoicePage();
          } else {
            // Logged in → go to home
            return const HomePage();
          }
        },
        '/login-email': (context) => const EmailLoginPage(),
        '/create-account': (context) => const CreateAccountPage(),
        '/home': (context) => const HomePage(),
        '/sell-service': (context) => const SellServicePage(),
      },
    );
  }
}
