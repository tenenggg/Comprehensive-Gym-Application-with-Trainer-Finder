import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_page.dart';
import '../exercise/exercise_module_page.dart';
import '../gym_finder_page.dart';
import 'trainer_finder_page.dart';
import 'booking_view_page.dart';
import 'profile_page.dart';
import '../../widgets/calories_burn_box.dart';
import '../../widgets/notification_badge.dart';
import 'calorie_sharing_page.dart';
import '../../services/notification_service.dart';
import '../shared/notification_page.dart';
import '../../widgets/profile_image_widget.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class UserLandingPage extends StatefulWidget {
  const UserLandingPage({super.key});

  @override
  State<UserLandingPage> createState() => _UserLandingPageState();
}

class _UserLandingPageState extends State<UserLandingPage> {
  String _userName = '';
  String? _profileImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    NotificationService().triggerDailyNotificationScheduling();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          setState(() {
            _userName = userDoc.data()?['name'] ?? 'User';
            _profileImageUrl = userDoc.data()?['profileImage'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
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

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ProfileImageDisplay(
                              imageUrl: _profileImageUrl,
                              size: 64,
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue.shade100,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout_rounded),
                              color: Colors.red.shade300,
                              iconSize: 28,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Calories Burn Box
                      const CaloriesBurnBox(),
                      const SizedBox(height: 24),

                      // Quick Actions Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
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
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.grid_view_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Quick Actions',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 1.0,
                              children: [
                                _buildActionCard(
                                  context,
                                  'Find Gym',
                                  Icons.fitness_center,
                                  () => _navigateToPage(const GymFinderPage()),
                                ),
                                _buildActionCard(
                                  context,
                                  'Exercise',
                                  Icons.sports_gymnastics,
                                  () => _navigateToPage(ExerciseModulePage(isTrainer: false)),
                                ),
                                _buildActionCard(
                                  context,
                                  'Find Trainer',
                                  Icons.person_outline,
                                  () => _navigateToPage(const TrainerFinderPage()),
                                ),
                                _buildActionCard(
                                  context,
                                  'View Booking',
                                  Icons.calendar_today,
                                  () => _navigateToPage(const BookingViewPage()),
                                ),
                                _buildActionCard(
                                  context,
                                  'Notifications',
                                  Icons.notifications_outlined,
                                  () => _navigateToPage(const NotificationPage(isTrainer: false)),
                                ),
                                _buildActionCard(
                                  context,
                                  'Profile',
                                  Icons.settings_outlined,
                                  () => _navigateToPage(const ProfilePage()),
                                ),
                                _buildActionCard(
                                  context,
                                  'Calorie Sharing',
                                  Icons.share_outlined,
                                  () => _navigateToPage(const CalorieSharingPage()),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    final iconContainer = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 24,
        color: Colors.white,
      ),
    );

    final cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: title == 'Notifications'
                      ? NotificationBadge(
                          child: iconContainer,
                          size: 18,
                          backgroundColor: const Color(0xFFFF3B30),
                        )
                      : iconContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return cardContent;
  }
} 