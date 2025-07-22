import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> getUserRole() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Check if user is admin
      final adminDoc = await _firestore.collection('admins').doc(user.uid).get();
      if (adminDoc.exists && adminDoc.data()?['isActive'] == true) {
        return 'admin';
      }

      // Check if user is trainer (checking both singular and plural forms for robustness)
      DocumentSnapshot trainerDoc = await _firestore.collection('trainers').doc(user.uid).get();
      if (!trainerDoc.exists) {
        // If not found in 'trainers', check 'trainer' as a fallback.
        trainerDoc = await _firestore.collection('trainer').doc(user.uid).get();
      }
      if (trainerDoc.exists) {
        return 'trainer';
      }

      // Check if user is regular user
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        return 'user';
      }

      return null;
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  Future<void> initializeAdminUser() async {
    print('[AuthService] Starting robust admin initialization...');
    const String adminEmail = 'admin@example.com';
    const String adminPassword = 'securepassword';

    try {
      // Use fetchSignInMethodsForEmail as it's a non-destructive check.
      // It avoids the risk of a startup crash due to credential issues.
      final signInMethods = await _auth.fetchSignInMethodsForEmail(adminEmail);

      if (signInMethods.isEmpty) {
        // Case 1: User does not exist, so we create them.
        print('[AuthService] Admin user not found by email. Creating user and Firestore document...');
        try {
          final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: adminEmail,
            password: adminPassword,
          );
          final User newUser = userCredential.user!;
          print('[AuthService] Admin user CREATED in Firebase Auth with UID: ${newUser.uid}');

          await _firestore.collection('admins').doc(newUser.uid).set({
            'email': adminEmail,
            'name': 'Admin',
            'role': 'admin',
            'isActive': true,
            'permissions': [
              'manage_users',
              'manage_trainers',
              'view_analytics',
              'manage_settings',
            ],
          });
          print('[AuthService] Admin document CREATED in Firestore.');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            // This is a recovery case where the initial check was inconsistent.
            // We log it but do not crash the app, assuming the user exists as intended.
            print('[AuthService] WARNING: Inconsistent state detected. Check reported no user, but creation failed. Assuming user exists.');
          } else {
            // Any other error during creation is critical.
            print('[AuthService] CRITICAL error during admin creation: ${e.code}');
            rethrow;
          }
        }
      } else {
        // Case 2: User already exists. We do nothing more at startup.
        print('[AuthService] Admin user email already exists. Initialization complete.');
      }
    } catch (e) {
      print('[AuthService] A fatal error occurred during admin initialization: $e');
      // Rethrow to signal a critical failure in the startup process.
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final role = await getUserRole();
      
      if (role == null) {
        await _auth.signOut();
        throw 'User account not found';
      }

      // Check if user is active
      if (role == 'admin') {
        final adminDoc = await _firestore.collection('admins').doc(userCredential.user!.uid).get();
        if (!(adminDoc.data()?['isActive'] ?? true)) {
          await _auth.signOut();
          throw 'Admin account is inactive';
        }
      } else if (role == 'user' || role == 'trainer') {
        final collection = role == 'user' ? 'users' : 'trainers';
        final doc = await _firestore.collection(collection).doc(userCredential.user!.uid).get();
        if (!(doc.data()?['isActive'] ?? true)) {
          await _auth.signOut();
          throw 'Account is inactive';
        }
      }
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }
} 