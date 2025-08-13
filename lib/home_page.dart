import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  double _calculateAverageRating(List<dynamic>? ratings) {
    if (ratings == null || ratings.isEmpty) return 0;
    double sum = ratings.fold(0, (prev, rating) => prev + rating);
    return sum / ratings.length;
  }

  Future<void> _rateService(String serviceId, double rating) async {
    final serviceRef = FirebaseFirestore.instance
        .collection('services')
        .doc(serviceId);
    await serviceRef.update({
      'ratings': FieldValue.arrayUnion([rating]),
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NearMe Services - Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/sell-service');
              },
              child: const Text('Sell a Service'),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('services')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final services = snapshot.data!.docs;

                if (services.isEmpty) {
                  return const Center(child: Text('No services found.'));
                }

                return ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final data = service.data()! as Map<String, dynamic>;
                    final avgRating = _calculateAverageRating(data['ratings']);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(data['name'] ?? ''),
                        subtitle: Text(
                          '${data['category'] ?? ''} | ${data['location'] ?? ''}\n'
                          'Price: ${data['priceMin']} - ${data['priceMax']}\n'
                          'By: ${data['ownerEmail'] ?? 'Unknown'}\n'
                          'Rating: ${avgRating.toStringAsFixed(1)} ⭐\n'
                          '${data['description'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.star, color: Colors.amber),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                double selectedRating = 3;
                                return AlertDialog(
                                  title: const Text('Rate Service'),
                                  content: StatefulBuilder(
                                    builder: (context, setState) {
                                      return Slider(
                                        value: selectedRating,
                                        min: 1,
                                        max: 5,
                                        divisions: 4,
                                        label: selectedRating.toString(),
                                        onChanged: (val) {
                                          setState(() {
                                            selectedRating = val;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await _rateService(
                                          service.id,
                                          selectedRating,
                                        );
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Submit'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
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
