import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../models/admin_model.dart';
import '../../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../login_page.dart';
import '../../widgets/profile_image_widget.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();
  Map<String, dynamic> _analytics = {};
  AdminModel? _currentAdmin;
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    print('[ADMIN_DASHBOARD] _loadData started.');
    setState(() {
      _isLoading = true;
      _loadingError = null;
    });
    try {
      final analytics = await _adminService.getAnalytics();
      print('[ADMIN_DASHBOARD] Analytics data received: $analytics'); // More detailed log

      final admin = await _adminService.getCurrentAdmin();
      print('[ADMIN_DASHBOARD] Current admin received: ${admin?.name}');
      
      if (mounted) {
        if (admin == null) {
          setState(() {
            _isLoading = false;
            _loadingError = 'Could not find an admin profile for the current user. Please contact support.';
          });
        } else {
          setState(() {
            _analytics = analytics;
            _currentAdmin = admin;
            _isLoading = false;
          });
          print('[ADMIN_DASHBOARD] State updated with new data.');
        }
      }
    } catch (e) {
      print('[ADMIN_DASHBOARD] Error loading admin data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingError = 'Failed to load admin data: $e';
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error signing out')),
      );
    }
  }

  Future<void> _refreshAdminProfile() async {
    final admin = await _adminService.getCurrentAdmin();
    if (mounted && admin != null) {
      setState(() {
        _currentAdmin = admin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2468),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF212E83),
              const Color(0xFF1A2468),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,  // Don't add padding at the bottom
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    // Admin Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          ProfileImageDisplay(
                            imageUrl: _currentAdmin?.profileImage,
                            size: 48,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Dashboard',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_currentAdmin != null)
                                  Text(
                                    _currentAdmin!.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue.shade100,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout_rounded),
                            color: Colors.red.shade300,
                            iconSize: 24,
                          ),
                        ],
                      ),
                    ),
                    // Main Content
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildOverview(),
                          ),
                          _buildUsersList(),
                          _buildTrainersList(),
                          _buildPaymentsPage(),
                          _buildRefundsPage(),
                          _buildAnnouncementsPage(),
                          if (_currentAdmin != null)
                            AdminSettingsPage(
                              admin: _currentAdmin!,
                              onProfileUpdated: _refreshAdminProfile,
                            )
                          else
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  _loadingError ?? 'Admin profile could not be loaded. Please try again later.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Bottom Navigation
                    Theme(
                      data: Theme.of(context).copyWith(
                        navigationBarTheme: NavigationBarThemeData(
                          labelTextStyle: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.selected)) {
                              return const TextStyle(fontSize: 12, height: 1.0, color: Colors.white, fontWeight: FontWeight.bold);
                            }
                            return const TextStyle(fontSize: 12, height: 1.0, color: Colors.white70);
                          }),
                        ),
                      ),
                      child: NavigationBar(
                        height: 60,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        indicatorColor: Colors.white.withOpacity(0.2),
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.dashboard_outlined, size: 24, color: Colors.white70),
                            selectedIcon: Icon(Icons.dashboard, size: 24, color: Colors.white),
                            label: 'Overview',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.people_outline, size: 24, color: Colors.white70),
                            selectedIcon: Icon(Icons.people, size: 24, color: Colors.white),
                            label: 'Users',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.fitness_center_outlined, size: 24, color: Colors.white70),
                            selectedIcon: Icon(Icons.fitness_center, size: 24, color: Colors.white),
                            label: 'Trainers',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.payment_outlined, size: 24, color: Colors.white70),
                            selectedIcon: Icon(Icons.payment, size: 24, color: Colors.white),
                            label: 'Payments',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.money_off_outlined, size: 24, color: Colors.white70),
                            selectedIcon: Icon(Icons.money_off, size: 24, color: Colors.white),
                            label: 'Refunds',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.campaign_outlined, size: 24, color: Colors.white70),
                            selectedIcon: Icon(Icons.campaign, size: 24, color: Colors.white),
                            label: 'Announce',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.settings_outlined, size: 24, color: Colors.white70),
                            selectedIcon: Icon(Icons.settings, size: 24, color: Colors.white),
                            label: 'Settings',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade100,
                ),
              ),
              Icon(icon, color: iconColor, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analytics Overview',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Users',
              _analytics['totalUsers']?.toString() ?? '0',
              Icons.people_alt,
              Colors.blue.shade300,
            ),
            _buildStatCard(
              'Total Trainers',
              _analytics['totalTrainers']?.toString() ?? '0',
              Icons.sports,
              Colors.green.shade300,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActiveBookingsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminService.getActiveBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No active bookings right now.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final bookings = snapshot.data!;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final bookingTime = (booking['bookingDateTime'] as Timestamp).toDate();
            
            return Card(
              color: Colors.white.withOpacity(0.1),
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  'User: ${booking['userName'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Trainer: ${booking['trainerName'] ?? 'N/A'}\n'
                  'On: ${bookingTime.day}/${bookingTime.month}/${bookingTime.year} at ${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: Text(
                  booking['status'].toString().toUpperCase(),
                  style: TextStyle(
                    color: booking['status'] == 'confirmed' ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<List<UserModel>>(
      stream: _adminService.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(
            child: Text(
              'No users found',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: user.profileImage != null && user.profileImage!.isNotEmpty
                    ? ProfileImageDisplay(
                        imageUrl: user.profileImage,
                        size: 40,
                        cacheKey: user.profileImage != null ? '${user.profileImage}_${user.id}' : null,
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.blue.shade300,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                title: Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  user.email,
                  style: TextStyle(color: Colors.blue.shade100),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: user.isActive,
                      onChanged: (value) => _adminService.updateUserStatus(user.id, value),
                      activeColor: Colors.green.shade300,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showDeleteConfirmationDialog(
                        context: context,
                        itemName: user.name,
                        onConfirm: () => _adminService.deleteUser(user.id),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrainersList() {
    return StreamBuilder<List<UserModel>>(
      stream: _adminService.getAllTrainers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final trainers = snapshot.data ?? [];
        if (trainers.isEmpty) {
          return const Center(
            child: Text(
              'No trainers found',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        }

        return Column(
          children: [
            // Trainers List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: trainers.length,
                itemBuilder: (context, index) {
                  final trainer = trainers[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: trainer.profileImage != null && trainer.profileImage!.isNotEmpty
                          ? ProfileImageDisplay(
                              imageUrl: trainer.profileImage,
                              size: 40,
                            )
                          : CircleAvatar(
                              backgroundColor: Colors.green.shade300,
                              child: Text(
                                trainer.name.isNotEmpty ? trainer.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                      title: Text(
                        trainer.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        trainer.email,
                        style: TextStyle(color: Colors.blue.shade100),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.verified_user),
                            onPressed: () => _adminService.updateTrainerVerification(
                              trainer.id,
                              !trainer.isVerified,
                            ),
                            color: trainer.isVerified
                                ? Colors.green.shade300
                                : Colors.grey,
                          ),
                          Switch(
                            value: trainer.isActive,
                            onChanged: (value) =>
                                _adminService.updateUserStatus(trainer.id, value),
                            activeColor: Colors.green.shade300,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _showDeleteConfirmationDialog(
                              context: context,
                              itemName: trainer.name,
                              onConfirm: () => _adminService.deleteTrainer(trainer.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentsPage() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: const TabBar(
            tabs: [
              Tab(text: 'Release Payments'),
              Tab(text: 'Refund Requests'),
              Tab(text: 'Payment History'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            _buildReleasePayments(),
            _buildRefundRequests(),
            _buildPaymentHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildReleasePayments() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminService.getEscrowPaymentsForRelease(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final allPayments = snapshot.data ?? [];
        // Filter out refunded payments - they should only appear in refunds section
        final payments = allPayments.where((payment) => 
          payment['adminStatus'] != 'refunded'
        ).toList();

        if (payments.isEmpty) {
          return const Center(
            child: Text(
              'No payments to release',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            final amount = payment['amount']?.toDouble() ?? 0.0;
            final userName = payment['userName'] ?? 'Unknown User';
            final trainerName = payment['trainerName'] ?? 'Unknown Trainer';
            final bookingDateTime = payment['formattedDateTime'] ?? 'Unknown Date';
            final createdAt = payment['createdAt'] as Timestamp?;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  'RM ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'User: $userName',
                      style: TextStyle(color: Colors.blue.shade100),
                    ),
                    Text(
                      'Trainer: $trainerName',
                      style: TextStyle(color: Colors.blue.shade100),
                    ),
                    Text(
                      'Session: $bookingDateTime',
                      style: TextStyle(color: Colors.blue.shade100),
                    ),
                    if (createdAt != null)
                      Text(
                        'Held since: ${_formatDate(createdAt.toDate())}',
                        style: TextStyle(color: Colors.blue.shade100, fontSize: 12),
                      ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () => _showReleasePaymentDialog(payment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Release'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRefundRequests() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminService.getPaymentsPendingRefund(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final refundRequests = snapshot.data ?? [];

        if (refundRequests.isEmpty) {
          return const Center(
            child: Text(
              'No pending refund requests.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: refundRequests.length,
          itemBuilder: (context, index) {
            final payment = refundRequests[index];
            final amount = payment['amount']?.toDouble() ?? 0.0;
            final userName = payment['userName'] ?? 'Unknown User';
            final trainerName = payment['trainerName'] ?? 'Unknown Trainer';
            final bookingDateTime = payment['formattedDateTime'] ?? 'Unknown Date';
            final reason = payment['cancellationReason'] ?? 'Not specified';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  'RM ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'User: $userName',
                      style: TextStyle(color: Colors.blue.shade100),
                    ),
                    Text(
                      'Trainer: $trainerName',
                      style: TextStyle(color: Colors.blue.shade100),
                    ),
                    Text(
                      'Reason: ${reason.replaceAll('_', ' ').toUpperCase()}',
                      style: TextStyle(color: Colors.orange.shade200),
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () => _showProcessRefundDialog(payment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Refund'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentHistory() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _adminService.getAllEscrowPayments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final payments = snapshot.data ?? [];

        if (payments.isEmpty) {
          return const Center(
            child: Text(
              'No payment history',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            final amount = payment['amount']?.toDouble() ?? 0.0;
            final userName = payment['userName'] ?? 'Unknown User';
            final trainerName = payment['trainerName'] ?? 'Unknown Trainer';
            final status = payment['adminStatus'] ?? 'unknown';
            final createdAt = payment['createdAt'] as Timestamp?;
            final releasedAt = payment['releasedAt'] as Timestamp?;
            final refundedAt = payment['refundedAt'] as Timestamp?;
            final refundReason = payment['refundReason'] ?? '';

            // Determine status color and text
            Color statusColor;
            String statusText;
            switch (status) {
              case 'released':
                statusColor = Colors.green;
                statusText = 'RELEASED';
                break;
              case 'refunded':
                statusColor = Colors.red;
                statusText = 'REFUNDED';
                break;
              case 'pending':
                statusColor = Colors.orange;
                statusText = 'PENDING';
                break;
              case 'held':
                statusColor = Colors.blue;
                statusText = 'HELD';
                break;
              default:
                statusColor = Colors.grey;
                statusText = status.toUpperCase();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Row(
                  children: [
                    Text(
                      'RM ${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'User: $userName',
                      style: TextStyle(color: Colors.blue.shade100),
                    ),
                    Text(
                      'Trainer: $trainerName',
                      style: TextStyle(color: Colors.blue.shade100),
                    ),
                    if (createdAt != null)
                      Text(
                        'Created: ${_formatDate(createdAt.toDate())}',
                        style: TextStyle(color: Colors.blue.shade100, fontSize: 12),
                      ),
                    if (releasedAt != null)
                      Text(
                        'Released: ${_formatDate(releasedAt.toDate())}',
                        style: TextStyle(color: Colors.green.shade100, fontSize: 12),
                      ),
                    if (refundedAt != null)
                      Text(
                        'Refunded: ${_formatDate(refundedAt.toDate())}',
                        style: TextStyle(color: Colors.red.shade100, fontSize: 12),
                      ),
                    if (refundReason.isNotEmpty)
                      Text(
                        'Reason: $refundReason',
                        style: TextStyle(color: Colors.red.shade100, fontSize: 12),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReleasePaymentDialog(Map<String, dynamic> payment) {
    final amount = payment['amount']?.toDouble() ?? 0.0;
    final userName = payment['userName'] ?? 'Unknown User';
    final trainerName = payment['trainerName'] ?? 'Unknown Trainer';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212E83),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Release Payment',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to release RM ${amount.toStringAsFixed(2)} to $trainerName for the session with $userName?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Release Payment'),
            onPressed: () async {
              try {
                await _adminService.releasePaymentToTrainer(
                  payment['id'],
                  payment['paymentIntentId'],
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Payment released to $trainerName'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error releasing payment: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showProcessRefundDialog(Map<String, dynamic> payment) {
    final amount = payment['amount']?.toDouble() ?? 0.0;
    final userName = payment['userName'] ?? 'Unknown User';
    final trainerName = payment['trainerName'] ?? 'Unknown Trainer';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF212E83),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Process Refund',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to refund RM ${amount.toStringAsFixed(2)} to $userName for the session cancelled by $trainerName?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            child: const Text('Yes, Process Refund', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              print('--- Refund Process Started ---');
              
              // Define all variables and check for nulls
              final bookingId = payment['bookingId'] as String?;
              final paymentIntentId = payment['paymentIntentId'] as String?;
              final userId = payment['userId'] as String?;
              final trainerId = payment['trainerId'] as String?;
              final amount = payment['amount']?.toDouble();

              print('1. Extracted Data:');
              print('   - Booking ID: $bookingId');
              print('   - Payment Intent ID: $paymentIntentId');
              print('   - User ID: $userId');
              print('   - Trainer ID: $trainerId');
              print('   - Amount: $amount');

              if (bookingId == null || paymentIntentId == null || userId == null || trainerId == null || amount == null) {
                print('--- ERROR: One or more required fields are null. Aborting. ---');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Critical error: Missing data for refund.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                Navigator.pop(context);
                return;
              }

              print('2. Data validation passed.');

              // Store the ScaffoldMessenger before the async gap.
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context); // Close dialog

              try {
                print('3. Dialog closed. Calling refund service...');
                
                await _adminService.refundPaymentForCancelledBooking(
                  bookingId: bookingId,
                  paymentIntentId: paymentIntentId,
                  userId: userId,
                  trainerId: trainerId,
                  amount: amount,
                  reason: 'trainer_cancellation_approved',
                );

                print('4. Refund service call completed successfully.');

                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Refund processed successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                print('5. Success message shown.');

              } catch (e, s) {
                print('--- ERROR DURING REFUND ---');
                print('Error: $e');
                print('Stack Trace: $s');
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error during refund: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSettingsPage() {
    final nameController = TextEditingController(
      text: _currentAdmin?.name ?? '',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade100,
                  ),
                ),
                const SizedBox(height: 20),
                // Name Change Field
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Admin Name',
                    labelStyle: TextStyle(color: Colors.blue.shade100),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue.shade200),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                  ),
                ),
                const SizedBox(height: 16),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await _adminService.updateAdminName(nameController.text.trim());
                        if (!mounted) return;
                        
                        // Refresh admin data
                        final admin = await _adminService.getCurrentAdmin();
                        setState(() {
                          _currentAdmin = admin;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Name updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating name: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // System Settings Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade100,
                  ),
                ),
                const SizedBox(height: 20),
                // Add more system settings here
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog({
    required BuildContext context,
    required String itemName,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF212E83),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirm Deletion',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "$itemName"? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.8),
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"$itemName" has been deleted.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnnouncementsPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.campaign, color: Colors.white, size: 100),
          const SizedBox(height: 20),
          const Text(
            'Send announcements to users and trainers.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showSendAnnouncementDialog(),
            icon: const Icon(Icons.send),
            label: const Text('New Announcement'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSendAnnouncementDialog() async {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String targetAudience = 'everyone'; // Default value

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Send New Announcement'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(labelText: 'Message'),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: targetAudience,
                      decoration: const InputDecoration(labelText: 'Target Audience'),
                      items: const [
                        DropdownMenuItem(
                          value: 'everyone',
                          child: Text('Everyone'),
                        ),
                        DropdownMenuItem(
                          value: 'users_only',
                          child: Text('Users Only'),
                        ),
                        DropdownMenuItem(
                          value: 'trainers_only',
                          child: Text('Trainers Only'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            targetAudience = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty && messageController.text.isNotEmpty) {
                      try {
                        await _adminService.sendAnnouncement(
                          title: titleController.text,
                          message: messageController.text,
                          audience: targetAudience,
                        );
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Announcement sent successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error sending announcement: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Title and message cannot be empty.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRefundsPage() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Refund Management',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _adminService.getAllRefunds(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                final refunds = snapshot.data ?? [];

                if (refunds.isEmpty) {
                  return const Center(
                    child: Text(
                      'No refunds found',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: refunds.length,
                  itemBuilder: (context, index) {
                    final refund = refunds[index];
                    final amount = refund['amount']?.toDouble() ?? 0.0;
                    final refundStatus = refund['refundStatus'] ?? 'pending';
                    final refundReason = refund['refundReason'] ?? 'Unknown';
                    final refundedAt = refund['refundedAt'] as Timestamp?;
                    final bookingId = refund['bookingId'] ?? '';
                    final userId = refund['userId'] ?? '';
                    final trainerId = refund['trainerId'] ?? '';
                    final refundedBy = refund['refundedBy'] ?? '';
                    final initiatedBy = refund['initiatedBy'] ?? 'admin';
                    final refundId = refund['refundId'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          children: [
                            Text(
                              'RM ${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: initiatedBy == 'trainer' 
                                    ? Colors.orange.withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                initiatedBy.toUpperCase(),
                                style: TextStyle(
                                  color: initiatedBy == 'trainer' 
                                      ? Colors.orange.shade300 
                                      : Colors.blue.shade300,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Reason: ${refundReason.replaceAll('_', ' ').toUpperCase()}',
                              style: TextStyle(color: Colors.blue.shade100),
                            ),
                            Text(
                              'Status: ${refundStatus.toUpperCase()}',
                              style: TextStyle(
                                color: refundStatus == 'succeeded' 
                                    ? Colors.green.shade300 
                                    : Colors.orange.shade300,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Booking ID: $bookingId',
                              style: TextStyle(color: Colors.blue.shade100, fontSize: 12),
                            ),
                            if (refundId.isNotEmpty)
                              Text(
                                'Refund ID: $refundId',
                                style: TextStyle(color: Colors.blue.shade100, fontSize: 12),
                              ),
                            if (refundedBy.isNotEmpty)
                              Text(
                                'Refunded by: $refundedBy',
                                style: TextStyle(color: Colors.blue.shade100, fontSize: 12),
                              ),
                            if (refundedAt != null)
                              Text(
                                'Refunded: ${_formatDate(refundedAt.toDate())}',
                                style: TextStyle(color: Colors.blue.shade100, fontSize: 12),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: refundStatus == 'succeeded' 
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            refundStatus.toUpperCase(),
                            style: TextStyle(
                              color: refundStatus == 'succeeded' 
                                  ? Colors.green.shade300 
                                  : Colors.orange.shade300,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSettingsPage extends StatefulWidget {
  final AdminModel admin;
  final Future<void> Function() onProfileUpdated;

  const AdminSettingsPage({
    super.key,
    required this.admin,
    required this.onProfileUpdated,
  });

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  late final TextEditingController _nameController;
  final AdminService _adminService = AdminService();
  bool _isSaving = false;
  String? _profileImageUrl;
  String _imageCacheKey = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.admin.name);
    _profileImageUrl = widget.admin.profileImage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newName = _nameController.text.trim();
      await _adminService.updateAdminProfile(widget.admin.id, newName);
      await widget.onProfileUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildProfileCard(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final adminId = FirebaseAuth.instance.currentUser?.uid;
    return Card(
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProfileImageWidget(
              imageUrl: _profileImageUrl != null && _imageCacheKey.isNotEmpty
                  ? '$_profileImageUrl?t=$_imageCacheKey'
                  : _profileImageUrl,
              userType: 'admin',
              isEditable: true,
              size: 100,
              cacheKey: _profileImageUrl != null && adminId != null
                  ? '$_profileImageUrl${adminId}'
                  : _imageCacheKey,
              onImageChanged: (url) async {
                if (adminId != null) {
                  final doc = await FirebaseFirestore.instance.collection('admins').doc(adminId).get();
                  setState(() {
                    _profileImageUrl = doc.data()?['profileImage'];
                    _imageCacheKey = DateTime.now().millisecondsSinceEpoch.toString();
                  });
                  await widget.onProfileUpdated();
                }
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Admin Name',
                labelStyle: TextStyle(color: Colors.blue.shade100),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade200),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : ElevatedButton.icon(
                    onPressed: _updateProfile,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700.withOpacity(0.8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
} 