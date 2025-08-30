import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'service_details_page.dart';
import 'seller_dashboard_page.dart';
import 'sell_service_page.dart';
import 'admin_dashboard.dart';

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

  Stream<List<QueryDocumentSnapshot>> _getServicesStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final collection = FirebaseFirestore.instance
        .collection('services')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return collection.map((snap) {
      return snap.docs.where((doc) {
        final data = doc.data()! as Map<String, dynamic>;
        if (currentUser != null && data['ownerId'] == currentUser.uid)
          return false;
        if (_userDistrict != null &&
            _userDistrict != "All Sri Lanka" &&
            data['location'] != _userDistrict)
          return false;
        return true;
      }).toList();
    });
  }

  Stream<QuerySnapshot> _getNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('notifications')
        .where('ownerId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  void _openNotificationsDialog(List<QueryDocumentSnapshot> notifications) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Notifications"),
        content: SizedBox(
          width: double.maxFinite,
          child: notifications.isEmpty
              ? const Text("No notifications")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final doc = notifications[index];
                    final data = doc.data()! as Map<String, dynamic>;
                    final userName = data['userName'] ?? 'Someone';
                    final type = data['type'] ?? 'Notification';

                    return ListTile(
                      title: Text('$userName - $type'),
                      subtitle: Text(
                        data['timestamp'] != null
                            ? (data['timestamp'] as Timestamp)
                                  .toDate()
                                  .toString()
                            : '',
                      ),
                      onTap: () {
                        Navigator.pop(ctx); // close the dialog

                        // If it's a booking request, go to SellerDashboard
                        if (data['type'] == 'booking_request' &&
                            data['serviceId'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SellerDashboardPage(
                                focusServiceId: data['serviceId'],
                              ),
                            ),
                          );
                        }
                        // Otherwise, go to ServiceDetailsPage
                        else if (data['serviceId'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ServiceDetailsPage(
                                serviceId: data['serviceId'],
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_role == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
          StreamBuilder<QuerySnapshot>(
            stream: _getNotifications(),
            builder: (context, snap) {
              int unreadCount = 0;
              if (snap.hasData) unreadCount = snap.data!.docs.length;

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      // ✅ Navigate to Seller Dashboard instead of popup
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SellerDashboardPage(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
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
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _getServicesStream(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());

          final services = snap.data!;
          if (services.isEmpty)
            return Center(
              child: Text(
                _userDistrict != null
                    ? 'No services found in $_userDistrict.'
                    : 'No services found.',
                style: const TextStyle(fontSize: 16),
              ),
            );

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
