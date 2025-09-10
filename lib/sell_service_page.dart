import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SellServicePage extends StatefulWidget {
  const SellServicePage({super.key});

  @override
  State<SellServicePage> createState() => _SellServicePageState();
}

class _SellServicePageState extends State<SellServicePage> {
  final _formKey = GlobalKey<FormState>();

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
  String? _category;
  String _serviceName = '';
  String _description = '';
  bool _loadingLocation = false;

  double _priceMinValue = 0;
  double _priceMaxValue = 1000;

  String? _district;
  double? _latitude;
  double? _longitude;

  final MapController _mapController = MapController();
  double _mapZoom = 15.0;

  final double defaultLat = 7.8731;
  final double defaultLng = 80.7718;

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

      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(_latitude!, _longitude!), _mapZoom);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live location captured successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    } finally {
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_district == null || _district!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a district')));
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture live location')),
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
      'priceMin': _priceMinValue,
      'priceMax': _priceMaxValue,
      'district': _district, // existing field
      'location': _district, // new field for same district
      'latitude': _latitude,
      'longitude': _longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  void _zoomIn() {
    setState(() {
      _mapZoom = (_mapZoom + 1).clamp(1.0, 18.0);
      if (_latitude != null && _longitude != null) {
        _mapController.move(LatLng(_latitude!, _longitude!), _mapZoom);
      }
    });
  }

  void _zoomOut() {
    setState(() {
      _mapZoom = (_mapZoom - 1).clamp(1.0, 18.0);
      if (_latitude != null && _longitude != null) {
        _mapController.move(LatLng(_latitude!, _longitude!), _mapZoom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sell a Service',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Category
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      prefixIcon: const Icon(
                        Icons.category,
                        color: Colors.deepPurple,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _categories
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _category = val),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Please select category'
                        : null,
                    onSaved: (val) => _category = val,
                  ),
                  const SizedBox(height: 16),

                  // Service Name
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Service Name',
                      prefixIcon: const Icon(
                        Icons.build_circle,
                        color: Colors.deepPurple,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSaved: (val) => _serviceName = val!.trim(),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Enter service name'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: const Icon(
                        Icons.description,
                        color: Colors.deepPurple,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 3,
                    onSaved: (val) => _description = val!.trim(),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Enter description' : null,
                  ),
                  const SizedBox(height: 24),

                  // Price Range
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: Colors.purple.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price Range: ${_priceMinValue.toStringAsFixed(0)} - ${_priceMaxValue.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.deepPurple,
                            ),
                          ),
                          RangeSlider(
                            min: 0,
                            max: 10000,
                            divisions: 100,
                            activeColor: Colors.deepPurple,
                            inactiveColor: Colors.purple[100],
                            values: RangeValues(_priceMinValue, _priceMaxValue),
                            labels: RangeLabels(
                              _priceMinValue.toStringAsFixed(0),
                              _priceMaxValue.toStringAsFixed(0),
                            ),
                            onChanged: (values) {
                              setState(() {
                                _priceMinValue = values.start.roundToDouble();
                                _priceMaxValue = values.end.roundToDouble();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // District
                  DropdownButtonFormField<String>(
                    value: _district,
                    decoration: InputDecoration(
                      labelText: 'District',
                      prefixIcon: const Icon(
                        Icons.location_on,
                        color: Colors.deepPurple,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items:
                        [
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
                            ]
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                    onChanged: (val) => setState(() => _district = val),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Please select district'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Capture Live Location
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: _loadingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                                color: Colors.white,
                              ),
                        label: const Text('Capture Live Location'),
                        onPressed: _loadingLocation ? null : _detectLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_latitude != null && _longitude != null) ...[
                        const SizedBox(width: 16),
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 4),
                        const Text(
                          'Location captured',
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Map with manual selection
                  SizedBox(
                    height: 300,
                    child: Stack(
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: LatLng(
                                  _latitude ?? defaultLat,
                                  _longitude ?? defaultLng,
                                ),
                                initialZoom: _mapZoom,
                                onTap: (tapPosition, point) {
                                  setState(() {
                                    _latitude = point.latitude;
                                    _longitude = point.longitude;
                                  });
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.example.nearm_services',
                                ),
                                MarkerLayer(
                                  markers: [
                                    if (_latitude != null && _longitude != null)
                                      Marker(
                                        point: LatLng(_latitude!, _longitude!),
                                        width: 50,
                                        height: 50,
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.red,
                                          size: 40,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Column(
                            children: [
                              FloatingActionButton(
                                mini: true,
                                backgroundColor: Colors.deepPurple,
                                onPressed: _zoomIn,
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton(
                                mini: true,
                                backgroundColor: Colors.deepPurple,
                                onPressed: _zoomOut,
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save, color: Colors.white),
                      label: const Text(
                        'Save Service',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      onPressed: _saveService,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
