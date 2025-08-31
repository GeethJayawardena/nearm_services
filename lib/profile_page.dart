import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _bankFormKey = GlobalKey<FormState>();

  late TabController _tabController;

  // Profile fields
  TextEditingController _nameController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _addressController = TextEditingController();
  String? _district;
  bool _editingProfile = false;

  // Bank fields
  String? _bankName;
  TextEditingController _accountController = TextEditingController();
  TextEditingController _cardController = TextEditingController();
  TextEditingController _expiryController = TextEditingController();
  TextEditingController _cvvController = TextEditingController();
  bool _editingBank = false;

  List<String> _districts = [
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

  List<String> _banksSriLanka = [
    'Bank of Ceylon',
    'Commercial Bank',
    'Sampath Bank',
    'People\'s Bank',
    'Hatton National Bank',
    'Nations Trust Bank',
    'DFCC Bank',
    'Pan Asia Bank',
    'Union Bank',
    'Seylan Bank',
    'Amana Bank',
    'NTB Bank',
    'DFCC Vardhana Bank',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _nameController.text = data['name'] ?? '';
        _emailController.text = user.email ?? '';
        _addressController.text = data['address'] ?? '';
        _district = data['district'] ?? 'All Sri Lanka';
        _bankName = data['bankName'];
        _accountController.text = data['accountNumber'] ?? '';
        _cardController.text = data['cardNumber'] ?? '';
        _expiryController.text = data['expiryDate'] ?? '';
        _cvvController.text = data['cvv'] ?? '';
      });
    } else {
      setState(() {
        _emailController.text = user.email ?? '';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'district': _district,
    }, SetOptions(merge: true));

    setState(() => _editingProfile = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile saved')));
  }

  Future<void> _saveBankDetails() async {
    if (!_bankFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'bankName': _bankName,
      'accountNumber': _accountController.text.trim(),
      'cardNumber': _cardController.text.trim(),
      'expiryDate': _expiryController.text.trim(),
      'cvv': _cvvController.text.trim(),
    }, SetOptions(merge: true));

    setState(() => _editingBank = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bank details saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Dashboard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Section
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Profile Info',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _editingProfile = !_editingProfile,
                                ),
                                child: Text(
                                  _editingProfile ? 'Cancel' : 'Edit',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                            readOnly: !_editingProfile,
                            validator: (val) => (val == null || val.isEmpty)
                                ? 'Enter name'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            readOnly: true,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                            ),
                            readOnly: !_editingProfile,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _district,
                            decoration: const InputDecoration(
                              labelText: 'District',
                            ),
                            items: _districts
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ),
                                )
                                .toList(),
                            onChanged: _editingProfile
                                ? (val) => setState(() => _district = val)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          if (_editingProfile)
                            ElevatedButton(
                              onPressed: _saveProfile,
                              child: const Text('Save Profile'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bank Section
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _bankFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Bank Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _editingBank = !_editingBank,
                                ),
                                child: Text(_editingBank ? 'Cancel' : 'Edit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _bankName,
                            decoration: const InputDecoration(
                              labelText: 'Bank Name',
                            ),
                            items: _banksSriLanka
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b),
                                  ),
                                )
                                .toList(),
                            onChanged: _editingBank
                                ? (val) => setState(() => _bankName = val)
                                : null,
                            validator: (val) =>
                                val == null ? 'Select bank' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _accountController,
                            decoration: const InputDecoration(
                              labelText: 'Account Number',
                            ),
                            readOnly: !_editingBank,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cardController,
                            decoration: const InputDecoration(
                              labelText: 'Card Number',
                            ),
                            readOnly: !_editingBank,
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _expiryController,
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date (MM/YY)',
                            ),
                            readOnly: !_editingBank,
                            obscureText: true,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cvvController,
                            decoration: const InputDecoration(labelText: 'CVV'),
                            readOnly: !_editingBank,
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          if (_editingBank)
                            ElevatedButton(
                              onPressed: _saveBankDetails,
                              child: const Text('Save Bank Details'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dashboard Tab Placeholder
          Center(
            child: Text(
              'Dashboard content here',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}
