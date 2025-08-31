import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'main.dart'; // routeObserver

class ServiceDetailsPage extends StatefulWidget {
  final String serviceId;
  const ServiceDetailsPage({super.key, required this.serviceId});

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage>
    with RouteAware {
  Map<String, dynamic>? _requestData;
  bool _isSeller = false;
  String? _ownerId;
  DateTime? _selectedDate;
  double _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServiceData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _reviewController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
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
      _isSeller = user.uid == _ownerId;
      DocumentSnapshot? requestDoc;

      if (_isSeller) {
        final requests = await FirebaseFirestore.instance
            .collection('services')
            .doc(widget.serviceId)
            .collection('requests')
            .get();
        if (requests.docs.isNotEmpty) requestDoc = requests.docs.first;
      } else {
        requestDoc = await FirebaseFirestore.instance
            .collection('services')
            .doc(widget.serviceId)
            .collection('requests')
            .doc(user.uid)
            .get();
      }

      setState(() {
        if (requestDoc != null && requestDoc.exists) {
          _requestData = requestDoc.data()! as Map<String, dynamic>;
          if (_selectedDate == null && _requestData!['bookingDate'] != null) {
            final bd = _requestData!['bookingDate'];
            if (bd is Timestamp)
              _selectedDate = bd.toDate();
            else if (bd is DateTime)
              _selectedDate = bd;
          }
          if (_requestData!['buyerReview'] != null &&
              _requestData!['buyerReview']['rating'] != null) {
            _rating = (_requestData!['buyerReview']['rating'] as num)
                .toDouble();
          }
        } else {
          _requestData = null;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _requestBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _ownerId == null) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a booking date")),
      );
      return;
    }

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
          'bookingDate': Timestamp.fromDate(_selectedDate!),
          'buyerAgreed': null,
          'proposedPrice': null,
          'paymentStatus': null,
          'buyerReview': null,
        });

    setState(() {
      _requestData = {
        'userId': user.uid,
        'userEmail': user.email,
        'status': 'pending',
        'bookingDate': Timestamp.fromDate(_selectedDate!),
        'buyerAgreed': null,
        'proposedPrice': null,
        'paymentStatus': null,
        'buyerReview': null,
      };
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Booking requested!')));
  }

  Future<void> _proposePrice() async {
    if (_requestData == null || !_isSeller) return;
    final buyerId = _requestData!['userId'];
    final price = double.tryParse(_priceController.text.trim());
    if (price == null) return;

    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(buyerId)
        .update({'proposedPrice': price, 'status': 'price_proposed'});

    setState(() {
      _requestData!['status'] = 'price_proposed';
      _requestData!['proposedPrice'] = price;
      _priceController.clear();
    });
  }

  Future<void> _respondToPrice(bool agreed) async {
    if (_requestData == null) return;
    final user = FirebaseAuth.instance.currentUser!;
    if (!agreed) {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('requests')
          .doc(user.uid)
          .update({'status': 'cancelled'});

      setState(() => _requestData = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deal cancelled')));
      return;
    }

    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(user.uid)
        .update({'buyerAgreed': true, 'status': 'buyer_agreed'});

    setState(() {
      _requestData!['status'] = 'buyer_agreed';
      _requestData!['buyerAgreed'] = true;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('You agreed to the price!')));
  }

  Future<void> _completeJob() async {
    if (_requestData == null || !_isSeller) return;
    final buyerId = _requestData!['userId'];
    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(buyerId)
        .update({'status': 'completed'});

    setState(() => _requestData!['status'] = 'completed');
  }

  void _payNow() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentPage()),
    );
  }

  Future<void> _submitReviewAndPayment() async {
    if (_requestData == null) return;
    final user = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(user.uid)
        .update({
          'paymentStatus': 'paid',
          'buyerReview': {
            'comment': _reviewController.text.trim(),
            'rating': _rating,
          },
          'status': 'done',
        });

    setState(() {
      _requestData = null;
      _selectedDate = null;
      _reviewController.clear();
      _rating = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment done & review submitted!')),
    );
  }

  void _openChat() {
    if (_ownerId == null || _requestData == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatPage(serviceId: widget.serviceId, otherUserId: _ownerId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Service Details Here',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Buyer booking
          if (!_isSeller && _requestData == null)
            Column(
              children: [
                ElevatedButton(
                  onPressed: _pickDate,
                  child: Text(
                    _selectedDate == null
                        ? 'Select Booking Date'
                        : "Booking Date: ${_selectedDate!.toLocal()}".split(
                            ' ',
                          )[0],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _requestBooking,
                  child: const Text('Request Booking'),
                ),
              ],
            ),

          // Existing request
          if (_requestData != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat'),
                ),
                const SizedBox(height: 12),

                // Seller propose price
                if (_isSeller &&
                    _requestData!['status'] == 'pending' &&
                    _requestData!['proposedPrice'] == null)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Enter proposed price',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _proposePrice,
                        child: const Text('Send'),
                      ),
                    ],
                  ),

                // Buyer accept/reject
                if (!_isSeller &&
                    _requestData!['status'] == 'price_proposed' &&
                    _requestData!['buyerAgreed'] == null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seller proposed: \$${_requestData!['proposedPrice']}',
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () => _respondToPrice(true),
                            child: const Text('Accept'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => _respondToPrice(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Reject'),
                          ),
                        ],
                      ),
                    ],
                  ),

                // Seller complete job
                if (_isSeller && _requestData!['status'] == 'buyer_agreed')
                  ElevatedButton(
                    onPressed: _completeJob,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Mark Job Completed'),
                  ),

                // Buyer pay & review
                if (!_isSeller && _requestData!['status'] == 'completed')
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _payNow,
                        child: const Text('Pay Now'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reviewController,
                        decoration: const InputDecoration(
                          hintText: 'Write your review',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Rating:'),
                          Expanded(
                            child: Slider(
                              value: _rating,
                              min: 0,
                              max: 5,
                              divisions: 5,
                              label: _rating.toString(),
                              onChanged: (val) => setState(() => _rating = val),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: _submitReviewAndPayment,
                        child: const Text('Submit Review & Done'),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Payment completed!')));
            Navigator.pop(context);
          },
          child: const Text('Pay \$100 (Sample)'),
        ),
      ),
    );
  }
}
