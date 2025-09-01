import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class RequestDetailsPage extends StatefulWidget {
  final String bookingId;
  final String serviceId;
  final String userId;

  const RequestDetailsPage({
    super.key,
    required this.bookingId,
    required this.serviceId,
    required this.userId,
  });

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage> {
  Map<String, dynamic>? requestData;
  Map<String, dynamic>? userData;
  bool isSeller = false;
  double rating = 0;
  final TextEditingController reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final serviceDoc = await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .get();
    if (!serviceDoc.exists) return;

    final ownerId = serviceDoc['ownerId'];
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      isSeller = user.uid == ownerId;
    }

    final reqDoc = await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(widget.bookingId)
        .get();

    final uDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    setState(() {
      requestData = reqDoc.data();
      userData = uDoc.exists ? uDoc.data() : null;
    });
  }

  Future<void> _proposePrice(double price) async {
    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(widget.bookingId)
        .update({
          'proposedPrice': price,
          'status': 'price_proposed',
          'buyerAgreed': null,
        });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Price \$${price.toString()} sent to buyer')),
    );
    _loadData();
  }

  void _showPriceDialog() {
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
                _proposePrice(price);
                Navigator.pop(context);
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  Future<void> _buyerRespond(bool agreed) async {
    if (agreed) {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('requests')
          .doc(widget.bookingId)
          .update({'buyerAgreed': true, 'status': 'buyer_agreed'});
    } else {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('requests')
          .doc(widget.bookingId)
          .update({'buyerAgreed': false, 'status': 'cancelled'});
    }
    _loadData();
  }

  Future<void> _completeJob() async {
    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(widget.bookingId)
        .update({'status': 'completed'});
    _loadData();
  }

  void _goToBankPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BankDetailsPage(
          serviceId: widget.serviceId,
          bookingId: widget.bookingId,
        ),
      ),
    ).then((paid) {
      if (paid == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment done! Please submit review.')),
        );
        _loadData();
      }
    });
  }

  Future<void> _submitReview() async {
    if (reviewController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write a review before submitting'),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(widget.bookingId)
        .update({
          'review': {'comment': reviewController.text.trim(), 'rating': rating},
          'status': 'done',
        });
    _loadData();
    reviewController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review submitted! Booking finished.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (requestData == null || userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final status = requestData!['status'] ?? 'pending';
    final proposedPrice = requestData!['proposedPrice'];
    final paymentStatus = requestData!['paymentStatus'];

    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User: ${userData!['name'] ?? 'N/A'}'),
            Text('Email: ${userData!['email'] ?? 'N/A'}'),
            const Divider(height: 32),
            Text('Status: $status'),
            if (proposedPrice != null && status != 'cancelled')
              Text('Proposed Price: \$${proposedPrice.toString()}'),
            const SizedBox(height: 16),

            // Seller: propose price
            if (isSeller && status == 'pending')
              ElevatedButton(
                onPressed: _showPriceDialog,
                child: const Text("Propose Price"),
              ),

            // Buyer: accept/reject price
            if (!isSeller &&
                status == 'price_proposed' &&
                requestData!['buyerAgreed'] == null)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _buyerRespond(true),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => _buyerRespond(false),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),

            // Buyer: cancelled
            if (!isSeller && status == 'cancelled')
              const Text(
                'Booking cancelled',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),

            // Seller: complete job
            if (isSeller && status == 'buyer_agreed')
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _completeJob,
                child: const Text('Mark Job Completed'),
              ),

            // Buyer: pay after job completed
            if (!isSeller && status == 'completed' && paymentStatus != 'paid')
              ElevatedButton(
                onPressed: _goToBankPayment,
                child: const Text('Pay Now'),
              ),

            // Buyer: submit review after payment
            if (!isSeller && status == 'completed' && paymentStatus == 'paid')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  TextField(
                    controller: reviewController,
                    decoration: const InputDecoration(
                      hintText: 'Write review...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Rating:'),
                      Slider(
                        value: rating,
                        min: 0,
                        max: 5,
                        divisions: 5,
                        label: rating.toString(),
                        onChanged: (val) => setState(() => rating = val),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _submitReview,
                    child: const Text('Submit Review'),
                  ),
                ],
              ),

            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat),
                label: const Text('Chat'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        serviceId: widget.serviceId,
                        otherUserId: widget.userId,
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
  }
}

// --- BankDetailsPage ---
class BankDetailsPage extends StatelessWidget {
  final String serviceId;
  final String bookingId;
  const BankDetailsPage({
    super.key,
    required this.serviceId,
    required this.bookingId,
  });

  Future<void> _completePayment(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('services')
        .doc(serviceId)
        .collection('requests')
        .doc(bookingId)
        .update({'paymentStatus': 'paid'});

    Navigator.pop(context, true); // return true to indicate payment done
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Details')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _completePayment(context),
          child: const Text('Pay \$100 (Sample Payment)'),
        ),
      ),
    );
  }
}
