import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _generatedOtp;
  String _selectedCountryCode = '+94';
  String? _userPhone;

  final List<String> _countryCodes = ['+94', '+91', '+44', '+1', '+61'];

  OverlayEntry? _otpOverlay; // overlay for top notification

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _generateOtp() {
    final rnd = Random();
    return (100000 + rnd.nextInt(900000)).toString();
  }

  void _showOtpNotification(String otp) {
    _otpOverlay?.remove(); // remove previous overlay if any

    _otpOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Colors.blue[800],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.sms, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Your OTP is: $otp",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _otpOverlay?.remove();
                    _otpOverlay = null;
                  },
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)?.insert(_otpOverlay!);

    // Auto remove after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _otpOverlay?.remove();
      _otpOverlay = null;
    });
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final enteredPhone = '$_selectedCountryCode${_phoneController.text.trim()}';

    setState(() => _isLoading = true);

    try {
      UserCredential cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // Fetch user from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();

      if (doc.exists && doc.data()?['phone'] != null) {
        final savedPhone = doc.data()?['phone'];

        if (savedPhone != enteredPhone) {
          _showMessage("⚠️ Phone number does not match our records.");
          await FirebaseAuth.instance.signOut();
          setState(() {
            _otpSent = false;
          });
          return;
        }

        // Phone matches → generate OTP
        _userPhone = savedPhone;
        _generatedOtp = _generateOtp();
        setState(() => _otpSent = true);
        _showOtpNotification(_generatedOtp!);
      } else {
        _showMessage("⚠️ No phone number saved. Please create account first.");
        await FirebaseAuth.instance.signOut();
        setState(() {
          _otpSent = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') message = 'No user found for that email.';
      if (e.code == 'wrong-password') message = 'Wrong password provided.';
      _showMessage(message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _verifyOtp() async {
    if (_otpController.text.trim() == _generatedOtp) {
      _showMessage("✅ Login successful!");
      Navigator.pushReplacementNamed(context, '/');
    } else {
      _showMessage("❌ Invalid OTP. Logging out.");
      await FirebaseAuth.instance.signOut();
      setState(() {
        _otpSent = false;
        _otpController.clear();
      });
    }
  }

  void _resendOtp() {
    _generatedOtp = _generateOtp();
    _showOtpNotification(_generatedOtp!);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _otpOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Email + Phone Login")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter email' : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Enter password' : null,
                    ),
                    const SizedBox(height: 16),

                    // Phone + country code (only before OTP sent)
                    if (!_otpSent)
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCountryCode,
                              decoration: const InputDecoration(
                                labelText: 'Code',
                                border: OutlineInputBorder(),
                              ),
                              items: _countryCodes
                                  .map(
                                    (code) => DropdownMenuItem(
                                      value: code,
                                      child: Text(code),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCountryCode = val!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                if (val == null || val.isEmpty)
                                  return 'Enter phone';
                                if (!RegExp(r'^[0-9]{7,13}$').hasMatch(val))
                                  return 'Enter valid phone';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    if (!_otpSent) const SizedBox(height: 16),

                    // Login / OTP
                    if (!_otpSent)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _loginWithEmail,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text('Login'),
                      ),

                    if (_otpSent) ...[
                      TextFormField(
                        controller: _otpController,
                        decoration: const InputDecoration(
                          labelText: 'Enter OTP',
                          prefixIcon: Icon(Icons.sms),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _verifyOtp,
                        child: const Text("Verify OTP"),
                      ),
                      TextButton(
                        onPressed: _resendOtp,
                        child: const Text("Resend OTP"),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
