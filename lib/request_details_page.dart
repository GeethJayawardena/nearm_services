import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart'; // Make sure this file exists

class RequestDetailsPage extends StatelessWidget {
  final String bookingId;
  final String serviceId;
  final String userId;

  const RequestDetailsPage({
    super.key,
    required this.bookingId,
    required this.serviceId,
    required this.userId,
  });

  Future<Map<String, dynamic>?> _fetchRequestDetails() async {
    final doc = await FirebaseFirestore.instance
        .collection('services')
        .doc(serviceId)
        .collection('requests')
        .doc(bookingId)
        .get();

    if (!doc.exists) return null;
    return doc.data()!;
  }

  Future<Map<String, dynamic>?> _fetchUserDetails(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    return doc.data()!;
  }

  Future<void> _proposePrice(BuildContext context, double price) async {
    await FirebaseFirestore.instance
        .collection('services')
        .doc(serviceId)
        .collection('requests')
        .doc(bookingId)
        .update({
          'proposedPrice': price,
          'buyerAgreed': null, // reset previous response
        });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Price \$${price.toString()} sent to buyer')),
    );
  }

  void _showPriceDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Propose Price"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Enter price"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(controller.text);
              if (price != null) {
                _proposePrice(context, price);
                Navigator.pop(context);
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Request Details')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchRequestDetails(),
        builder: (context, requestSnap) {
          if (requestSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requestData = requestSnap.data;
          if (requestData == null) {
            return const Center(child: Text('Request not found.'));
          }

          return FutureBuilder<Map<String, dynamic>?>(
            future: _fetchUserDetails(userId),
            builder: (context, userSnap) {
              final userData = userSnap.data;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- User Info ---
                      Text(
                        'User Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Name: ${userData?['name'] ?? 'N/A'}'),
                      Text('Email: ${userData?['email'] ?? 'N/A'}'),
                      const Divider(height: 32),

                      // --- Booking Info ---
                      Text(
                        'Booking Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Status: ${requestData['status']}'),
                      Text(
                        'Requested At: ${requestData['timestamp'] != null ? (requestData['timestamp'] as Timestamp).toDate().toString() : 'N/A'}',
                      ),
                      Text(
                        'Selected Date: ${requestData['selectedDate'] != null ? (requestData['selectedDate'] as Timestamp).toDate().toString() : 'N/A'}',
                      ),
                      const SizedBox(height: 16),

                      // --- Proposed Price (Seller) ---
                      if (requestData['proposedPrice'] != null)
                        Text(
                          'Proposed Price: \$${requestData['proposedPrice']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (requestData['buyerAgreed'] != null)
                        Text(
                          'Buyer Response: ${requestData['buyerAgreed']! ? "Agreed" : "Rejected"}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: requestData['buyerAgreed']!
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // --- Seller can propose price if status is pending ---
                      if (requestData['status'] == 'pending')
                        ElevatedButton(
                          onPressed: () => _showPriceDialog(context),
                          child: const Text("Propose Price"),
                        ),

                      const SizedBox(height: 16),

                      // --- Accept / Reject Booking Buttons ---
                      if (requestData['status'] == 'pending')
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('services')
                                      .doc(serviceId)
                                      .collection('requests')
                                      .doc(bookingId)
                                      .update({'status': 'approved'});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Booking approved'),
                                    ),
                                  );
                                },
                                child: const Text('Accept'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  FirebaseFirestore.instance
                                      .collection('services')
                                      .doc(serviceId)
                                      .collection('requests')
                                      .doc(bookingId)
                                      .update({'status': 'rejected'});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Booking rejected'),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 32),

                      // --- Chat Button ---
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.chat),
                          label: const Text('Chat with User'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  serviceId: serviceId,
                                  otherUserId: userId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
