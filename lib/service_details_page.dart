import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'bank_details_page.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

class ServiceDetailsPage extends StatefulWidget {
  final String serviceId;
  const ServiceDetailsPage({super.key, required this.serviceId});

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage>
    with RouteAware {
  Map<String, dynamic>? _requestData;
  Map<String, dynamic>? _sellerData;
  bool _isSeller = false;
  String? _ownerId;
  DateTime? _selectedDate;
  Map<String, dynamic>? _serviceData;
  List<Map<String, dynamic>> _reviews = [];
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 0;
  final MapController _mapController = MapController();
  double _mapZoom = 15.0;

  // Location & distance
  double? _roadDistanceKm;
  bool _loadingDistance = false;
  double? _userLat;
  double? _userLng;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    // Load service + seller data. DO NOT auto-fetch buyer location here.
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
    _reviewController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadServiceData();
  }

  // ------------------ Firestore Data ------------------
  Future<void> _loadServiceData() async {
    final serviceDoc = await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .get();
    if (!serviceDoc.exists) return;

    _serviceData = serviceDoc.data();
    _ownerId = serviceDoc['ownerId'];

    // Load seller info from Firestore
    final sellerDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_ownerId)
        .get();

    if (sellerDoc.exists) {
      _sellerData = sellerDoc.data();

      // Convert local profileImage path to File if exists
      try {
        if (_sellerData != null &&
            _sellerData!['profileImage'] != null &&
            !_sellerData!['profileImage'].toString().startsWith('http')) {
          final path = _sellerData!['profileImage'].toString();
          final file = File(path);
          if (await file.exists()) {
            _sellerData!['profileImageFile'] = file;
          }
        }
      } catch (e) {
        // ignore file read errors
      }
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _isSeller = user.uid == _ownerId;
      await _loadActiveRequest(user.uid);
      await _loadReviews();
    }

    if (mounted) setState(() {});
  }

  Future<void> _cancelBooking() async {
    if (_requestData == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = _requestData!['userId'];

    // Update Firestore
    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(userId)
        .update({'status': 'cancelled'});

    // Update local state to hide the request
    setState(() {
      _requestData = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Booking cancelled')));
  }

  Future<void> _loadActiveRequest(String userId) async {
    Map<String, dynamic>? activeRequest;

    if (_isSeller) {
      final requestsSnap = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('requests')
          .get();
      if (requestsSnap.docs.isNotEmpty)
        activeRequest = requestsSnap.docs.first.data();
    } else {
      final doc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .collection('requests')
          .doc(userId)
          .get();
      if (doc.exists) {
        final status = doc['status'] ?? 'pending';
        if (status != 'done' && status != 'cancelled')
          activeRequest = doc.data();
      }
    }

    setState(() {
      _requestData = activeRequest;
      if (_selectedDate == null &&
          _requestData != null &&
          _requestData!['bookingDate'] != null) {
        final bd = _requestData!['bookingDate'];
        _selectedDate = bd is Timestamp ? bd.toDate() : bd as DateTime?;
      }
    });
  }

  Future<void> _loadReviews() async {
    final reviewsSnap = await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .where('buyerReview', isNotEqualTo: null)
        .get();

    setState(() {
      _reviews = reviewsSnap.docs
          .map(
            (d) => {
              'comment': d['buyerReview']['comment'] ?? '',
              'rating': d['buyerReview']['rating'] ?? 0,
            },
          )
          .toList();
    });
  }

  // ------------------ Booking / Request ------------------
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
    if (user == null || _ownerId == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a booking date")),
      );
      return;
    }

    final serviceRef = FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests');

    // Check if this date is already booked
    final existing = await serviceRef
        .where('bookingDate', isEqualTo: Timestamp.fromDate(_selectedDate!))
        .where(
          'status',
          whereIn: ['pending', 'price_proposed', 'buyer_agreed', 'completed'],
        )
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Seller not available on this date")),
      );
      return;
    }

    // Save booking request (use user id as doc id to avoid duplicates)
    final requestRef = serviceRef.doc(user.uid);
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

  Future<void> _submitReview() async {
    if (_reviewController.text.trim().isEmpty || _selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a rating and comment')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    final reviewData = {
      'rating': _selectedRating,
      'comment': _reviewController.text.trim(),
      'userId': user.uid,
      'userName': user.displayName ?? user.email,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // 1) Save inside requests for buyer tracking
    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('requests')
        .doc(user.uid)
        .update({'buyerReview': reviewData});

    // 2) Save in separate 'reviews' collection for easy HomePage queries
    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .collection('reviews')
        .add(reviewData);

    setState(() {
      _requestData!['buyerReview'] = reviewData;
      _reviews.add(reviewData);
      _reviewController.clear();
      _selectedRating = 0;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Review submitted!')));
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

  // ------------------ Map / Location ------------------
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

  /// Called when user presses "My Location".
  /// This captures buyer location locally (NOT saved to Firestore),
  /// computes route & distance to seller, and updates the map.
  Future<void> _captureBuyerLocation() async {
    setState(() => _loadingDistance = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied. Please enable them in settings.',
            ),
          ),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _userLat = pos.latitude;
      _userLng = pos.longitude;

      // Compute route & distance (using OpenRouteService)
      if (_serviceData != null) {
        final route = await _getRoadRoute(
          _userLat!,
          _userLng!,
          _serviceData!['latitude'],
          _serviceData!['longitude'],
        );

        if (route != null && route.isNotEmpty) {
          _routePoints = route;
          final distanceKm = await _getRoadDistance(
            _userLat!,
            _userLng!,
            _serviceData!['latitude'],
            _serviceData!['longitude'],
          );
          setState(() => _roadDistanceKm = distanceKm);
        } else {
          // fallback: draw straight line between the two points
          _routePoints = [
            LatLng(_userLat!, _userLng!),
            LatLng(_serviceData!['latitude'], _serviceData!['longitude']),
          ];
        }

        // Move center to midpoint of buyer & seller for better view
        final center = LatLng(
          (_userLat! + _serviceData!['latitude']) / 2,
          (_userLng! + _serviceData!['longitude']) / 2,
        );
        _mapController.move(center, 12);
      } else {
        // If no service data, center on buyer only
        _mapController.move(LatLng(_userLat!, _userLng!), 14);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    } finally {
      if (mounted) setState(() => _loadingDistance = false);
    }
  }

  Future<double?> _getRoadDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    const apiKey =
        'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImIzNGNjNTEwZjNkOTQ3ZjZiZDQ0NmJmNGQ5NTg2ZTQ1IiwiaCI6Im11cm11cjY0In0=';
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=$startLng,$startLat&end=$endLng,$endLat';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final distanceMeters =
            data['features'][0]['properties']['segments'][0]['distance'];
        return distanceMeters / 1000;
      }
      return null;
    } catch (e) {
      // ignore or log
      debugPrint('Error fetching road distance: $e');
      return null;
    }
  }

  Future<List<LatLng>?> _getRoadRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    const apiKey =
        'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImIzNGNjNTEwZjNkOTQ3ZjZiZDQ0NmJmNGQ5NTg2ZTQ1IiwiaCI6Im11cm11cjY0In0=';
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=$startLng,$startLat&end=$endLng,$endLat';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['features'][0]['geometry']['coordinates'] as List;
        return coords.map((c) => LatLng(c[1], c[0])).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching road route: $e');
      return null;
    }
  }

  // ------------------ UI ------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Service Details'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Service Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _serviceData?['name'] ?? 'Service Name',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _serviceData?['description'] ?? 'Service Description',
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  "Price: ${_serviceData?['priceMin'] ?? '-'} - ${_serviceData?['priceMax'] ?? '-'}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (_roadDistanceKm != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Distance: ${_roadDistanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Seller Info Card
          if (_sellerData != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: _sellerData!['profileImageFile'] != null
                        ? FileImage(_sellerData!['profileImageFile'] as File)
                        : (_sellerData!['profilePic'] != null
                              ? NetworkImage(_sellerData!['profilePic'])
                              : const AssetImage('assets/default_avatar.png')
                                    as ImageProvider),
                  ),

                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sellerData!['name'] ?? 'Seller Name',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sellerData!['email'] ?? 'Seller Email',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sellerData!['contact'] ??
                              'Contact number not available',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Map Section
          if (_serviceData?['latitude'] != null &&
              _serviceData?['longitude'] != null)
            SizedBox(
              height: 300,
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
                      onPositionChanged: (pos, _) {
                        _mapZoom = pos.zoom ?? _mapZoom;
                      },
                    ),

                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.nearm_services',
                      ),
                      MarkerLayer(
                        markers: [
                          // Seller marker (red) - ALWAYS visible
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

                          // Buyer marker (blue) - only visible after pressing "My Location"
                          if (_userLat != null && _userLng != null)
                            Marker(
                              point: LatLng(_userLat!, _userLng!),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.person_pin_circle,
                                color: Colors.blue,
                                size: 40,
                              ),
                            ),
                        ],
                      ),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              color: Colors.greenAccent,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                    ],
                  ),

                  // Zoom control buttons
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

                  // My Location button (bottom-right)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FloatingActionButton.extended(
                      onPressed: _loadingDistance
                          ? null
                          : _captureBuyerLocation,
                      icon: _loadingDistance
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.my_location),
                      label: const Text('My Location'),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Booking / Request Section
          if (!_isSeller && _requestData == null)
            Column(
              children: [
                ElevatedButton(
                  onPressed: _pickDate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? 'Select Booking Date'
                        : "Booking Date: ${_selectedDate!.toLocal()}".split(
                            ' ',
                          )[0],
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _requestBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Request Booking',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),

          if (_requestData != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  label: const Text('Chat'),
                ),
                const SizedBox(height: 12),
                // Only for buyers and pending requests
                if (!_isSeller && _requestData!['status'] == 'pending')
                  ElevatedButton(
                    onPressed: _cancelBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Cancel Booking'),
                  ),

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

                if (!_isSeller &&
                    _requestData!['status'] == 'completed' &&
                    _requestData!['buyerReview'] == null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'Leave a Review',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < _selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                            ),
                            onPressed: () {
                              setState(() => _selectedRating = index + 1);
                            },
                          );
                        }),
                      ),
                      TextField(
                        controller: _reviewController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Write your review here',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Submit Review'),
                      ),
                    ],
                  ),

                if (!_isSeller &&
                    _requestData!['status'] == 'completed' &&
                    _requestData!['buyerReview'] != null)
                  ElevatedButton(
                    onPressed: _payNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: const Text('Pay Now'),
                  ),
              ],
            ),

          if (_reviews.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text(
              'Previous Reviews',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: _reviews.map((r) {
                final comment = r['comment'] ?? '';
                final rating = r['rating'] ?? 0;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
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
