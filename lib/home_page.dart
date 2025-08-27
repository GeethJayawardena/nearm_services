import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'service_details_page.dart';
import 'seller_dashboard_page.dart';
import 'sell_service_page.dart';
import 'admin_dashboard.dart'; // Make sure you have this page

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSeller = false;
  String? _userDistrict;
  String? _role;

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
    _checkUserRole();
    _loadUserDistrict();
  }

  /// 🔹 Check if user is admin, seller, or normal
  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final role = userDoc.data()?['role'] ?? 'user';
      setState(() => _role = role);

      if (role == 'admin') {
        // Auto-redirect admin to Admin Dashboard
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        });
        return;
      }

      if (role == 'seller') {
        setState(() => _isSeller = true);
      }
    } else {
      // If user doc doesn't exist, treat as normal user
      setState(() => _role = 'user');
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
        if (_districts.contains(district)) await _updateUserDistrict(district);
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
              if (selectedDistrict != null)
                await _updateUserDistrict(selectedDistrict!);
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
      return collection.where('location', isEqualTo: _userDistrict).snapshots();
    }

    return collection.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // While loading role or redirecting admin, show a loader
    if (_role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('NearMe Services'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SellServicePage()),
        ),
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, size: 28),
        tooltip: 'Sell a Service',
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getServicesStream(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());

          final services = snap.data!.docs;
          if (services.isEmpty) {
            return Center(
              child: Text(
                _userDistrict != null
                    ? 'No services found in $_userDistrict.'
                    : 'No services found.',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: services.length,
            itemBuilder: (context, i) {
              final doc = services[i];
              final data = doc.data()! as Map<String, dynamic>;
              final ownerName = data['ownerName'] ?? '';
              final ownerEmail = data['ownerEmail'] ?? '';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceDetailsPage(serviceId: doc.id),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          Chip(
                            label: Text(data['category'] ?? ''),
                            backgroundColor: Colors.blue.shade50,
                          ),
                          Chip(
                            label: Text(data['location'] ?? ''),
                            backgroundColor: Colors.green.shade50,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Price: ${data['priceMin'] ?? ''} - ${data['priceMax'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Owner: ${ownerName.isNotEmpty ? ownerName : ownerEmail}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      AverageRatingLine(serviceId: doc.id),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _isSeller
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SellerDashboardPage(),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: theme.primaryColor,
                ),
                child: const Text(
                  'Seller Dashboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            )
          : null,
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
