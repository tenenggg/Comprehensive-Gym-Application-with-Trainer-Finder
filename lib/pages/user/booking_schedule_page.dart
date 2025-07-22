import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'payment_page.dart';

class BookingSchedulePage extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final String specialization;
  final int experience;
  final double sessionFee;

  const BookingSchedulePage({
    super.key,
    required this.trainerId,
    required this.trainerName,
    required this.specialization,
    required this.experience,
    required this.sessionFee,
  });

  @override
  State<BookingSchedulePage> createState() => _BookingSchedulePageState();
}

class _BookingSchedulePageState extends State<BookingSchedulePage> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  bool _isLoading = false;
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
          'Book Session',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Trainer Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.trainerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Specialization: ${widget.specialization}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Experience: ${widget.experience} years',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Session Fee: RM${widget.sessionFee.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Calendar Section
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
                              _selectedTimeSlot = null; // Reset time slot when date changes
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
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('trainer')
                    .doc(widget.trainerId)
                    .collection('bookings')
                    .where('bookingDate', isEqualTo: Timestamp.fromDate(
                      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
                    ))
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
                  
                  // Get booked slots (only pending and confirmed)
                  final bookedSlots = bookings.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = (data['status'] ?? '').toLowerCase();
                    return status == 'pending' || status == 'confirmed';
                  }).map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['timeSlot'] as String;
                  }).toSet();

                  // Filter available time slots (exclude booked slots and past time slots)
                  final availableTimeSlots = _getAvailableTimeSlots(bookedSlots);

                  // Show message when no time slots are available
                  if (availableTimeSlots.isEmpty) {
                    return Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: Colors.white.withOpacity(0.7),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isToday() ? 'No available time slots for today' : 'No available time slots for this date',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isToday() 
                                ? 'All time slots for today have either been booked or have passed.'
                                : 'Please select a different date or check back later.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: availableTimeSlots.length,
                    itemBuilder: (context, index) {
                      final timeSlot = availableTimeSlots[index];
                      final isSelected = timeSlot == _selectedTimeSlot;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(color: Colors.blue, width: 2)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: isSelected
                              ? null // Disable tap if already selected
                              : () {
                                  setState(() {
                                    _selectedTimeSlot = timeSlot;
                                  });
                                },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isSelected
                                        ? Icons.check_circle_outline
                                        : Icons.access_time,
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.white,
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
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Available',
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
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Continue Button
            Container(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _selectedTimeSlot == null || _isLoading
                    ? null
                    : () => _proceedToPayment(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Continue to Payment',
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
    );
  }

  Future<void> _proceedToPayment(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'User not logged in';
      }

      // Get user data to ensure we have the latest name
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw 'User profile not found';
      }

      // Get user's name from Firestore data
      final userData = userDoc.data() as Map<String, dynamic>;
      String userName = userData['name'] ?? '';
      
      // If name is still empty after checking user profile, throw error
      if (userName.isEmpty) {
        throw 'Please update your profile with your name before booking';
      }

      // Check if the slot is available
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('trainer')
          .doc(widget.trainerId)
          .collection('bookings')
          .where('bookingDate', isEqualTo: Timestamp.fromDate(
            DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
          ))
          .where('timeSlot', isEqualTo: _selectedTimeSlot)
          .get();

      // A slot is considered unavailable only if there's a booking that is 'pending' or 'confirmed'
      final isSlotTaken = bookingsSnapshot.docs.any((doc) {
        final status = (doc.data()['status'] ?? '').toLowerCase();
        return status == 'pending' || status == 'confirmed';
      });

      if (isSlotTaken) {
        throw 'This time slot is no longer available';
      }

      // Create a new booking document
      final bookingId = FirebaseFirestore.instance.collection('bookings').doc().id;
      final timestamp = FieldValue.serverTimestamp();
      
      final bookingData = {
        'bookingId': bookingId,
        'userId': user.uid,
        'name': userName,
        'userEmail': user.email,
        'trainerId': widget.trainerId,
        'trainerName': widget.trainerName,
        'bookingDate': Timestamp.fromDate(
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).toUtc(),
        ),
        'timeSlot': _selectedTimeSlot,
        'formattedDateTime':
            '${DateFormat('MMM d, yyyy').format(_selectedDate)} at $_selectedTimeSlot',
        'status': 'pending',
        'createdAt': timestamp,
        'timestamp': timestamp,
        'lastUpdated': timestamp,
        'paymentStatus': 'unpaid',
        'calorieSharingConfirmed': false,
        'calorieSharingExpiry': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))),
      };

      // Start a batch write
      final batch = FirebaseFirestore.instance.batch();

      // Add to user's bookings
      final userBookingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('bookings')
          .doc(bookingId);
      batch.set(userBookingRef, bookingData);

      // Add to trainer's bookings
      final trainerBookingRef = FirebaseFirestore.instance
          .collection('trainer')
          .doc(widget.trainerId)
          .collection('bookings')
          .doc(bookingId);
      batch.set(trainerBookingRef, bookingData);

      // Add to root bookings collection
      final rootBookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId);
      batch.set(rootBookingRef, bookingData);

      // Update trainer's clients reference with full user data
      final trainerClientsRef = FirebaseFirestore.instance
          .collection('trainer')
          .doc(widget.trainerId)
          .collection('clients')
          .doc(user.uid);
      batch.set(trainerClientsRef, {
        'userId': user.uid,
        'name': userName,
        'userEmail': user.email,
        'lastBooking': timestamp,
        'bookingsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Commit the batch
      await batch.commit();

      if (!mounted) return;

      // Ask user to confirm calorie sharing
      await _showCalorieSharingDialog(context, bookingId);

      // Navigate to payment page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentPage(
            bookingId: bookingId,
            trainerId: widget.trainerId,
            trainerName: widget.trainerName,
            specialization: widget.specialization,
            experience: widget.experience,
            bookingDateTime: '${DateFormat('MMM d, yyyy').format(_selectedDate)} at $_selectedTimeSlot',
            amount: widget.sessionFee,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showCalorieSharingDialog(BuildContext context, String bookingId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Calories?'),
        content: const Text('Do you want to share your calorie data with this trainer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({'calorieSharingConfirmed': result == true});
  }

  List<String> _getAvailableTimeSlots(Set<String> bookedSlots) {
    final now = DateTime.now();
    final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    // If selected date is today, filter out past time slots
    final isToday = selectedDate.year == now.year && 
                   selectedDate.month == now.month && 
                   selectedDate.day == now.day;
    
    return _timeSlots.where((slot) {
      // First, exclude booked slots
      if (bookedSlots.contains(slot)) {
        return false;
      }
      
      // If it's today, check if the time slot has passed
      if (isToday) {
        final slotTime = _parseTimeSlot(slot);
        final currentTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
        
        // Add 30 minutes buffer to current time to prevent booking too close to current time
        final bufferTime = currentTime.add(const Duration(minutes: 30));
        
        return slotTime.isAfter(bufferTime);
      }
      
      // If it's a future date, all slots are available (except booked ones)
      return true;
    }).toList();
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

  bool _isToday() {
    final now = DateTime.now();
    final selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selectedDate.year == now.year &&
           selectedDate.month == now.month &&
           selectedDate.day == now.day;
  }
} 