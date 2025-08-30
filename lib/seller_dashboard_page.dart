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

  /// Mark all notifications as read (optional)
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
    if (_scrollDone || widget.focusServiceId == null || widget.focusBookingId == null) return;

    double offset = 0;
    for (var serviceDoc in serviceDocs) {
      final serviceId = serviceDoc.id;

      // Approximate height per service header + bookings
      final serviceData = serviceDoc.data()! as Map<String, dynamic>;
      final requests = serviceDoc.reference
          .collection('requests')
          .where('status', isEqualTo: 'pending');

      // We'll scroll after first frame, just highlight is enough
      if (serviceId == widget.focusServiceId) {
        // Scroll to top for now (we can't get exact index without fully loaded requests)
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

      offset += 120.0; // approx height per service
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                    onPressed: () async {
                      await markNotificationsAsRead();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifications cleared!')),
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

          // Scroll to focused booking
          _scrollToFocusedBooking(services);

          return ListView(
            controller: _scrollController,
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: serviceId == widget.focusServiceId
                                ? Colors.blue
                                : Colors.black,
                          ),
                        ),
                      ),
                      ...requests.map((reqDoc) {
                        final reqData = reqDoc.data()! as Map<String, dynamic>;
                        final userEmail =
                            reqData['userEmail'] ?? reqData['userId'];

                        final isFocused =
                            reqDoc.id == widget.focusBookingId;

                        return Card(
                          color: isFocused ? Colors.yellow[100] : Colors.white,
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
