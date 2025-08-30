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
  Map<String, dynamic>? _requestData;
  String? _ownerId;

  @override
  void initState() {
    super.initState();
    _loadServiceData();
  }

  Future<void> _loadServiceData() async {
    final serviceDoc = await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .get();
    if (!serviceDoc.exists) return;

    _ownerId = serviceDoc['ownerId'];

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final requestDoc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('requests')
          .doc(user.uid)
          .get();
      setState(() {
        _requestData = requestDoc.exists ? requestDoc.data()! : null;
      });
    }
  }

  Future<void> _requestBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _ownerId == null) return;

    // 1️⃣ Save booking request
    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(user.uid)
        .set({
          'userId': user.uid,
          'userEmail': user.email,
          'userName': user.displayName ?? user.email,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

    // 2️⃣ Add notification for seller
    await FirebaseFirestore.instance.collection('notifications').add({
      'ownerId': _ownerId, // Seller ID
      'serviceId': widget.serviceId,
      'userId': user.uid,
      'userName': user.displayName ?? user.email,
      'type': 'booking_request',
      'status': 'unread',
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() {
      _requestData = {
        'userId': user.uid,
        'userEmail': user.email,
        'status': 'pending',
      };
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking requested! You can now chat.')),
    );
  }

  void _openChat() {
    if (_ownerId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatPage(serviceId: widget.serviceId, otherUserId: _ownerId!),
      ),
    );
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Rating submitted!')));
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
          _ownerId = data['ownerId'];

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
              Text(
                'Owner: ${ownerName.isNotEmpty ? ownerName : data['ownerEmail']}',
              ),
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
              if (_requestData == null)
                ElevatedButton(
                  onPressed: _requestBooking,
                  child: const Text('Request Booking'),
                ),
              if (_requestData != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openChat,
                      icon: const Icon(Icons.chat),
                      label: Text(
                        _requestData!['status'] == 'pending'
                            ? 'Chat with Seller (Pending)'
                            : 'Chat with Seller',
                      ),
                    ),
                    if (_requestData!['status'] == 'pending')
                      const SizedBox(height: 4),
                    if (_requestData!['status'] == 'rejected')
                      const Text(
                        'Booking Rejected',
                        style: TextStyle(color: Colors.red),
                      ),
                    if (_requestData!['status'] == 'approved')
                      const Text(
                        'Booking Approved',
                        style: TextStyle(color: Colors.green),
                      ),
                  ],
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
