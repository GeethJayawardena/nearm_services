import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;

      // 1️⃣ Delete user's profile document
      await firestore.collection('users').doc(user.uid).delete();

      // 2️⃣ Delete all services created by the user (and their requests)
      final servicesSnap = await firestore
          .collection('services')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      for (var serviceDoc in servicesSnap.docs) {
        // Delete all requests under this service
        final requestsSnap = await serviceDoc.reference
            .collection('requests')
            .get();
        for (var reqDoc in requestsSnap.docs) {
          await reqDoc.reference.delete();
        }
        await serviceDoc.reference.delete();
      }

      // 3️⃣ Delete all requests where user is a buyer
      final allServicesSnap = await firestore.collection('services').get();
      for (var serviceDoc in allServicesSnap.docs) {
        final buyerRequestsSnap = await serviceDoc.reference
            .collection('requests')
            .where('userId', isEqualTo: user.uid)
            .get();
        for (var reqDoc in buyerRequestsSnap.docs) {
          await reqDoc.reference.delete();
        }
      }

      // 4️⃣ Delete user from Firebase Auth
      await user.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account and all related data deleted!')),
      );

      Navigator.of(context).pushReplacementNamed('/login'); // Your login route
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Are you sure you want to delete your account? '
              'All your services, bookings, and requests will be permanently removed!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _deleteAccount(context),
              child: const Text('Delete Account Permanently'),
            ),
          ],
        ),
      ),
    );
  }
}
