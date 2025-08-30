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

  // Category list
  final List<String> _categories = [
    'Electrician',
    'Plumber',
    'Carpenter',
    'Cleaner / Housemaid',
    'Cook / Home Chef',
    'Babysitter / Nanny',
    'Gardener',
    'Mechanic (Bike/Car)',
    'Washer / Laundry Helper',
    'AC Repair Technician',
    'Painter',
    'Mason / Construction Helper',
    'Pest Control',
    'Delivery Helper',
    'Elderly Caregiver',
  ];
  String? _category; // Selected category

  String _serviceName = '';
  String _description = '';
  String _location = '';
  bool _loadingLocation = false;

  // Price Range
  double _priceMinValue = 0;
  double _priceMaxValue = 1000;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a location')));
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
      'priceMin': _priceMinValue,
      'priceMax': _priceMaxValue,
      'location': _location,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sell a Service')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // 🔹 Category Dropdown
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((String cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _category = val);
                    },
                    validator: (val) => val == null || val.isEmpty
                        ? 'Please select a category'
                        : null,
                    onSaved: (val) => _category = val,
                  ),
                  const SizedBox(height: 16),

                  // Service Name
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Service Name',
                      prefixIcon: Icon(Icons.build_circle),
                    ),
                    onSaved: (val) => _serviceName = val!.trim(),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Enter service name'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                    onSaved: (val) => _description = val!.trim(),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Enter description' : null,
                  ),
                  const SizedBox(height: 24),

                  // 🔹 Price Range
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price Range: ${_priceMinValue.toStringAsFixed(0)} - ${_priceMaxValue.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      RangeSlider(
                        min: 0,
                        max: 10000,
                        divisions: 100,
                        values: RangeValues(_priceMinValue, _priceMaxValue),
                        labels: RangeLabels(
                          _priceMinValue.toStringAsFixed(0),
                          _priceMaxValue.toStringAsFixed(0),
                        ),
                        onChanged: (RangeValues values) {
                          setState(() {
                            _priceMinValue = values.start.roundToDouble();
                            _priceMaxValue = values.end.roundToDouble();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 🔹 Location row: GPS + Dropdown
                  Row(
                    children: [
                      IconButton(
                        icon: _loadingLocation
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.my_location, color: Colors.blue),
                        onPressed: _loadingLocation ? null : _detectLocation,
                      ),
                      Expanded(
                        child: LocationSelector(
                          selectedLocation: _location,
                          onLocationSelected: (val) {
                            setState(() => _location = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 🔹 Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Save Service',
                        style: TextStyle(fontSize: 18),
                      ),
                      onPressed: _saveService,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
