import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _loading = false;
  bool _otpSent = false;
  String? _generatedOtp;

  String _selectedCountryCode = "+94";
  final List<String> _countryCodes = ["+94", "+91", "+44", "+1", "+61"];

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  void _showOtpNotification(String otp) {
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        left: 16,
        right: 16,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          color: Colors.deepPurple,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                  onPressed: () => overlayEntry?.remove(),
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

    Overlay.of(context)?.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 5), () => overlayEntry?.remove());
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.isEmpty) {
      _showMessage('Enter phone number first');
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));

    _generatedOtp = _generateOtp();
    _otpSent = true;
    setState(() => _loading = false);

    _showOtpNotification(_generatedOtp!);
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_otpSent) {
      _showMessage('Send OTP first');
      return;
    }
    if (_otpController.text.trim() != _generatedOtp) {
      _showMessage('Invalid OTP ❌');
      return;
    }

    setState(() => _loading = true);

    try {
      String fullPhone = "$_selectedCountryCode${_phoneController.text.trim()}";

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user?.uid)
          .set({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': fullPhone,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
            'phoneVerified': true,
          });

      _showMessage('✅ Account created successfully!');
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 12,
                shadowColor: Colors.black54,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Sign up to get started!",
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 32),

                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Name',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          validator: (val) => val == null || val.isEmpty
                              ? 'Enter your name'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.isEmpty)
                              return 'Enter email';
                            if (!RegExp(
                              r'^[\w-]+@([\w-]+\.)+[\w]{2,4}$',
                            ).hasMatch(val))
                              return 'Enter valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          obscureText: true,
                          validator: (val) {
                            if (val == null || val.isEmpty)
                              return 'Enter password';
                            if (val.length < 6)
                              return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone + Country Code
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _selectedCountryCode,
                                decoration: InputDecoration(
                                  labelText: "Code",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                                items: _countryCodes
                                    .map(
                                      (code) => DropdownMenuItem(
                                        value: code,
                                        child: Text(code),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => setState(() {
                                  _selectedCountryCode = val!;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                controller: _phoneController,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: const Icon(Icons.phone),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (val) {
                                  if (val == null || val.isEmpty)
                                    return 'Enter phone number';
                                  if (!RegExp(r'^[0-9]{7,13}$').hasMatch(val))
                                    return 'Enter valid phone';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // OTP
                        if (_otpSent)
                          Column(
                            children: [
                              TextFormField(
                                controller: _otpController,
                                decoration: const InputDecoration(
                                  labelText: 'Enter OTP',
                                  prefixIcon: Icon(Icons.confirmation_number),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _loading ? null : _sendOtp,
                                  child: const Text("Resend OTP"),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),

                        // Send OTP / Create Account button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading
                                ? null
                                : (_otpSent ? _createAccount : _sendOtp),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.deepPurple,
                            ),
                            child: _loading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    _otpSent ? 'Create Account' : 'Send OTP',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            '/login-email',
                          ),
                          child: const Text('Back to Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
