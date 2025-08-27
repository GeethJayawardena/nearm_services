import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDetailsPage extends StatelessWidget {
  final String userId;

  const UserDetailsPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Selling Services",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildSellingList(),
            const SizedBox(height: 24),
            const Text(
              "Buying History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildBuyingList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSellingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .where('ownerId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final services = snapshot.data!.docs;

        if (services.isEmpty) return const Text("No selling services.");

        return Column(
          children: services.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['name'] ?? ''),
              subtitle: Text(
                "Price: ${data['priceMin']} - ${data['priceMax']}",
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBuyingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('purchases')
          .where('buyerId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final purchases = snapshot.data!.docs;

        if (purchases.isEmpty) return const Text("No buying history.");

        return Column(
          children: purchases.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text("Bought: ${data['serviceName']}"),
              subtitle: Text("From: ${data['sellerName']}"),
            );
          }).toList(),
        );
      },
    );
  }
}
