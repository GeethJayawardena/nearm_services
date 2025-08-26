import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'location_selector.dart';

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

  bool _loadingLocation = false;

  final _priceMinController = TextEditingController();
  final _priceMaxController = TextEditingController();

  /// 🔹 Get location automatically using GPS
  Future<void> _detectLocation() async {
    setState(() => _loadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          setState(() => _loadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );

      if (placemarks.isNotEmpty) {
        String? district =
            placemarks[0].subAdministrativeArea ??
            placemarks[0].administrativeArea ??
            placemarks[0].locality;

        if (district != null && district.isNotEmpty) {
          setState(() => _location = district);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to detect location: $e')));
    } finally {
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or detect a location')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
      'location': _location, // ✅ Auto/manual district saved
      'timestamp': FieldValue.serverTimestamp(),
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
                  if (val == null || val.isEmpty) {
                    return 'Enter minimum price';
                  }
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
                  if (val == null || val.isEmpty) {
                    return 'Enter maximum price';
                  }
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

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _location.isEmpty
                          ? 'No location selected'
                          : 'Selected: $_location',
                    ),
                  ),
                  IconButton(
                    icon: _loadingLocation
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.my_location, color: Colors.blue),
                    onPressed: _loadingLocation ? null : _detectLocation,
                  ),
                ],
              ),

              // 🔹 Manual selection fallback
              LocationSelector(
                onLocationSelected: (district) {
                  setState(() => _location = district);
                },
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
