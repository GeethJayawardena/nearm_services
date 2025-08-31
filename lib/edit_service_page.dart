import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditServicePage extends StatefulWidget {
  final String serviceId;
  const EditServicePage({super.key, required this.serviceId});

  @override
  State<EditServicePage> createState() => _EditServicePageState();
}

class _EditServicePageState extends State<EditServicePage> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController _nameController = TextEditingController();
  TextEditingController _descController = TextEditingController();
  TextEditingController _priceMinController = TextEditingController();
  TextEditingController _priceMaxController = TextEditingController();
  TextEditingController _locationController = TextEditingController();
  String? _category;

  final List<String> _categories = [
    'Cleaning',
    'Plumbing',
    'Electrical',
    'Delivery',
    'Other',
  ];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadService();
  }

  Future<void> _loadService() async {
    final doc = await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameController.text = data['name'] ?? '';
        _descController.text = data['description'] ?? '';
        _priceMinController.text = data['priceMin']?.toString() ?? '';
        _priceMaxController.text = data['priceMax']?.toString() ?? '';
        _locationController.text = data['location'] ?? '';
        _category = data['category'];
        _loading = false;
      });
    }
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    await FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .set({
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'priceMin': double.tryParse(_priceMinController.text.trim()) ?? 0,
          'priceMax': double.tryParse(_priceMaxController.text.trim()) ?? 0,
          'location': _locationController.text.trim(),
          'category': _category,
        }, SetOptions(merge: true));

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Service updated')));
    Navigator.pop(context);
  }

  Future<void> _deleteService() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content: const Text(
          'Are you sure you want to delete this service? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .delete();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Service deleted')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Add Firestore category to dropdown if it's not already in the list
    final categoriesWithCustom = Set<String>.from(_categories);
    if (_category != null) categoriesWithCustom.add(_category!);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Service Name'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceMinController,
                decoration: const InputDecoration(labelText: 'Min Price'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceMaxController,
                decoration: const InputDecoration(labelText: 'Max Price'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: categoriesWithCustom.contains(_category)
                    ? _category
                    : null,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categoriesWithCustom
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveService,
                child: const Text('Save Changes'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _deleteService,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete Service'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
