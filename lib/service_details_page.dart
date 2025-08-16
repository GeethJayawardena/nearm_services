import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class ServiceDetailsPage extends StatefulWidget {
  final String serviceId;
  const ServiceDetailsPage({super.key, required this.serviceId});

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage> {
  double _rating = 0;

  Future<Map<String, dynamic>?> _fetchUserRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(user.uid)
        .get();

    if (!doc.exists) return null;
    return doc.data()!;
  }

  Future<void> _requestBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final serviceDoc = await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .get();
    if (!serviceDoc.exists) return;

    final ownerId = serviceDoc['ownerId'];

    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(user.uid)
        .set({
          'userId': user.uid,
          'userEmail': user.email,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

    // Notify owner
    await FirebaseFirestore.instance.collection('notifications').add({
      'ownerId': ownerId,
      'serviceId': widget.serviceId,
      'userId': user.uid,
      'type': 'booking_request',
      'status': 'unread',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking request sent! Waiting for approval.'),
        ),
      );
      setState(() {}); // Refresh UI to show pending status
    }
  }

  Future<void> _submitRating() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('ratings')
        .doc(user.uid)
        .set({
          'rating': _rating,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': user.uid,
          'userEmail': user.email,
        });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rating submitted!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceRef = FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId);

    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: FutureBuilder<DocumentSnapshot>(
        future: serviceRef.get(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists)
            return const Center(child: Text('Service not found.'));

          final data = snap.data!.data()! as Map<String, dynamic>;
          final ownerName = data['ownerName'] ?? '';
          final ownerEmail = data['ownerEmail'] ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                data['name'] ?? '',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text('${data['category']} • ${data['location']}'),
              const SizedBox(height: 6),
              Text('Price Range: ${data['priceMin']} - ${data['priceMax']}'),
              const SizedBox(height: 6),
              Text('Owner: ${ownerName.isNotEmpty ? ownerName : ownerEmail}'),
              const SizedBox(height: 8),
              _AverageRatingBlock(serviceId: widget.serviceId),
              const SizedBox(height: 16),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(data['description'] ?? ''),
              const SizedBox(height: 20),

              // Booking / Chat button
              FutureBuilder<Map<String, dynamic>?>(
                future: _fetchUserRequest(),
                builder: (context, requestSnap) {
                  final requestData = requestSnap.data;

                  if (requestData == null) {
                    // No request yet → show booking button
                    return ElevatedButton(
                      onPressed: _requestBooking,
                      child: const Text('Request Booking'),
                    );
                  }

                  if (requestData['status'] == 'pending') {
                    return ElevatedButton(
                      onPressed: null,
                      child: const Text('Booking Pending'),
                    );
                  }

                  if (requestData['status'] == 'approved') {
                    return ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              serviceId: widget.serviceId,
                              otherUserId: data['ownerId'],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Chat with Seller'),
                    );
                  }

                  if (requestData['status'] == 'rejected') {
                    return ElevatedButton(
                      onPressed: null,
                      child: const Text('Booking Rejected'),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),

              const Divider(height: 32),
              const Text(
                'Rate this service',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _rating,
                min: 0,
                max: 5,
                divisions: 5,
                label: _rating.toStringAsFixed(1),
                onChanged: (val) => setState(() => _rating = val),
              ),
              ElevatedButton(
                onPressed: _submitRating,
                child: const Text('Submit Rating'),
              ),
              const SizedBox(height: 20),
              const Text(
                'All Ratings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _RatingsList(serviceId: widget.serviceId),
            ],
          );
        },
      ),
    );
  }
}

class _AverageRatingBlock extends StatelessWidget {
  final String serviceId;
  const _AverageRatingBlock({required this.serviceId});

  @override
  Widget build(BuildContext context) {
    final ratingsRef = FirebaseFirestore.instance
        .collection('services')
        .doc(serviceId)
        .collection('ratings');

    return StreamBuilder<QuerySnapshot>(
      stream: ratingsRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Text('⭐ No ratings yet');
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Text('⭐ No ratings yet');

        double sum = 0;
        for (final d in docs) {
          final m = d.data() as Map<String, dynamic>;
          sum += (m['rating'] ?? 0).toDouble();
        }
        final avg = sum / docs.length;
        return Text('⭐ ${avg.toStringAsFixed(1)} (${docs.length})');
      },
    );
  }
}

class _RatingsList extends StatelessWidget {
  final String serviceId;
  const _RatingsList({required this.serviceId});

  @override
  Widget build(BuildContext context) {
    final ratingsRef = FirebaseFirestore.instance
        .collection('services')
        .doc(serviceId)
        .collection('ratings')
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: ratingsRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Text('No ratings yet.');

        return Column(
          children: docs.map((d) {
            final m = d.data() as Map<String, dynamic>;
            final rating = (m['rating'] ?? 0).toDouble();
            final email = m['userEmail'] ?? 'User';
            return ListTile(
              dense: true,
              leading: const Icon(Icons.person),
              title: Text('⭐ ${rating.toStringAsFixed(1)}'),
              subtitle: Text(email),
            );
          }).toList(),
        );
      },
    );
  }
}
