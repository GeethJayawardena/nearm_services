import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginChoicePage extends StatelessWidget {
  const LoginChoicePage({super.key});

  // Future<void> _continueAsGuest(BuildContext context) async {
  //   try {
  //     await FirebaseAuth.instance.signInAnonymously();
  //     Navigator.pushReplacementNamed(context, '/home');
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to sign in as guest: $e')),
  //     );
  //   }
  // }
  Future<void> _continueAsGuest(BuildContext context) async {
    try {
      print("🔄 Attempting anonymous sign-in...");
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      print("✅ Signed in as guest: ${userCredential.user?.uid}");
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e, stack) {
      print("❌ Guest sign-in error: $e");
      print(stack);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to sign in as guest: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to NearMe Services')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login-email');
              },
              child: const Text('Login with Email'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login-phone');
              },
              child: const Text('Login with Phone'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _continueAsGuest(context),
              child: const Text('Continue as Guest'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/create-account');
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
