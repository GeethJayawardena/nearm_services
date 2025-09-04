import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ Correct imports (no duplicates)
import 'login_choice_page.dart';
import 'email_login_page.dart'; // EmailLoginPage
import 'create_account_page.dart'; // CreateAccountPage
import 'home_page.dart';
import 'sell_service_page.dart';
import 'admin_dashboard.dart';

// Global RouteObserver for page refresh
final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

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
      home: const LandingPage(),
      navigatorObservers: [routeObserver],
      routes: {
        '/login-choice': (context) => const LoginChoicePage(),
        '/login-email': (context) => EmailLoginPage(), // removed const
        '/create-account': (context) => const CreateAccountPage(),
        '/home': (context) => const HomePage(),
        '/sell-service': (context) => const SellServicePage(),
        '/admin-dashboard': (context) => const AdminDashboard(),
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  Future<Widget> _getPage(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final role = doc.data()?['role'] ?? 'user';

    if (role == 'admin') return const AdminDashboard();
    return const HomePage();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          // Not logged in
          return const LoginChoicePage();
        }

        // Logged in → check role from Firestore
        return FutureBuilder<Widget>(
          future: _getPage(user),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            } else if (roleSnapshot.hasError) {
              return Scaffold(
                body: Center(child: Text("Error: ${roleSnapshot.error}")),
              );
            } else {
              return roleSnapshot.data!;
            }
          },
        );
      },
    );
  }
}
