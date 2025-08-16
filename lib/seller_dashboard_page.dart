import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'request_details_page.dart'; // Create this page for full details + chat

class SellerDashboardPage extends StatelessWidget {
  const SellerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final servicesRef = FirebaseFirestore.instance
        .collection('services')
        .where('ownerId', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Seller Dashboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: servicesRef.snapshots(),
        builder: (context, serviceSnap) {
          if (serviceSnap.hasError) {
            return Center(child: Text('Error: ${serviceSnap.error}'));
          }
          if (!serviceSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final services = serviceSnap.data!.docs;
          if (services.isEmpty) {
            return const Center(child: Text('You have no services listed.'));
          }

          return ListView(
            children: services.map((serviceDoc) {
              final serviceId = serviceDoc.id;
              final serviceData = serviceDoc.data()! as Map<String, dynamic>;
              final serviceName = serviceData['name'] ?? 'Unnamed Service';

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('services')
                    .doc(serviceId)
                    .collection('requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, reqSnap) {
                  if (!reqSnap.hasData) return const SizedBox();
                  final requests = reqSnap.data!.docs;
                  if (requests.isEmpty) return const SizedBox();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          serviceName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...requests.map((reqDoc) {
                        final reqData = reqDoc.data()! as Map<String, dynamic>;
                        final userEmail =
                            reqData['userEmail'] ?? reqData['userId'];

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: ListTile(
                            title: Text('Booking request from $userEmail'),
                            subtitle: Text('Status: ${reqData['status']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  ),
                                  onPressed: () {
                                    FirebaseFirestore.instance
                                        .collection('services')
                                        .doc(serviceId)
                                        .collection('requests')
                                        .doc(reqDoc.id)
                                        .update({'status': 'approved'});
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    FirebaseFirestore.instance
                                        .collection('services')
                                        .doc(serviceId)
                                        .collection('requests')
                                        .doc(reqDoc.id)
                                        .update({'status': 'rejected'});
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              // Navigate to full request details + chat
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RequestDetailsPage(
                                    bookingId: reqDoc.id,
                                    serviceId: serviceId,
                                    userId: reqData['userId'],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
