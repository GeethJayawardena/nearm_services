import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'service_details_page.dart';
import 'seller_dashboard_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSeller = false;

  @override
  void initState() {
    super.initState();
    _checkIfSeller();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NearMe Services - Home'),
        actions: [
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
                    onPressed: () {
                      Navigator.pushNamed(context, '/sell-service');
                    },
                    child: const Text('Sell a Service'),
                  ),
                ),
                if (_isSeller) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SellerDashboardPage(),
                          ),
                        );
                      },
                      child: const Text('Seller Dashboard'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('services')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final services = snap.data!.docs;
                if (services.isEmpty) {
                  return const Center(child: Text('No services found.'));
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ServiceDetailsPage(serviceId: doc.id),
                            ),
                          );
                        },
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
          final r = (m['rating'] ?? 0).toDouble();
          sum += r;
        }
        final avg = sum / docs.length;
        return Text('⭐ ${avg.toStringAsFixed(1)} (${docs.length})');
      },
    );
  }
}
