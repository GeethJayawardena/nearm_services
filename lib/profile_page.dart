import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'request_details_page.dart';
import 'service_details_page.dart';
import 'edit_service_page.dart';
import 'email_login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _bankFormKey = GlobalKey<FormState>();
  late TabController _tabController;
  late TabController _dashboardTabController;

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

  // Profile picture
  File? _profileImage;
  String? _profileImageUrl; // store path in Firestore

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

  final List<String> _banksSriLanka = [
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
    _dashboardTabController = TabController(length: 3, vsync: this);
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
        _profileImageUrl = data['profileImage'];
      });

      if (_profileImageUrl != null && File(_profileImageUrl!).existsSync()) {
        setState(() {
          _profileImage = File(_profileImageUrl!);
        });
      }
    } else {
      setState(() {
        _emailController.text = user.email ?? '';
        _district = 'All Sri Lanka';
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final localImage = await File(pickedFile.path).copy(
        '${dir.path}/${user.uid}.png', // <-- use user ID as filename
      );

      setState(() {
        _profileImage = localImage;
        _profileImageUrl = localImage.path;
      });

      // Save path in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profileImage': localImage.path,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? imagePath = _profileImage?.path ?? _profileImageUrl;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'district': _district,
      'profileImage': imagePath,
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout Confirmation"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "This will permanently delete your account and all related data.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.collection('users').doc(user.uid).delete();

      // Delete services & requests
      final servicesSnap = await firestore
          .collection('services')
          .where('ownerId', isEqualTo: user.uid)
          .get();
      for (var serviceDoc in servicesSnap.docs) {
        final requestsSnap = await serviceDoc.reference
            .collection('requests')
            .get();
        for (var reqDoc in requestsSnap.docs) await reqDoc.reference.delete();
        await serviceDoc.reference.delete();
      }

      // Delete user's requests on other services
      final allServicesSnap = await firestore.collection('services').get();
      for (var serviceDoc in allServicesSnap.docs) {
        final buyerRequestsSnap = await serviceDoc.reference
            .collection('requests')
            .where('userId', isEqualTo: user.uid)
            .get();
        for (var reqDoc in buyerRequestsSnap.docs)
          await reqDoc.reference.delete();
      }

      await user.delete();

      // Show account deleted message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Account deleted successfully")),
      );

      // Navigate safely to login page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => EmailLoginPage()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case "pending":
        color = Colors.orange;
        break;
      case "accepted":
      case "price_proposed":
      case "buyer_agreed":
        color = Colors.blue;
        break;
      case "completed":
        color = Colors.green;
        break;
      case "cancelled":
      case "rejected":
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _deleteAccount,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepPurple,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Profile"),
            Tab(text: "Dashboard"),
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
                _buildProfileCard(),
                const SizedBox(height: 16),
                _buildBankCard(),
              ],
            ),
          ),
          Column(
            children: [
              TabBar(
                controller: _dashboardTabController,
                labelColor: Colors.deepPurple,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.deepPurple,
                tabs: const [
                  Tab(text: "My Bookings"),
                  Tab(text: "Bookings on My Services"),
                  Tab(text: "My Services"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _dashboardTabController,
                  children: [
                    _buildBookingsTab(user?.uid, buyer: true),
                    _buildBookingsTab(user?.uid, buyer: false),
                    _buildServicesTab(user?.uid),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Profile Card ---
  Widget _buildProfileCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      shadowColor: Colors.grey.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(
                "Profile Info",
                () => setState(() => _editingProfile = !_editingProfile),
                _editingProfile,
              ),
              const SizedBox(height: 12),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : (_profileImageUrl != null
                                ? FileImage(File(_profileImageUrl!))
                                : null),
                      child: _profileImage == null && _profileImageUrl == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),

                    if (_editingProfile)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.deepPurple,
                          ),
                          onPressed: _pickProfileImage,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _textField(_nameController, "Name", _editingProfile),
              const SizedBox(height: 12),
              _textField(_emailController, "Email", false),
              const SizedBox(height: 12),
              _textField(_addressController, "Address", _editingProfile),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _districts.contains(_district)
                    ? _district
                    : 'All Sri Lanka',
                items: _districts
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: _editingProfile
                    ? (val) => setState(() => _district = val)
                    : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "District",
                ),
              ),
              const SizedBox(height: 16),
              if (_editingProfile)
                _gradientButton("Save Profile", _saveProfile),
            ],
          ),
        ),
      ),
    );
  }

  // --- Bank Card ---
  Widget _buildBankCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      shadowColor: Colors.grey.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _bankFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(
                "Bank Details",
                () => setState(() => _editingBank = !_editingBank),
                _editingBank,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _banksSriLanka.contains(_bankName) ? _bankName : null,
                items: _banksSriLanka
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: _editingBank
                    ? (val) => setState(() => _bankName = val)
                    : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "Bank Name",
                ),
              ),
              const SizedBox(height: 12),
              _textField(_accountController, "Account Number", _editingBank),
              const SizedBox(height: 12),
              _textField(
                _cardController,
                "Card Number",
                _editingBank,
                obscure: true,
              ),
              const SizedBox(height: 12),
              _textField(
                _expiryController,
                "Expiry Date (MM/YY)",
                _editingBank,
                obscure: true,
              ),
              const SizedBox(height: 12),
              _textField(_cvvController, "CVV", _editingBank, obscure: true),
              const SizedBox(height: 16),
              if (_editingBank)
                _gradientButton("Save Bank Details", _saveBankDetails),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---
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

  Widget _textField(
    TextEditingController controller,
    String label,
    bool editable, {
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: !editable,
      obscureText: obscure,
      validator: (val) => val == null || val.isEmpty ? 'Enter $label' : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _gradientButton(String text, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // --- Dashboard Tabs ---
  Widget _buildBookingsTab(String? uid, {required bool buyer}) {
    if (uid == null) return const Center(child: Text("User not logged in"));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .where('ownerId', isEqualTo: buyer ? null : uid) // <-- fix here
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Text("No data");

          List<Widget> items = [];
          for (var service in snapshot.data!.docs) {
            final serviceId = service.id;
            final serviceName = service['name'] ?? 'Service';
            final requests = service.reference.collection('requests');

            items.add(
              StreamBuilder<QuerySnapshot>(
                stream: buyer
                    ? requests.where('userId', isEqualTo: uid).snapshots()
                    : requests.snapshots(),
                builder: (context, reqSnap) {
                  if (!reqSnap.hasData || reqSnap.data!.docs.isEmpty) {
                    return const SizedBox();
                  }

                  return Column(
                    children: reqSnap.data!.docs.map((req) {
                      final data = req.data() as Map<String, dynamic>;
                      final status = data['status'] ?? 'pending';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            buyer
                                ? serviceName
                                : (data['userName'] ?? 'Booking'),
                          ),
                          subtitle: Text(
                            buyer
                                ? "Booking ID: ${req.id}"
                                : "$serviceName | Booking ID: ${req.id}",
                          ),
                          trailing: _statusChip(status),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            );
          }
          return Column(children: items);
        },
      ),
    );
  }

  Widget _buildServicesTab(String? uid) {
    if (uid == null) return const Center(child: Text("User not logged in"));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .where('ownerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty)
            return const Text("No services added");
          return Column(
            children: snapshot.data!.docs.map((service) {
              final data = service.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(data['name'] ?? 'Service'),
                  subtitle: Text(data['description'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.deepPurple),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditServicePage(
                          serviceId: service.id,
                          serviceData: data,
                        ),
                      ),
                    ),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServiceDetailsPage(serviceId: service.id),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
