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
        _district = _districts.contains(data['district'])
            ? data['district']
            : 'All Sri Lanka';
        _bankName = _banksSriLanka.contains(data['bankName'])
            ? data['bankName']
            : null;
        _accountController.text = data['accountNumber'] ?? '';
        _cardController.text = data['cardNumber'] ?? '';
        _expiryController.text = data['expiryDate'] ?? '';
        _cvvController.text = data['cvv'] ?? '';
      });
    } else {
      setState(() {
        _emailController.text = user.email ?? '';
        _district = 'All Sri Lanka';
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

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case "Pending":
        color = Colors.orange;
        break;
      case "Accepted":
        color = Colors.blue;
        break;
      case "Completed":
        color = Colors.green;
        break;
      case "Rejected":
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
          // Profile Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileCard(),
                const SizedBox(height: 16),
                _buildBankCard(),
              ],
            ),
          ),

          // Dashboard Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "My Bookings",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('buyerId', isEqualTo: user?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Text("No bookings yet.");
                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(data['serviceTitle'] ?? 'Service'),
                          subtitle: _statusChip(data['status'] ?? 'Pending'),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  "My Services",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('services')
                      .where('sellerId', isEqualTo: user?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const CircularProgressIndicator();
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Text("No services posted.");
                    return Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(data['title'] ?? 'Service'),
                          subtitle: _statusChip(data['status'] ?? 'Pending'),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header("Profile Info", () {
                setState(() => _editingProfile = !_editingProfile);
              }, _editingProfile),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                readOnly: !_editingProfile,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                readOnly: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                readOnly: !_editingProfile,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _districts.contains(_district)
                    ? _district
                    : 'All Sri Lanka',
                decoration: const InputDecoration(labelText: 'District'),
                items: _districts
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
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
    );
  }

  Widget _buildBankCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _bankFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header("Bank Details", () {
                setState(() => _editingBank = !_editingBank);
              }, _editingBank),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _banksSriLanka.contains(_bankName) ? _bankName : null,
                decoration: const InputDecoration(labelText: 'Bank Name'),
                items: _banksSriLanka
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: _editingBank
                    ? (val) => setState(() => _bankName = val)
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountController,
                decoration: const InputDecoration(labelText: 'Account Number'),
                readOnly: !_editingBank,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cardController,
                decoration: const InputDecoration(labelText: 'Card Number'),
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
    );
  }

  Widget _header(String title, VoidCallback onTap, bool editing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        TextButton(onPressed: onTap, child: Text(editing ? "Cancel" : "Edit")),
      ],
    );
  }
}
