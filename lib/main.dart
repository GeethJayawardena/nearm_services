import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_choice_page.dart';
import 'email_login_page.dart';
import 'home_page.dart';
import 'sell_service_page.dart';
import 'create_account_page.dart';
import 'admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getInitialPage() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Not logged in → show login choice
      return const LoginChoicePage();
    } else {
      // Logged in → check role
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = doc.data()?['role'] ?? 'user';

      if (role == 'admin') {
        return const AdminDashboard();
      } else {
        return const HomePage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NearMe Services',
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Widget>(
        future: _getInitialPage(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text("Error: ${snapshot.error}")),
            );
          } else {
            return snapshot.data ?? const LoginChoicePage();
          }
        },
      ),
      routes: {
        '/login-email': (context) => const EmailLoginPage(),
        '/create-account': (context) => const CreateAccountPage(),
        '/home': (context) => const HomePage(),
        '/sell-service': (context) => const SellServicePage(),
        '/admin-dashboard': (context) => const AdminDashboard(),
      },
    );
  }
}
