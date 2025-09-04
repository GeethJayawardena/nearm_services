import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'main.dart';
import 'bank_details_page.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  Map<String, dynamic>? _serviceData;
  List<Map<String, dynamic>> _reviews = [];
  final TextEditingController _priceController = TextEditingController();
  final MapController _mapController = MapController();
  double _mapZoom = 15.0;

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

    _serviceData = serviceDoc.data();
    _ownerId = serviceDoc['ownerId'];
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _isSeller = user.uid == _ownerId;

      Map<String, dynamic>? activeRequest;

      if (_isSeller) {
        final requestsSnap = await FirebaseFirestore.instance
            .collection('services')
            .doc(widget.serviceId)
            .collection('requests')
            .get();

        if (requestsSnap.docs.isNotEmpty) {
          activeRequest = requestsSnap.docs.first.data();
        }
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('services')
            .doc(widget.serviceId)
            .collection('requests')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final status = doc['status'] ?? 'pending';
          if (status != 'done' && status != 'cancelled') {
            activeRequest = doc.data();
          }
        }
      }

      // Load previous reviews
      final reviewsSnap = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('requests')
          .where('buyerReview', isNotEqualTo: null)
          .get();

      _reviews = reviewsSnap.docs
          .map(
            (d) => {
              'comment': d['buyerReview']['comment'] ?? '',
              'rating': d['buyerReview']['rating'] ?? 0,
            },
          )
          .toList();

      setState(() {
        _requestData = activeRequest;
        if (_selectedDate == null &&
            _requestData != null &&
            _requestData!['bookingDate'] != null) {
          final bd = _requestData!['bookingDate'];
          if (bd is Timestamp)
            _selectedDate = bd.toDate();
          else if (bd is DateTime)
            _selectedDate = bd;
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

    final requestRef = FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(); // auto-ID

    await requestRef.set({
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
      MaterialPageRoute(
        builder: (_) => BankDetailsPage(serviceId: widget.serviceId),
      ),
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

  void _zoomIn() {
    _mapZoom = (_mapZoom + 1).clamp(1.0, 18.0);
    if (_serviceData != null) {
      _mapController.move(
        LatLng(_serviceData!['latitude'], _serviceData!['longitude']),
        _mapZoom,
      );
    }
  }

  void _zoomOut() {
    _mapZoom = (_mapZoom - 1).clamp(1.0, 18.0);
    if (_serviceData != null) {
      _mapController.move(
        LatLng(_serviceData!['latitude'], _serviceData!['longitude']),
        _mapZoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _serviceData?['name'] ?? 'Service Name',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_serviceData?['description'] ?? 'Service Description'),
          const SizedBox(height: 8),
          Text(
            "Price: ${_serviceData?['priceMin'] ?? '-'} - ${_serviceData?['priceMax'] ?? '-'}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Flutter Map
          if (_serviceData?['latitude'] != null &&
              _serviceData?['longitude'] != null)
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(
                        _serviceData!['latitude'],
                        _serviceData!['longitude'],
                      ),
                      initialZoom: _mapZoom,
                      minZoom: 5,
                      maxZoom: 18,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.nearm_services',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _serviceData!['latitude'],
                              _serviceData!['longitude'],
                            ),
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      children: [
                        FloatingActionButton(
                          mini: true,
                          onPressed: _zoomIn,
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 4),
                        FloatingActionButton(
                          mini: true,
                          onPressed: _zoomOut,
                          child: const Icon(Icons.remove),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Booking / request actions
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

          // Existing request actions
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
                if (_isSeller && _requestData!['status'] == 'buyer_agreed')
                  ElevatedButton(
                    onPressed: _completeJob,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Mark Job Completed'),
                  ),
                if (!_isSeller && _requestData!['status'] == 'completed')
                  ElevatedButton(
                    onPressed: _payNow,
                    child: const Text('Pay Now'),
                  ),
              ],
            ),

          // Previous reviews
          if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text(
              'Previous Reviews',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Column(
              children: _reviews.map((r) {
                final comment = r['comment'] ?? '';
                final rating = r['rating'] ?? 0;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(comment),
                    subtitle: Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
