import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home_page.dart'; // for AverageRatingLine class

class AdminUserDetailsPage extends StatefulWidget {
  final String userId;
  const AdminUserDetailsPage({super.key, required this.userId});

  @override
  State<AdminUserDetailsPage> createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends State<AdminUserDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildSellerAds() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .where('ownerId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final services = snap.data!.docs;
        if (services.isEmpty) return const Center(child: Text('No ads found.'));

        return ListView.builder(
          itemCount: services.length,
          itemBuilder: (context, index) {
            final doc = services[index];
            final data = doc.data()! as Map<String, dynamic>;
            final ownerName = data['ownerName'] ?? '';
            final ownerEmail = data['ownerEmail'] ?? '';

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(data['name'] ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data['category'] ?? ''} | ${data['location'] ?? ''}',
                    ),
                    Text('Price: ${data['priceMin']} - ${data['priceMax']}'),
                    Text(
                      'Owner: ${ownerName.isNotEmpty ? ownerName : ownerEmail}',
                    ),
                    const SizedBox(height: 4),
                    AverageRatingLine(serviceId: doc.id),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBuyerHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('buyerId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final orders = snap.data!.docs;
        if (orders.isEmpty)
          return const Center(child: Text('No purchases found.'));

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data()! as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text(data['serviceName'] ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Category: ${data['category'] ?? ''}'),
                    Text('Seller: ${data['sellerName'] ?? ''}'),
                    Text('Price Paid: ${data['price'] ?? ''}'),
                    Text('Timestamp: ${data['timestamp'] ?? ''}'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Details"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Seller Ads"),
            Tab(text: "Buyer History"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSellerAds(), _buildBuyerHistory()],
      ),
    );
  }
}
