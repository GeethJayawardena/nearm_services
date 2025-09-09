import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'request_details_page.dart';

class SellerDashboardPage extends StatefulWidget {
  final String? focusServiceId;
  final String? focusBookingId;

  const SellerDashboardPage({
    super.key,
    this.focusServiceId,
    this.focusBookingId,
  });

  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage> {
  final ScrollController _scrollController = ScrollController();
  bool _scrollDone = false;

  Future<void> markNotificationsAsRead() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final unread = await FirebaseFirestore.instance
        .collection('notifications')
        .where('ownerId', isEqualTo: userId)
        .where('status', isEqualTo: 'unread')
        .get();

    for (var doc in unread.docs) {
      await doc.reference.update({'status': 'read'});
    }
  }

  void _scrollToFocusedBooking(List<QueryDocumentSnapshot> serviceDocs) {
    if (_scrollDone ||
        widget.focusServiceId == null ||
        widget.focusBookingId == null)
      return;

    double offset = 0;
    for (var serviceDoc in serviceDocs) {
      final serviceId = serviceDoc.id;
      if (serviceId == widget.focusServiceId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        });
        _scrollDone = true;
        break;
      }
      offset += 150.0; // approximate height of service+requests
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case "pending":
        color = Colors.orange;
        break;
      case "approved":
      case "buyeragreed":
        color = Colors.green;
        break;
      case "completed":
        color = Colors.blue;
        break;
      case "rejected":
      case "cancelled":
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

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
      appBar: AppBar(
        title: const Text('Seller Dashboard'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('ownerId', isEqualTo: user.uid)
                .where('status', isEqualTo: 'unread')
                .snapshots(),
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData) count = snapshot.data!.docs.length;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                "Notifications",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (count == 0)
                                const Text("No new notifications"),
                              if (count > 0)
                                Text("$count unread notifications"),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await markNotificationsAsRead();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AllNotificationsPage(),
                                    ),
                                  );
                                },
                                child: const Text("View All"),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
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

          _scrollToFocusedBooking(services);

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            children: services.map((serviceDoc) {
              final serviceId = serviceDoc.id;
              final serviceData = serviceDoc.data()! as Map<String, dynamic>;
              final serviceName = serviceData['name'] ?? 'Unnamed Service';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: serviceId == widget.focusServiceId
                              ? Colors.blue
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('services')
                            .doc(serviceId)
                            .collection('requests')
                            .snapshots(),
                        builder: (context, reqSnap) {
                          if (!reqSnap.hasData || reqSnap.data!.docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text("No bookings yet"),
                            );
                          }

                          return Column(
                            children: reqSnap.data!.docs.map((reqDoc) {
                              final reqData =
                                  reqDoc.data()! as Map<String, dynamic>;
                              final userEmail =
                                  reqData['userEmail'] ?? reqData['userId'];
                              String subtitle = '';
                              Color subtitleColor = Colors.black;

                              if (reqData['status'] == 'pending') {
                                subtitle = 'Pending booking request';
                                subtitleColor = Colors.orange;
                              } else if (reqData['status'] == 'approved' &&
                                  reqData['buyerAgreed'] == true) {
                                subtitle = 'Buyer accepted proposed price';
                                subtitleColor = Colors.green;
                              } else if (reqData['status'] == 'completed' &&
                                  reqData['jobCompleted'] == true) {
                                subtitle =
                                    'Job Completed • Payment: ${reqData['paymentStatus'] ?? 'Pending'}';
                                subtitleColor = Colors.blue;
                                if (reqData['buyerReview'] != null) {
                                  subtitle +=
                                      ' • Review: ${reqData['buyerReview']['rating']}/5';
                                }
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text('Booking from $userEmail'),
                                  subtitle: subtitle.isNotEmpty
                                      ? Text(
                                          subtitle,
                                          style: TextStyle(
                                            color: subtitleColor,
                                          ),
                                        )
                                      : null,
                                  trailing: _statusChip(
                                    reqData['status'] ?? 'pending',
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RequestDetailsPage(
                                        bookingId: reqDoc.id,
                                        serviceId: serviceId,
                                        userId: reqData['userId'],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class AllNotificationsPage extends StatelessWidget {
  const AllNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sellerId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("All Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('ownerId', isEqualTo: sellerId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!.docs;
          if (notifications.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(data['type'] ?? 'Notification'),
                subtitle: Text(data['userName'] ?? 'Unknown User'),
                trailing: Text(data['status'] ?? ''),
              );
            },
          );
        },
      ),
    );
  }
}
