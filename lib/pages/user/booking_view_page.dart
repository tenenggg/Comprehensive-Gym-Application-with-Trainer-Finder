import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment_page.dart';
import '../../widgets/profile_image_widget.dart';
import 'package:intl/intl.dart';

class BookingViewPage extends StatelessWidget {
  const BookingViewPage({super.key});

  Future<double> _getSessionFee(String trainerId) async {
    try {
      final trainerDoc = await FirebaseFirestore.instance
          .collection('trainer')
          .doc(trainerId)
          .get();
      if (trainerDoc.exists) {
        return (trainerDoc.data()?['sessionFee'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      print('Error getting session fee: $e');
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2468),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Bookings',
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
          child: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const Center(
                  child: Text(
                    'Please log in to view your bookings',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userSnapshot.data!.uid)
                    .collection('bookings')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final bookings = snapshot.data?.docs ?? [];

                  if (bookings.isEmpty) {
                    return const Center(
                      child: Text(
                        'No bookings found',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  // Group bookings by trainer
                  final Map<String, List<QueryDocumentSnapshot>> groupedBookings = {};
                  for (var booking in bookings) {
                    final trainerName = booking['trainerName'] as String? ?? 'Unknown Trainer';
                    if (groupedBookings.containsKey(trainerName)) {
                      groupedBookings[trainerName]!.add(booking);
                    } else {
                      groupedBookings[trainerName] = [booking];
                    }
                  }

                  final trainerNames = groupedBookings.keys.toList();

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: trainerNames.length,
                    itemBuilder: (context, index) {
                      final trainerName = trainerNames[index];
                      final trainerBookings = groupedBookings[trainerName]!;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ExpansionTile(
                          leading: FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('trainer')
                                .doc(trainerBookings.first['trainerId'])
                                .get(),
                            builder: (context, trainerSnapshot) {
                              if (trainerSnapshot.hasData && trainerSnapshot.data!.exists) {
                                final trainerData = trainerSnapshot.data!.data() as Map<String, dynamic>?;
                                return ProfileImageDisplay(
                                  imageUrl: trainerData?['profileImage'],
                                  size: 40,
                                );
                              }
                              return Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              );
                            },
                          ),
                          title: Text(
                            trainerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${trainerBookings.length} booking${trainerBookings.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          iconColor: Colors.white,
                          collapsedIconColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          collapsedBackgroundColor: Colors.transparent,
                          children: trainerBookings.map((bookingDoc) {
                            final booking = bookingDoc.data() as Map<String, dynamic>;
                            final status = booking['status'] ?? 'pending';
                            final paymentStatus = booking['paymentStatus'];
                            final sharingConfirmed = booking['calorieSharingConfirmed'] == true;

                            Color statusColor;
                            if (status == 'confirmed' && (paymentStatus == 'paid' || paymentStatus == 'paid_held')) {
                              statusColor = Colors.green;
                            } else if (status == 'pending') {
                              statusColor = Colors.orange;
                            } else {
                              statusColor = Colors.red;
                            }

                            return Container(
                              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.calendar_today,
                                            color: statusColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                booking['formattedDateTime'] ?? 'No schedule',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  status.toUpperCase(),
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      'Payment Status',
                                      (paymentStatus ?? 'UNPAID').toUpperCase(),
                                    ),
                                    const SizedBox(height: 6),
                                    if (paymentStatus == 'refunded') ...[
                                      _buildInfoRow(
                                        'Refund Status',
                                        'REFUNDED',
                                      ),
                                      const SizedBox(height: 6),
                                      _buildInfoRow(
                                        'Refund Reason',
                                        (booking['refundReason'] as String? ?? 'N/A').replaceAll('_', ' ').toUpperCase(),
                                      ),
                                      const SizedBox(height: 6),
                                      if (booking['refundedAt'] != null)
                                        _buildInfoRow(
                                          'Refunded On',
                                          DateFormat.yMMMd().add_jm().format((booking['refundedAt'] as Timestamp).toDate()),
                                        ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.fitness_center, color: Colors.white70, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          sharingConfirmed ? 'Calorie data is shared' : 'Calorie data is not shared',
                                          style: TextStyle(
                                            color: sharingConfirmed ? Colors.greenAccent : Colors.orangeAccent,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (status == 'pending' && paymentStatus != 'paid_held' && paymentStatus != 'refunded')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final sessionFee = await _getSessionFee(booking['trainerId']);
                                              if (sessionFee > 0 && context.mounted) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => PaymentPage(
                                                      bookingId: bookingDoc.id,
                                                      trainerId: booking['trainerId'],
                                                      amount: sessionFee,
                                                      trainerName: trainerName,
                                                      specialization: booking['trainerSpecialization'] as String? ?? 'No specialization',
                                                      experience: booking['trainerExperience'] as int? ?? 0,
                                                      bookingDateTime:
                                                          booking['formattedDateTime'] ?? 'No schedule',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade400,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: const Text(
                                              'Pay Now',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
} 