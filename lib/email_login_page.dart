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
  OverlayEntry? _otpOverlay;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }

  String _generateOtp() {
    final rnd = Random();
    return (100000 + rnd.nextInt(900000)).toString();
  }

  void _showOtpNotification(String otp) {
    _otpOverlay?.remove();
    _otpOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        left: 16,
        right: 16,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: Colors.deepPurple.shade400,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.sms, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Your OTP is: $otp",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .get();

      if (doc.exists && doc.data()?['phone'] != null) {
        final savedPhone = doc.data()?['phone'];

        if (savedPhone != enteredPhone) {
          _showMessage("⚠️ Phone number does not match our records.");
          await FirebaseAuth.instance.signOut();
          setState(() => _otpSent = false);
          return;
        }

        _userPhone = savedPhone;
        _generatedOtp = _generateOtp();
        setState(() => _otpSent = true);
        _showOtpNotification(_generatedOtp!);
      } else {
        _showMessage(
          "⚠️ No phone number saved. Please create an account first.",
        );
        await FirebaseAuth.instance.signOut();
        setState(() => _otpSent = false);
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
      body: Stack(
        children: [
          // Background gradient
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
                          "Welcome Back",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Login to continue using your account",
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 32),

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

                            final emailParts = val.split('@');
                            if (emailParts.length != 2)
                              return 'Enter valid email';

                            final localPart = emailParts[0];
                            final domainPart = emailParts[1];

                            // Only allow lowercase domain
                            final allowedDomains = [
                              'gmail.com',
                              'yahoo.com',
                              'hotmail.com',
                            ];
                            if (!allowedDomains.contains(domainPart)) {
                              return 'Enter valid email';
                            }

                            // Local part can have lowercase letters, numbers, and special chars
                            final localRegex = RegExp(r'^[a-z0-9._%+-]+$');
                            if (!localRegex.hasMatch(localPart))
                              return 'Invalid email format';

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
                          validator: (val) => val == null || val.isEmpty
                              ? 'Enter password'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Phone + Country code
                        if (!_otpSent)
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCountryCode,
                                  decoration: InputDecoration(
                                    labelText: 'Code',
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
                                  onChanged: (val) => setState(
                                    () => _selectedCountryCode = val!,
                                  ),
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
                                    if (!RegExp(r'^7\d{8}$').hasMatch(val))
                                      return 'Enter valid phone number';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        if (!_otpSent) const SizedBox(height: 24),

                        // Login button
                        if (!_otpSent)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _loginWithEmail,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.deepPurple,
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),

                        // OTP verification
                        if (_otpSent) ...[
                          TextFormField(
                            controller: _otpController,
                            decoration: InputDecoration(
                              labelText: 'Enter OTP',
                              prefixIcon: const Icon(Icons.sms),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.deepPurple,
                              ),
                              child: const Text(
                                'Verify OTP',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
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
        ],
      ),
    );
  }
}
