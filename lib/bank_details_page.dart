import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BankDetailsPage extends StatefulWidget {
  final String serviceId;
  const BankDetailsPage({super.key, required this.serviceId});

  @override
  State<BankDetailsPage> createState() => _BankDetailsPageState();
}

class _BankDetailsPageState extends State<BankDetailsPage> {
  Map<String, dynamic>? bankData;
  bool _loading = true;
  final TextEditingController _reviewController = TextEditingController();
  bool _paid = false;

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  Future<void> _loadBankDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    setState(() {
      bankData = doc.exists ? doc.data() : null;
      _loading = false;
    });
  }

  Future<void> _payAndSubmit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Update Firestore: mark payment done and store review
    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(user.uid)
        .update({
          'paymentStatus': 'paid',
          'buyerReview': {
            'comment': _reviewController.text.trim(),
            'rating': 5, // You can add rating input field if needed
          },
          'status': 'done',
        });

    setState(() {
      _paid = true;
      _reviewController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment done & review submitted!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final hasBankDetails =
        bankData != null &&
        bankData!['bankName'] != null &&
        bankData!['accountNumber'] != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Bank Details & Payment")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasBankDetails) ...[
              Text("Bank Name: ${bankData!['bankName']}"),
              const SizedBox(height: 8),
              Text("Account Number: ${bankData!['accountNumber']}"),
              const SizedBox(height: 8),
              Text("Card Number: ${bankData!['cardNumber']}"),
              const SizedBox(height: 8),
              Text("Expiry Date: ${bankData!['expiryDate']}"),
              const SizedBox(height: 8),
              Text("CVV: ${bankData!['cvv']}"),
              const SizedBox(height: 20),
            ] else ...[
              const Text(
                "No bank details found. Please contact the seller to pay.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
            ],

            // Show Pay button only if not yet paid
            if (!_paid)
              Center(
                child: ElevatedButton(
                  onPressed: _payAndSubmit,
                  child: const Text("Pay Now"),
                ),
              ),

            // After payment, show review input
            if (_paid)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "Submit your review",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextField(
                    controller: _reviewController,
                    decoration: const InputDecoration(
                      hintText: "Write your review",
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton(
                      onPressed: _payAndSubmit,
                      child: const Text("Submit Review & Done"),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
