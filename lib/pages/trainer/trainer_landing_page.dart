import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_page.dart';
import 'client_list_page.dart';
import '../exercise/exercise_module_page.dart';
import '../gym_finder_page.dart';
import 'schedule_page.dart';
import 'trainer_profile_page.dart';
import 'payments_page.dart';
import '../../widgets/calories_burn_box.dart';
import '../../widgets/notification_badge.dart';
import 'calorie_sharing_page.dart';
import '../shared/notification_page.dart';
import '../../services/trainer_location_service.dart';
import '../../widgets/profile_image_widget.dart';

class TrainerLandingPage extends StatefulWidget {
  const TrainerLandingPage({super.key});

  @override
  State<TrainerLandingPage> createState() => _TrainerLandingPageState();
}

class _TrainerLandingPageState extends State<TrainerLandingPage> {
  final String _trainerName = '';
  final bool _isLoading = true;
  late Stream<DocumentSnapshot> _trainerStream;
  bool _locationTrackingStarted = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _setupTrainerStream();
    _initializeLocationTracking();
  }

  @override
  void dispose() {
    // Don't stop location tracking on dispose as we want it to continue in background
    super.dispose();
  }

  void _setupTrainerStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _trainerStream = FirebaseFirestore.instance
          .collection('trainer')
          .doc(user.uid)
          .snapshots();
    }
  }

  Future<void> _initializeLocationTracking() async {
    try {
      // Check location tracking status
      final status = await TrainerLocationService.getLocationTrackingStatus();
      
      if (status['isLoggedIn'] && status['isTrainer']) {
        if (!status['locationServicesEnabled']) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enable location services for automatic location updates'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
        
        if (!status['locationPermissionGranted']) {
          // Request location permission and start tracking
          final success = await TrainerLocationService.requestLocationPermissionAndStartTracking();
          if (success) {
            setState(() {
              _locationTrackingStarted = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location tracking started automatically'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location permission required for automatic updates'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } else if (!status['isTrackingActive']) {
          // Start tracking if permissions are already granted
          await TrainerLocationService.startLocationTracking();
          setState(() {
            _locationTrackingStarted = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location tracking started automatically'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          setState(() {
            _locationTrackingStarted = true;
          });
        }
      }
    } catch (e) {
      print('Error initializing location tracking: $e');
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

  void _navigateToPage(BuildContext context, String route) {
    if (route == '/trainer/notifications') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotificationPage(isTrainer: true)),
      );
    } else if (route == '/trainer/client_list') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ClientListPage()),
      );
    } else if (route == '/trainer/exercise_module') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ExerciseModulePage(isTrainer: true)),
      );
    } else if (route == '/trainer/gym_finder') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GymFinderPage()),
      );
    } else if (route == '/trainer/schedule') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SchedulePage()),
      );
    } else if (route == '/trainer/profile') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TrainerProfilePage()),
      );
    } else if (route == '/trainer/calorie_sharing') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TrainerCalorieSharingPage()),
      );
    } else if (route == '/trainer/payments') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PaymentsPage()),
      );
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
          bottom: false,
          child: StreamBuilder<DocumentSnapshot>(
            stream: _trainerStream,
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

              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final name = data?['name'] as String? ?? 'Trainer';
              _profileImageUrl = data?['profileImage'];

              return SingleChildScrollView(
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
                      child: Column(
                        children: [
                          Row(
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
                                      name,
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
                          // Location tracking status
                          if (_locationTrackingStarted) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.my_location,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Location tracking active',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Calories Burn Box
                    const CaloriesBurnBox(isTrainer: true),
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
                                'Client List',
                                Icons.people_outline,
                                () => _navigateToPage(context, '/trainer/client_list'),
                              ),
                              _buildActionCard(
                                context,
                                'Exercise',
                                Icons.fitness_center,
                                () => _navigateToPage(context, '/trainer/exercise_module'),
                              ),
                              _buildActionCard(
                                context,
                                'Gym Finder',
                                Icons.location_on_outlined,
                                () => _navigateToPage(context, '/trainer/gym_finder'),
                              ),
                              _buildActionCard(
                                context,
                                'Schedule',
                                Icons.calendar_month,
                                () => _navigateToPage(context, '/trainer/schedule'),
                              ),
                              _buildActionCard(
                                context,
                                'Payments',
                                Icons.payment_outlined,
                                () => _navigateToPage(context, '/trainer/payments'),
                              ),
                              _buildActionCard(
                                context,
                                'Notifications',
                                Icons.notifications,
                                () => _navigateToPage(context, '/trainer/notifications'),
                              ),
                              _buildActionCard(
                                context,
                                'Profile',
                                Icons.person_outline,
                                () => _navigateToPage(context, '/trainer/profile'),
                              ),
                              _buildActionCard(
                                context,
                                'Calorie Sharing',
                                Icons.share,
                                () => _navigateToPage(context, '/trainer/calorie_sharing'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
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