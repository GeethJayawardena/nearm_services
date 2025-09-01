import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'request_details_page.dart';
import 'service_details_page.dart';
import 'edit_service_page.dart';
import 'login_choice_page.dart';

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

  // ===== LOGOUT WITH CONFIRMATION =====
  Future<void> _logout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Cancel
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    // If user cancels, do nothing
    if (confirmed != true) return;

    // Sign out from Firebase
    await FirebaseAuth.instance.signOut();

    // Navigate to login page and remove all previous routes
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login', // make sure this is your login route
      (route) => false,
    );
  }

  // ===== DELETE ACCOUNT WITH SAFE LOGOUT =====
  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Account Deletion"),
        content: const Text(
          "All your services, requests, and profile data will be permanently deleted. This cannot be undone.",
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
      // Delete user's profile
      await firestore.collection('users').doc(user.uid).delete();

      // Delete all services created by user along with their requests
      final servicesSnap = await firestore
          .collection('services')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      for (var serviceDoc in servicesSnap.docs) {
        final requestsSnap = await serviceDoc.reference
            .collection('requests')
            .get();
        for (var reqDoc in requestsSnap.docs) {
          await reqDoc.reference.delete();
        }
        await serviceDoc.reference.delete();
      }

      // Delete requests where user is buyer
      final allServicesSnap = await firestore.collection('services').get();
      for (var serviceDoc in allServicesSnap.docs) {
        final buyerRequestsSnap = await serviceDoc.reference
            .collection('requests')
            .where('userId', isEqualTo: user.uid)
            .get();
        for (var reqDoc in buyerRequestsSnap.docs) {
          await reqDoc.reference.delete();
        }
      }

      // Delete Firebase Auth user
      await user.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
      );

      // Redirect to login page and remove all previous routes
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login', // make sure this is your login route
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
    }
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case "pending":
        color = Colors.orange;
        break;
      case "price_proposed":
      case "buyer_agreed":
      case "accepted":
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout, // <-- call the updated function
            tooltip: 'Logout',
          ),

          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _deleteAccount,
            tooltip: 'Delete Account',
          ),
        ],
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
          // ===== PROFILE TAB =====
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

          // ===== DASHBOARD TAB WITH INTERNAL TABS =====
          Column(
            children: [
              TabBar(
                controller: _dashboardTabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'My Bookings'),
                  Tab(text: 'Bookings on My Services'),
                  Tab(text: 'My Services'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _dashboardTabController,
                  children: [
                    // ===== MY BOOKINGS (Buyer) =====
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('services')
                            .snapshots(),
                        builder: (context, serviceSnapshot) {
                          if (serviceSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!serviceSnapshot.hasData ||
                              serviceSnapshot.data!.docs.isEmpty) {
                            return const Text("No bookings yet.");
                          }

                          List<Widget> bookingWidgets = [];

                          for (var serviceDoc in serviceSnapshot.data!.docs) {
                            final serviceId = serviceDoc.id;
                            final serviceName = serviceDoc['name'] ?? 'Service';

                            // Requests where user is buyer
                            final requests = serviceDoc.reference.collection(
                              'requests',
                            );

                            bookingWidgets.add(
                              StreamBuilder<QuerySnapshot>(
                                stream: requests
                                    .where('userId', isEqualTo: user?.uid)
                                    .snapshots(),
                                builder: (context, reqSnapshot) {
                                  if (!reqSnapshot.hasData ||
                                      reqSnapshot.data!.docs.isEmpty) {
                                    return const SizedBox();
                                  }

                                  return Column(
                                    children: reqSnapshot.data!.docs.map((
                                      reqDoc,
                                    ) {
                                      final data =
                                          reqDoc.data() as Map<String, dynamic>;
                                      final status =
                                          (data['status'] ?? 'pending')
                                              .toString();
                                      String bookingDateText =
                                          'Booking Date N/A';
                                      if (data['bookingDate'] != null &&
                                          data['bookingDate'] is Timestamp) {
                                        bookingDateText =
                                            (data['bookingDate'] as Timestamp)
                                                .toDate()
                                                .toLocal()
                                                .toString()
                                                .split(' ')[0];
                                      }
                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: ListTile(
                                          title: Text(serviceName),
                                          subtitle: Text(bookingDateText),
                                          trailing: _statusChip(status),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    RequestDetailsPage(
                                                      bookingId: reqDoc.id,
                                                      serviceId: serviceId,
                                                      userId: user!.uid,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            );
                          }

                          if (bookingWidgets.isEmpty) {
                            return const Text("No bookings yet.");
                          }

                          return Column(children: bookingWidgets);
                        },
                      ),
                    ),

                    // ===== BOOKINGS ON MY SERVICES (Seller) =====
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('services')
                            .where('ownerId', isEqualTo: user?.uid)
                            .snapshots(),
                        builder: (context, serviceSnapshot) {
                          if (serviceSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!serviceSnapshot.hasData ||
                              serviceSnapshot.data!.docs.isEmpty) {
                            return const Text("No services posted yet.");
                          }

                          final serviceDocs = serviceSnapshot.data!.docs;

                          return Column(
                            children: serviceDocs.map((serviceDoc) {
                              final serviceId = serviceDoc.id;
                              final serviceName =
                                  serviceDoc['name'] ?? 'Service';

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('services')
                                    .doc(serviceId)
                                    .collection('requests')
                                    .snapshots(),
                                builder: (context, requestSnapshot) {
                                  if (requestSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox();
                                  }
                                  if (!requestSnapshot.hasData ||
                                      requestSnapshot.data!.docs.isEmpty) {
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: ListTile(
                                        title: Text(serviceName),
                                        subtitle: const Text(
                                          "No bookings on this service yet",
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: requestSnapshot.data!.docs.map((
                                      reqDoc,
                                    ) {
                                      final data =
                                          reqDoc.data() as Map<String, dynamic>;
                                      final status =
                                          (data['status'] ?? 'pending')
                                              .toString();
                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: ListTile(
                                          title: Text(
                                            data['userName'] ?? 'Booking',
                                          ),
                                          subtitle: Text(
                                            "$serviceName | ${data['bookingDate'] != null ? (data['bookingDate'] as Timestamp).toDate().toLocal().toString().split(' ')[0] : 'Booking Date N/A'}",
                                          ),
                                          trailing: _statusChip(status),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    RequestDetailsPage(
                                                      bookingId: reqDoc.id,
                                                      serviceId: serviceId,
                                                      userId:
                                                          data['userId'] ?? '',
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),

                    // ===== MY SERVICES =====
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('services')
                            .where('ownerId', isEqualTo: user?.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty)
                            return const Text("No services posted.");

                          return Column(
                            children: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  title: Text(
                                    data['name'] ?? 'Service',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(data['category'] ?? ''),
                                  trailing: const Icon(
                                    Icons.edit,
                                    color: Colors.blueAccent,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditServicePage(
                                          serviceId: doc.id,
                                          serviceData: data,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== PROFILE CARD =====
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

  // ===== BANK CARD =====
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
