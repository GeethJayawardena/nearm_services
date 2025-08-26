import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

Future<Position?> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) return null;

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return null;
  }
  if (permission == LocationPermission.deniedForever) return null;

  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}

Future<String?> getDistrictFromCoordinates(Position pos) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );
    if (placemarks.isNotEmpty) {
      return placemarks.first.subAdministrativeArea;
    }
  } catch (e) {
    print('Error fetching district: $e');
  }
  return null;
}

class LocationSelector extends StatefulWidget {
  final Function(String) onLocationSelected;
  final String? initialValue;
  const LocationSelector({
    super.key,
    required this.onLocationSelected,
    this.initialValue,
  });

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  String? _selectedDistrict;
  bool _loadingGPS = false;

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
    _selectedDistrict = widget.initialValue;
  }

  Future<void> _useGPS() async {
    setState(() => _loadingGPS = true);
    final pos = await getCurrentLocation();
    if (pos != null) {
      final district = await getDistrictFromCoordinates(pos);
      if (district != null) {
        setState(() => _selectedDistrict = district);
        widget.onLocationSelected(district);
      }
    }
    setState(() => _loadingGPS = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          icon: _loadingGPS
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.my_location),
          label: const Text('Use Current Location'),
          onPressed: _loadingGPS ? null : _useGPS,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedDistrict,
          hint: const Text('Select your district manually'),
          items: _districts
              .map((d) => DropdownMenuItem(value: d, child: Text(d)))
              .toList(),
          onChanged: (val) {
            setState(() => _selectedDistrict = val);
            if (val != null) widget.onLocationSelected(val);
          },
        ),
      ],
    );
  }
}
