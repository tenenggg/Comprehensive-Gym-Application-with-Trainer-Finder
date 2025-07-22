import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2468),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Payments',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const TabBar(
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    tabs: [
                      Tab(text: 'Pending Payments'),
                      Tab(text: 'Payment History'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPendingPayments(),
                      _buildPaymentHistory(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPayments() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to view payments',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('trainer')
          .doc(user.uid)
          .collection('payments')
          .where('status', isEqualTo: 'held')
          .orderBy('timestamp', descending: true)
          .snapshots(),
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

        final payments = snapshot.data?.docs ?? [];

        if (payments.isEmpty) {
          return const Center(
            child: Text(
              'No pending payments',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index].data() as Map<String, dynamic>;
            final amount = payment['amount']?.toDouble() ?? 0.0;
            final userName = payment['userName'] ?? 'Unknown User';
            final bookingDateTime = payment['formattedDateTime'] ?? 'Unknown Date';
            final timestamp = payment['timestamp'] as Timestamp?;
            final escrowStatus = payment['escrowStatus'] ?? 'pending';

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
                      'From: $userName',
                      style: TextStyle(color: Colors.blue.shade100),
                    ),
                    Text(
                      'Session: $bookingDateTime',
                      style: TextStyle(color: Colors.blue.shade100),
                    ),
                    if (timestamp != null)
                      Text(
                        'Held since: ${_formatDate(timestamp.toDate())}',
                        style: TextStyle(color: Colors.blue.shade100, fontSize: 12),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'HELD IN ESCROW',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildPaymentHistory() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to view payments',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('trainer')
          .doc(user.uid)
          .collection('payments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
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

        final payments = snapshot.data?.docs ?? [];

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
            final payment = payments[index].data() as Map<String, dynamic>;
            final amount = payment['amount']?.toDouble() ?? 0.0;
            final userName = payment['userName'] ?? 'Unknown User';
            final status = payment['status'] ?? 'unknown';
            final escrowStatus = payment['escrowStatus'] ?? 'unknown';
            final timestamp = payment['timestamp'] as Timestamp?;
            final releasedAt = payment['releasedAt'] as Timestamp?;

            Color statusColor;
            String statusText;
            if (status == 'completed' && escrowStatus == 'released') {
              statusColor = Colors.green;
              statusText = 'RELEASED';
            } else if (status == 'held') {
              statusColor = Colors.orange;
              statusText = 'HELD';
            } else {
              statusColor = Colors.grey;
              statusText = 'UNKNOWN';
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
                      'From: $userName',
                      style: TextStyle(color: Colors.blue.shade100),
                    ),
                    if (timestamp != null)
                      Text(
                        'Received: ${_formatDate(timestamp.toDate())}',
                        style: TextStyle(color: Colors.blue.shade100, fontSize: 12),
                      ),
                    if (releasedAt != null)
                      Text(
                        'Released: ${_formatDate(releasedAt.toDate())}',
                        style: TextStyle(color: Colors.green.shade100, fontSize: 12),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 