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

  Future<void> _payNow() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Update Firestore with paymentStatus
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('requests')
          .doc(user.uid)
          .update({'paymentStatus': 'paid'});

      setState(() {
        _paid = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment successful!')));

      // Return true to previous page
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Bank Details & Payment"),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bank Details Card
                  SizedBox(
                    width: double.infinity,
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child:
                            bankData != null &&
                                bankData!['bankName'] != null &&
                                bankData!['accountNumber'] != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Bank Details",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Bank Name: ${bankData!['bankName']}",
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Account Number: ${bankData!['accountNumber']}",
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  if (bankData!['cardNumber'] != null)
                                    Text(
                                      "Card Number: ${bankData!['cardNumber']}",
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  if (bankData!['expiryDate'] != null)
                                    Text(
                                      "Expiry Date: ${bankData!['expiryDate']}",
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  if (bankData!['cvv'] != null)
                                    Text(
                                      "CVV: ${bankData!['cvv']}",
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                ],
                              )
                            : Center(
                                child: Text(
                                  "No bank details found. Please contact the seller to pay.",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Pay Button
                  if (!_paid)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _payNow,
                        icon: const Icon(Icons.payment),
                        label: const Text("Pay Now"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 32,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                  // After Payment Message
                  if (_paid)
                    Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.shade400),
                        ),
                        child: Column(
                          children: const [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 60,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '✅ Payment done! Thank you!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
