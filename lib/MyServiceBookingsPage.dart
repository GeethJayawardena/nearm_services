import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyServiceBookingsPage extends StatelessWidget {
  const MyServiceBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    final servicesRef = FirebaseFirestore.instance
        .collection('services')
        .where('ownerId', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(title: const Text("My Service Bookings")),
      body: StreamBuilder<QuerySnapshot>(
        stream: servicesRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("Error: ${snap.error}"));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final services = snap.data!.docs;
          if (services.isEmpty) {
            return const Center(child: Text("No services added yet."));
          }

          return ListView(
            children: services.map((serviceDoc) {
              final serviceData = serviceDoc.data() as Map<String, dynamic>;
              final serviceName = serviceData['name'] ?? "Unnamed Service";

              return ExpansionTile(
                title: Text(serviceName),
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: serviceDoc.reference
                        .collection('bookings')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, bookingSnap) {
                      if (bookingSnap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("Error: ${bookingSnap.error}"),
                        );
                      }
                      if (!bookingSnap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        );
                      }

                      final bookings = bookingSnap.data!.docs;
                      if (bookings.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text("No booking requests yet."),
                        );
                      }

                      return Column(
                        children: bookings.map((bookingDoc) {
                          final booking =
                              bookingDoc.data() as Map<String, dynamic>;
                          final userEmail =
                              booking['userEmail'] ?? "Unknown User";
                          final status = booking['status'] ?? "pending";

                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text("User: $userEmail"),
                            subtitle: Text("Status: $status"),
                            trailing: status == "pending"
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check,
                                          color: Colors.green,
                                        ),
                                        onPressed: () {
                                          bookingDoc.reference.update({
                                            "status": "approved",
                                          });
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          bookingDoc.reference.update({
                                            "status": "rejected",
                                          });
                                        },
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
