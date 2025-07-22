import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/profile_image_widget.dart';

class TrainerCalorieSharingPage extends StatelessWidget {
  const TrainerCalorieSharingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final trainerUid = FirebaseAuth.instance.currentUser?.uid;
    if (trainerUid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in as trainer')),
      );
    }
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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('trainerId', isEqualTo: trainerUid)
                .where('calorieSharingConfirmed', isEqualTo: true)
                .where('status', whereIn: ['pending', 'confirmed'])
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
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              final bookings = snapshot.data?.docs ?? [];
              if (bookings.isEmpty) {
                return const Center(
                  child: Text(
                    'No users have shared their calories yet.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              // Group bookings by user
              final Map<String, List<QueryDocumentSnapshot>> userBookings = {};
              for (var booking in bookings) {
                final userId = booking['userId'] as String;
                if (!userBookings.containsKey(userId)) {
                  userBookings[userId] = [];
                }
                userBookings[userId]!.add(booking);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: userBookings.length,
                itemBuilder: (context, index) {
                  final userId = userBookings.keys.elementAt(index);
                  final userBookingsList = userBookings[userId]!;
                  final firstBooking = userBookingsList.first.data() as Map<String, dynamic>;
                  final userName = firstBooking['name'] ?? 'User';

                  return UserCalorieCard(
                    userId: userId,
                    userName: userName,
                    bookings: userBookingsList,
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

class UserCalorieCard extends StatefulWidget {
  final String userId;
  final String userName;
  final List<QueryDocumentSnapshot> bookings;

  const UserCalorieCard({
    super.key,
    required this.userId,
    required this.userName,
    required this.bookings,
  });

  @override
  State<UserCalorieCard> createState() => _UserCalorieCardState();
}

class _UserCalorieCardState extends State<UserCalorieCard> {
  bool _isExpanded = false;

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
                        .collection('users')
                        .doc(widget.userId)
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
                    child: Text(
                      widget.userName,
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
                  CalorieDataAndGoalWidget(userId: widget.userId),
                  const SizedBox(height: 16),
                  ...widget.bookings.map((booking) {
                    final data = booking.data() as Map<String, dynamic>;
                    final schedule = data['formattedDateTime'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Session: $schedule',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
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

class CalorieDataAndGoalWidget extends StatelessWidget {
  final String userId;
  const CalorieDataAndGoalWidget({required this.userId, super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDoc = DateTime(today.year, today.month, today.day).toIso8601String();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('daily_calories')
          .doc(todayDoc)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Error loading calories', style: TextStyle(color: Colors.red));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading calories...', style: TextStyle(color: Colors.white70));
        }
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final calories = data?['calories'] ?? 0;
        final goal = data?['goal'];
        if (goal != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Calories: $calories kcal",
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                "Today's Goal: $goal kcal",
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          );
        } else {
          // Fallback: fetch from user profile
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasError) {
                return const Text('Error loading goal', style: TextStyle(color: Colors.red));
              }
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Text('Loading goal...', style: TextStyle(color: Colors.white70));
              }
              final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
              final profileGoal = userData?['dailyCalorieGoal'];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Calories: $calories kcal",
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profileGoal != null
                        ? "Today's Goal: $profileGoal kcal"
                        : "No goal set",
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              );
            },
          );
        }
      },
    );
  }
} 