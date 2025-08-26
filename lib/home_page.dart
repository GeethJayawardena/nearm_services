import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'service_details_page.dart';
import 'seller_dashboard_page.dart';
import 'location_selector.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSeller = false;
  String? _userDistrict;
  final List<String> _districts = [
    "All Sri Lanka",
    "Colombo",
    "Gampaha",
    "Kalutara",
    "Kandy",
    "Matale",
    "Nuwara Eliya",
    "Galle",
    "Matara",
    "Hambantota",
    "Jaffna",
    "Kilinochchi",
    "Mannar",
    "Mullaitivu",
    "Vavuniya",
    "Batticaloa",
    "Ampara",
    "Trincomalee",
    "Kurunegala",
    "Puttalam",
    "Anuradhapura",
    "Polonnaruwa",
    "Badulla",
    "Monaragala",
    "Ratnapura",
    "Kegalle",
  ];

  @override
  void initState() {
    super.initState();
    _checkIfSeller();
    _loadUserDistrict();
  }

  Future<void> _checkIfSeller() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collection('services')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      setState(() => _isSeller = true);
    }
  }

  Future<void> _loadUserDistrict() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists && userDoc.data()!.containsKey('district')) {
      setState(() => _userDistrict = userDoc.data()!['district']);
    }
  }

  Future<void> _updateUserDistrict(String district) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'district': district,
    }, SetOptions(merge: true));

    setState(() => _userDistrict = district);
  }

  Future<void> _detectLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final district = placemarks.first.administrativeArea ?? "Unknown";
        if (_districts.contains(district)) {
          await _updateUserDistrict(district);
        }
      }
    } catch (e) {
      debugPrint("Error detecting location: $e");
    }
  }

  Future<void> _chooseLocationDialog() async {
    String? selectedDistrict = _userDistrict;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Choose Location"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _detectLocation();
              },
              icon: const Icon(Icons.my_location),
              label: const Text("Use Current Location (GPS)"),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedDistrict,
              hint: const Text("Select District"),
              items: _districts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (val) => selectedDistrict = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedDistrict != null) {
                await _updateUserDistrict(selectedDistrict!);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = FirebaseAuth.instance;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await auth.signOut();
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  Stream<QuerySnapshot> _getServicesStream() {
    final collection = FirebaseFirestore.instance
        .collection('services')
        .orderBy('timestamp', descending: true);

    if (_userDistrict != null && _userDistrict != "All Sri Lanka") {
      // Filter using 'location' instead of 'district'
      return collection.where('location', isEqualTo: _userDistrict).snapshots();
    }

    // Show all services if district is null or 'All Sri Lanka'
    return collection.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NearMe Services - Home'),
        actions: [
          if (_userDistrict != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Text(
                "📍 $_userDistrict",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _chooseLocationDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/sell-service'),
                    child: const Text('Sell a Service'),
                  ),
                ),
                if (_isSeller) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SellerDashboardPage(),
                        ),
                      ),
                      child: const Text('Seller Dashboard'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getServicesStream(),
              builder: (context, snap) {
                if (snap.hasError)
                  return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());

                final services = snap.data!.docs;
                if (services.isEmpty) {
                  return Center(
                    child: Text(
                      _userDistrict != null
                          ? 'No services found in $_userDistrict.'
                          : 'No services found.',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, i) {
                    final doc = services[i];
                    final data = doc.data()! as Map<String, dynamic>;
                    final ownerName = data['ownerName'] ?? '';
                    final ownerEmail = data['ownerEmail'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(data['name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${data['category'] ?? ''} | ${data['location'] ?? ''}',
                            ),
                            Text(
                              'Price: ${data['priceMin'] ?? ''} - ${data['priceMax'] ?? ''}',
                            ),
                            Text(
                              'Owner: ${ownerName.isNotEmpty ? ownerName : ownerEmail}',
                            ),
                            const SizedBox(height: 4),
                            AverageRatingLine(serviceId: doc.id),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ServiceDetailsPage(serviceId: doc.id),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AverageRatingLine extends StatelessWidget {
  final String serviceId;
  const AverageRatingLine({super.key, required this.serviceId});

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
