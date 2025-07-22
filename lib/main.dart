import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/login_page.dart';
import 'pages/user/user_landing_page.dart';
import 'pages/trainer/trainer_landing_page.dart';
import 'pages/admin/admin_dashboard.dart';
import 'services/auth_service.dart';
import 'services/admin_service.dart';
import 'services/trainer_location_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  print('[main.dart] App starting...');
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('[main.dart] WidgetsFlutterBinding initialized.');

    await Firebase.initializeApp();
    print('[main.dart] Firebase initialized successfully.');

    tz.initializeTimeZones();
    print('[main.dart] Timezones initialized.');

    // Use the new centralized admin initializer from AuthService
    print('[main.dart] Starting admin initialization...');
    await AuthService().initializeAdminUser();
    print('[main.dart] Admin initialization complete.');

    // Initialize location tracking for trainers if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final trainerDoc = await FirebaseFirestore.instance
            .collection('trainer')
            .doc(user.uid)
            .get();
        if (trainerDoc.exists) {
          print('[main.dart] Trainer detected, initializing location tracking...');
          await TrainerLocationService.startLocationTracking();
          print('[main.dart] Location tracking initialized for trainer.');
        }
      } catch (e) {
        print('[main.dart] Error initializing location tracking: $e');
      }
    }

    runApp(const MyApp());
    print('[main.dart] runApp() called.');
  } catch (e) {
    print('!!!!!!!!!! CRITICAL ERROR DURING INITIALIZATION !!!!!!!!!!');
    print(e);
    print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GT Finder',
      theme: ThemeData(
        primaryColor: const Color(0xFF1A2468),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const LoginPage();
          }

          return FutureBuilder<String?>(
            future: _authService.getUserRole(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              switch (roleSnapshot.data) {
                case 'admin':
                  return const AdminDashboard();
                case 'trainer':
                  return const TrainerLandingPage();
                case 'user':
                  return const UserLandingPage();
                default:
                  return const LoginPage();
              }
            },
          );
        },
      ),
    );
  }
}
