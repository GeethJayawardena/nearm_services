import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditServicePage extends StatefulWidget {
  final String serviceId;
  final Map<String, dynamic> serviceData;

  const EditServicePage({
    super.key,
    required this.serviceId,
    required this.serviceData,
  });

  @override
  State<EditServicePage> createState() => _EditServicePageState();
}

class _EditServicePageState extends State<EditServicePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _priceMinController;
  late TextEditingController _priceMaxController;

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

  late String? _category;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.serviceData["name"] ?? "",
    );
    _descriptionController = TextEditingController(
      text: widget.serviceData["description"] ?? "",
    );
    _locationController = TextEditingController(
      text: widget.serviceData["location"] ?? "",
    );
    _priceMinController = TextEditingController(
      text: widget.serviceData["priceMin"]?.toString() ?? "",
    );
    _priceMaxController = TextEditingController(
      text: widget.serviceData["priceMax"]?.toString() ?? "",
    );

    _category = _categories.contains(widget.serviceData["category"])
        ? widget.serviceData["category"]
        : null;
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection("services")
          .doc(widget.serviceId)
          .update({
            "name": _nameController.text.trim(),
            "description": _descriptionController.text.trim(),
            "location": _locationController.text.trim(),
            "priceMin": int.tryParse(_priceMinController.text.trim()) ?? 0,
            "priceMax": int.tryParse(_priceMaxController.text.trim()) ?? 0,
            "category": _category ?? "Other",
            "timestamp": FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service updated successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteService() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Service"),
        content: const Text("Are you sure you want to delete this service?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection("services")
          .doc(widget.serviceId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service deleted successfully")),
        );
        Navigator.pop(context); // go back after deletion
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Service"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteService,
            tooltip: "Delete Service",
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _category,
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _category = value);
                      },
                      decoration: const InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Service Name",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Please enter a name" : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: "Location",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _priceMinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Minimum Price",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _priceMaxController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Maximum Price",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveService,
                            child: const Text("Save"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
