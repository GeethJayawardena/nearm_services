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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${userData?['name'] ?? 'N/A'}'),
                    Text('Email: ${userData?['email'] ?? 'N/A'}'),
                    const Divider(height: 32),
                    Text(
                      'Booking Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Status: ${requestData['status']}'),
                    Text(
                      'Requested At: ${requestData['timestamp'] != null ? (requestData['timestamp'] as Timestamp).toDate().toString() : 'N/A'}',
                    ),
                    const SizedBox(height: 32),
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
              );
            },
          );
        },
      ),
    );
  }
}
