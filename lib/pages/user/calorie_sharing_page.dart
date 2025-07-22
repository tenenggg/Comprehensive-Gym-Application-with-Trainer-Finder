import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../widgets/profile_image_widget.dart';

class CalorieSharingPage extends StatelessWidget {
  const CalorieSharingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2468),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Calorie Sharing',
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
                    .where('status', whereIn: ['pending', 'confirmed', 'completed'])
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

                  final allBookings = snapshot.data?.docs ?? [];
                  final bookings = allBookings.where((doc) {
                    final data = doc.data() as Map<String, dynamic>?;
                    return data?['sharingEntryHidden'] != true;
                  }).toList();

                  if (bookings.isEmpty) {
                    return const Center(
                      child: Text(
                        'No active bookings found',
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  // Group bookings by trainer
                  final Map<String, List<QueryDocumentSnapshot>> trainerBookings = {};
                  for (var booking in bookings) {
                    final trainerId = booking['trainerId'] as String;
                    if (!trainerBookings.containsKey(trainerId)) {
                      trainerBookings[trainerId] = [];
                    }
                    trainerBookings[trainerId]!.add(booking);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: trainerBookings.length,
                    itemBuilder: (context, index) {
                      final trainerId = trainerBookings.keys.elementAt(index);
                      final trainerBookingsList = trainerBookings[trainerId]!;
                      final firstBooking = trainerBookingsList.first.data() as Map<String, dynamic>;
                      final trainerName = firstBooking['trainerName'] ?? 'Unknown Trainer';

                      return TrainerCalorieCard(
                        trainerId: trainerId,
                        trainerName: trainerName,
                        bookings: trainerBookingsList,
                        userId: userSnapshot.data!.uid,
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
}

class TrainerCalorieCard extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final List<QueryDocumentSnapshot> bookings;
  final String userId;

  const TrainerCalorieCard({
    super.key,
    required this.trainerId,
    required this.trainerName,
    required this.bookings,
    required this.userId,
  });

  @override
  State<TrainerCalorieCard> createState() => _TrainerCalorieCardState();
}

class _TrainerCalorieCardState extends State<TrainerCalorieCard> {
  bool _isExpanded = false;

  Future<void> _hideBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C3E50),
        title: const Text('Clear Session?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently hide this session from your sharing history list. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Clear', style: TextStyle(color: Colors.redAccent.shade100)),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('bookings')
            .doc(bookingId)
            .update({'sharingEntryHidden': true});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error hiding session: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('trainer')
                        .doc(widget.trainerId)
                        .get(),
                    builder: (context, trainerSnapshot) {
                      if (trainerSnapshot.hasData && trainerSnapshot.data!.exists) {
                        final trainerData = trainerSnapshot.data!.data() as Map<String, dynamic>?;
                        return ProfileImageDisplay(
                          imageUrl: trainerData?['profileImage'],
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
                    child: Text(
                      widget.trainerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),
                  ...widget.bookings.map((booking) {
                    final data = booking.data() as Map<String, dynamic>;
                    final bookingId = booking.id;
                    final schedule = data['formattedDateTime'] ?? 'Session';

                    final isSharingConfirmed = data['calorieSharingConfirmed'] == true;
                    final expiryTimestamp = data['calorieSharingExpiry'] as Timestamp?;
                    final isCompleted = data['status'] == 'completed';
                    
                    final isExpired = (expiryTimestamp != null && expiryTimestamp.toDate().isBefore(DateTime.now())) || 
                                      (isCompleted && expiryTimestamp == null);

                    final isSharingActive = isSharingConfirmed && !isExpired;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          tileColor: Colors.white.withOpacity(0.05),
                          title: Text(
                            schedule,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            isExpired
                                ? 'Sharing for this session has ended.'
                                : isSharingActive
                                    ? (expiryTimestamp != null
                                        ? 'Sharing is ON. Ends at ${DateFormat.jm().format(expiryTimestamp.toDate())}'
                                        : 'Sharing is ON.')
                                    : 'Sharing is OFF.',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isSharingActive,
                                onChanged: isExpired 
                                  ? null 
                                  : (bool value) {
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(widget.userId)
                                          .collection('bookings')
                                          .doc(bookingId)
                                          .update({'calorieSharingConfirmed': value});
                                    },
                                activeColor: Colors.greenAccent,
                              ),
                              if (isExpired)
                                IconButton(
                                  icon: const Icon(Icons.delete_sweep_outlined),
                                  color: Colors.redAccent.withOpacity(0.7),
                                  tooltip: 'Clear From List',
                                  onPressed: () => _hideBooking(bookingId),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }
} 