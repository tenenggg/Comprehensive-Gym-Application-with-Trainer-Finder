import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/admin_service.dart';
import '../../widgets/profile_image_widget.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _selectedDate = DateTime.now();
  final List<String> _timeSlots = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
    '07:00 PM',
    '08:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2468),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Schedule',
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
          child: Column(
            children: [
              // Compact Calendar Section
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _selectedDate = DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month - 1,
                                    _selectedDate.day,
                                  );
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _selectedDate = DateTime(
                                    _selectedDate.year,
                                    _selectedDate.month + 1,
                                    _selectedDate.day,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          final date = DateTime.now().add(Duration(days: index));
                          final isSelected = date.year == _selectedDate.year &&
                              date.month == _selectedDate.month &&
                              date.day == _selectedDate.day;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDate = date;
                              });
                            },
                            child: Container(
                              width: 60,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat('EEE').format(date),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('d').format(date),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.7),
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
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
                ),
              ),
              // Time Slots Section
              Expanded(
                child: StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(
                        child: Text(
                          'Please log in to view your schedule',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final trainerId = userSnapshot.data!.uid;
                    final selectedDateStart = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                    );
                    final selectedDateEnd = selectedDateStart.add(const Duration(days: 1));

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('trainer')
                          .doc(trainerId)
                          .collection('bookings')
                          .where('bookingDate', isGreaterThanOrEqualTo: Timestamp.fromDate(selectedDateStart))
                          .where('bookingDate', isLessThan: Timestamp.fromDate(selectedDateEnd))
                          .orderBy('bookingDate')
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
                        
                        // Group bookings by time slot and get the most recent one for each slot
                        final Map<String, Map<String, dynamic>> allBookingsBySlot = {};
                        for (var doc in bookings) {
                          final data = doc.data() as Map<String, dynamic>;
                          final timeSlot = data['timeSlot'] as String;
                          final timestamp = data['timestamp'] as Timestamp?;
                          final currentTimestamp = allBookingsBySlot[timeSlot]?['timestamp'] as Timestamp?;
                          
                          // Only update if this is a newer booking for the slot
                          if (!allBookingsBySlot.containsKey(timeSlot) ||
                              (timestamp != null && 
                               (currentTimestamp == null ||
                                timestamp.compareTo(currentTimestamp) > 0))) {
                            allBookingsBySlot[timeSlot] = data;
                          }
                        }

                        // Create a map of active bookings (pending or confirmed)
                        final activeBookings = Map.fromEntries(
                          allBookingsBySlot.entries.where((entry) {
                            final status = (entry.value['status'] ?? '').toLowerCase();
                            return status == 'pending' || status == 'confirmed';
                          })
                        );

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _timeSlots.length,
                          itemBuilder: (context, index) {
                            final timeSlot = _timeSlots[index];
                            final bookingData = allBookingsBySlot[timeSlot];
                            final isActiveBooking = activeBookings.containsKey(timeSlot);

                            // Check if the time slot has passed for today
                            final now = DateTime.now();
                            final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                            final isToday = selectedDate.year == now.year && 
                                           selectedDate.month == now.month && 
                                           selectedDate.day == now.day;
                            
                            bool isPastTime = false;
                            if (isToday) {
                              final slotTime = _parseTimeSlot(timeSlot);
                              final currentTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
                              isPastTime = slotTime.isBefore(currentTime);
                            }

                            // Show the slot as available if:
                            // 1. There's no booking at all
                            // 2. The booking exists but is cancelled or rejected
                            // 3. AND the time slot hasn't passed
                            final isAvailable = !isActiveBooking && !isPastTime;

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
                              child: InkWell(
                                onTap: bookingData != null
                                    ? () => _showBookingDetails(context, bookingData)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(bookingData?['status']).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getStatusIcon(bookingData?['status']),
                                          color: _getStatusColor(bookingData?['status']),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              timeSlot,
                                              style: TextStyle(
                                                color: isPastTime ? Colors.white.withOpacity(0.5) : Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (bookingData != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                bookingData['name'] ?? bookingData['userEmail'] ?? 'Unknown Client',
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.7),
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Status: ${(bookingData['status'] ?? 'pending').toUpperCase()}',
                                                style: TextStyle(
                                                  color: _getStatusColor(bookingData['status']),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ] else ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                isPastTime ? 'Time Passed' : 'Available',
                                                style: TextStyle(
                                                  color: isPastTime ? Colors.red.withOpacity(0.7) : Colors.white.withOpacity(0.7),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (bookingData != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(bookingData['status']).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _getStatusText(bookingData['status']),
                                            style: TextStyle(
                                              color: _getStatusColor(bookingData['status']),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2468),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Booking Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Client Information Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(booking['userId'])
                            .get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                            return ProfileImageDisplay(
                              imageUrl: userData?['profileImage'],
                              size: 48,
                            );
                          }
                          return Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking['name'] ?? booking['userEmail'] ?? 'Unknown Client',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Client ID: ${booking['userId']}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Booking Information Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    'Schedule',
                    booking['formattedDateTime'] ?? 'Not specified',
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'Status',
                    (booking['status'] ?? 'pending').toUpperCase(),
                  ),
                  if (booking['paymentStatus'] != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Payment',
                      booking['paymentStatus'].toUpperCase(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Action Buttons
            if (booking['status'] == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateBookingStatus(booking, 'confirmed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateBookingStatus(booking, 'rejected'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (booking['status'] == 'confirmed') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _updateBookingStatus(booking, 'cancelled'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel Booking',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateBookingStatus(Map<String, dynamic> booking, String status) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show confirmation dialog for cancellation
      if (status == 'cancelled') {
        final shouldCancel = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2A3A9E),
            title: const Text(
              'Cancel Booking',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to cancel this booking? This action cannot be undone and will trigger a refund to the user.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'No',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Yes, Cancel',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );

        if (shouldCancel != true) return;
      }

      // Start a batch write
      final batch = FirebaseFirestore.instance.batch();

      final Map<String, dynamic> updateData = {
        'status': status,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      };

      // First check if the documents exist
      final trainerBookingRef = FirebaseFirestore.instance
          .collection('trainer')
          .doc(user.uid)
          .collection('bookings')
          .doc(booking['bookingId']);

      final userBookingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(booking['userId'])
          .collection('bookings')
          .doc(booking['bookingId']);

      // Get both documents
      final trainerBookingDoc = await trainerBookingRef.get();
      final userBookingDoc = await userBookingRef.get();

      // Update or set the documents based on their existence
      if (trainerBookingDoc.exists) {
        batch.update(trainerBookingRef, updateData);
      } else {
        batch.set(trainerBookingRef, {...booking, ...updateData});
      }

      if (userBookingDoc.exists) {
        batch.update(userBookingRef, updateData);
      } else {
        batch.set(userBookingRef, {...booking, ...updateData});
      }

      // If cancelling, update the client's booking count
      if (status == 'cancelled') {
        final trainerClientsRef = FirebaseFirestore.instance
            .collection('trainer')
            .doc(user.uid)
            .collection('clients')
            .doc(booking['userId']);

        final clientDoc = await trainerClientsRef.get();
        
        if (clientDoc.exists) {
          batch.update(trainerClientsRef, {
            'bookingsCount': FieldValue.increment(-1),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        // Also update the booking data in both collections to mark it as cancelled
        final cancelledData = {
          ...booking,
          ...updateData,
          'cancelled': true,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': user.uid,
        };

        batch.set(trainerBookingRef, cancelledData, SetOptions(merge: true));
        batch.set(userBookingRef, cancelledData, SetOptions(merge: true));

        // Check if payment needs to be refunded
        final paymentStatus = booking['paymentStatus'];
        final paymentIntentId = booking['paymentIntentId'];
        
        if ((paymentStatus == 'paid' || paymentStatus == 'paid_held') && paymentIntentId != null) {
          // Mark payment for admin refund instead of processing automatically
          try {
            final adminService = AdminService();
            await adminService.requestRefundForCancelledBooking(
              bookingId: booking['bookingId'],
              paymentIntentId: paymentIntentId,
            );
          } catch (e) {
            print('Error flagging for refund: $e');
            // Continue with cancellation. Admin can manually check.
          }
        }
      }

      // Commit the batch
      await batch.commit();

      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking ${status.toUpperCase()}'),
          backgroundColor: _getStatusColor(status),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.white.withOpacity(0.7);
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.pending_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'completed':
        return Icons.task_alt;
      default:
        return Icons.event_available;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return 'CONFIRMED';
      case 'pending':
        return 'PENDING';
      case 'rejected':
        return 'REJECTED';
      case 'cancelled':
        return 'CANCELLED';
      case 'completed':
        return 'COMPLETED';
      default:
        return 'AVAILABLE';
    }
  }

  DateTime _parseTimeSlot(String timeSlot) {
    // Parse time slots like "09:00 AM", "02:00 PM"
    final parts = timeSlot.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final period = parts[1];
    
    // Convert to 24-hour format
    if (period == 'PM' && hour != 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }
    
    return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
  }
} 