import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellServicePage extends StatefulWidget {
  const SellServicePage({super.key});

  @override
  State<SellServicePage> createState() => _SellServicePageState();
}

class _SellServicePageState extends State<SellServicePage> {
  final _formKey = GlobalKey<FormState>();
  String _category = '';
  String _serviceName = '';
  String _description = '';
  double _priceMin = 0;
  double _priceMax = 0;
  String _location = '';

  final _priceMinController = TextEditingController();
  final _priceMaxController = TextEditingController();

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to sell a service'),
        ),
      );
      return;
    }

    final ownerEmail = user.email ?? 'anonymous@user';
    final ownerName =
        (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : (user.email != null ? user.email!.split('@').first : 'Anonymous');

    await FirebaseFirestore.instance.collection('services').add({
      'ownerId': user.uid,
      'ownerEmail': ownerEmail,
      'ownerName': ownerName,
      'category': _category,
      'name': _serviceName,
      'description': _description,
      'priceMin': _priceMin,
      'priceMax': _priceMax,
      'location': _location,
      'timestamp': FieldValue.serverTimestamp(),
      // optional cached fields (not strictly needed, but useful later)
      'avgRating': 0.0,
      'ratingsCount': 0,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _priceMinController.dispose();
    _priceMaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sell a Service')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Category'),
                onSaved: (val) => _category = val!.trim(),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter category' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Service Name'),
                onSaved: (val) => _serviceName = val!.trim(),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter service name' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                onSaved: (val) => _description = val!.trim(),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter description' : null,
              ),
              TextFormField(
                controller: _priceMinController,
                decoration: const InputDecoration(labelText: 'Price Min'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter minimum price';
                  if (double.tryParse(val) == null) return 'Enter valid number';
                  return null;
                },
                onSaved: (val) => _priceMin = double.parse(val!),
              ),
              TextFormField(
                controller: _priceMaxController,
                decoration: const InputDecoration(labelText: 'Price Max'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter maximum price';
                  if (double.tryParse(val) == null) return 'Enter valid number';
                  if (_priceMinController.text.isNotEmpty &&
                      double.tryParse(_priceMinController.text)! >
                          double.tryParse(val)!) {
                    return 'Max price should be greater than min price';
                  }
                  return null;
                },
                onSaved: (val) => _priceMax = double.parse(val!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Location'),
                onSaved: (val) => _location = val!.trim(),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter location' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveService,
                child: const Text('Save Service'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
