import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'login_choice_page.dart';
import 'email_login_page.dart';
import 'phone_login_page.dart';
import 'create_account_page.dart';
import 'home_page.dart';
import 'sell_service_page.dart'; // <-- import the new page

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
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginChoicePage(),
        '/login-email': (context) => const EmailLoginPage(),
        '/login-phone': (context) => const PhoneLoginPage(),
        '/create-account': (context) => const CreateAccountPage(),
        '/home': (context) => const HomePage(),
        '/sell-service': (context) =>
            const SellServicePage(), // <-- add route here
      },
    );
  }
}
