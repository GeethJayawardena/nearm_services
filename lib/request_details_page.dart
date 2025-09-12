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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- User Info Card ---
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepPurple.shade200,
                      child: Text(
                        (userData!['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userData!['name'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userData!['email'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Booking Info Card ---
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: status == 'cancelled'
                            ? Colors.red
                            : Colors.green.shade700,
                      ),
                    ),
                    if (proposedPrice != null && status != 'cancelled')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Proposed Price: \$${proposedPrice.toString()}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // --- Action Buttons ---
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isSeller && status == 'pending')
                          ElevatedButton.icon(
                            onPressed: _showPriceDialog,
                            icon: const Icon(Icons.attach_money),
                            label: const Text("Propose Price"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        if (!isSeller &&
                            status == 'price_proposed' &&
                            requestData!['buyerAgreed'] == null)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _buyerRespond(true),
                                  child: const Text('Accept'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _buyerRespond(false),
                                  child: const Text('Reject'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (isSeller && status == 'buyer_agreed')
                          ElevatedButton.icon(
                            onPressed: _completeJob,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Mark Job Completed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        if (!isSeller &&
                            status == 'completed' &&
                            paymentStatus != 'paid')
                          ElevatedButton.icon(
                            onPressed: _goToBankPayment,
                            icon: const Icon(Icons.payment),
                            label: const Text('Pay Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Review Section ---
            if (!isSeller && status == 'completed' && paymentStatus == 'paid')
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Submit Review',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: reviewController,
                        decoration: InputDecoration(
                          hintText: 'Write your review...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Rating:'),
                          Expanded(
                            child: Slider(
                              value: rating,
                              min: 0,
                              max: 5,
                              divisions: 5,
                              label: rating.toString(),
                              onChanged: (val) => setState(() => rating = val),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _submitReview,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Review'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // --- Chat Button ---
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat, key: ValueKey('chat_icon')),
                label: const Text('Chat with User'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        serviceId: widget.serviceId,
                        otherUserId: widget.userId,
                      ),
                      fullscreenDialog:
                          true, // optional: also prevents hero conflicts
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Bank Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () => _completePayment(context),
          icon: const Icon(Icons.payment),
          label: const Text('Pay \$100 (Sample Payment)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
