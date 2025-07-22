import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:async/async.dart';
import '../models/admin_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();

      return adminDoc.exists && (adminDoc.data()?['isActive'] ?? false);
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Get admin details
  Future<AdminModel?> getCurrentAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final adminDoc = await _firestore
          .collection('admins')
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) return null;

      return AdminModel.fromMap(adminDoc.data()!, adminDoc.id);
    } catch (e) {
      print('Error getting admin details: $e');
      return null;
    }
  }

  // Get all users
  Stream<List<UserModel>> getAllUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get all trainers
  Stream<List<UserModel>> getAllTrainers() {
    final stream1 = _firestore.collection('trainers').snapshots();
    final stream2 = _firestore.collection('trainer').snapshots();

    return StreamGroup.merge([stream1, stream2]).map((snapshot) {
      final trainers = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
      print(
          '[AdminService.getAllTrainers] Fetched ${trainers.length} trainers from collection ${snapshot.metadata.isFromCache ? "cache" : "server"}.');
      return trainers;
    });
  }

  // Update user status
  Future<void> updateUserStatus(String userId, bool isActive) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .update({'isActive': isActive});
  }

  // Update trainer verification status
  Future<void> updateTrainerVerification(String trainerId, bool isVerified) async {
    await _firestore
        .collection('trainers')
        .doc(trainerId)
        .update({'isVerified': isVerified});
  }

  // Get analytics data
  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      
      // Try fetching both 'trainers' and 'trainer' collections to debug
      final trainersSnapshot = await _firestore.collection('trainers').get();
      final trainerSingularSnapshot = await _firestore.collection('trainer').get();
      
      final totalTrainers = trainersSnapshot.size + trainerSingularSnapshot.size;

      final activeBookingsSnapshot = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'active')
          .get();

      print(
          'Fetched counts - Users: ${usersSnapshot.size}, Trainers: $totalTrainers (trainers: ${trainersSnapshot.size}, trainer: ${trainerSingularSnapshot.size}), Bookings: ${activeBookingsSnapshot.size}'); // Debug log

      final analytics = {
        'totalUsers': usersSnapshot.size,
        'totalTrainers': totalTrainers,
        'activeBookings': activeBookingsSnapshot.size,
        'revenue': 0, // Add revenue calculation later
      };

      print('Returning analytics: $analytics'); // Debug log
      return analytics;
    } catch (e) {
      print('Error getting analytics: $e');
      return {
        'totalUsers': 0,
        'totalTrainers': 0,
        'activeBookings': 0,
        'revenue': 0,
      };
    }
  }

  // Create a new admin
  Future<void> createAdmin({
    required String email,
    required String password,
    required String name,
    required List<String> permissions,
  }) async {
    try {
      // Create auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create admin document
      await _firestore.collection('admins').doc(userCredential.user!.uid).set({
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'permissions': permissions,
        'isActive': true,
      });
    } catch (e) {
      print('Error creating admin: $e');
      rethrow;
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  // Delete trainer
  Future<void> deleteTrainer(String trainerId) async {
    // Attempt to delete from both collections to handle naming inconsistencies.
    try {
      await _firestore.collection('trainers').doc(trainerId).delete();
    } catch (e) {
      print('Could not delete from "trainers" collection: $e');
    }
    try {
      await _firestore.collection('trainer').doc(trainerId).delete();
    } catch (e) {
      print('Could not delete from "trainer" collection: $e');
    }
  }

  // Update admin profile
  Future<void> updateAdminProfile(String adminId, String newName) async {
    try {
      await _firestore
          .collection('admins')
          .doc(adminId)
          .update({'name': newName});
    } catch (e) {
      print('Error updating admin profile: $e');
      rethrow;
    }
  }

  // Get system settings
  Future<Map<String, dynamic>> getSystemSettings() async {
    final doc = await _firestore.collection('settings').doc('system').get();
    return doc.data() ?? {};
  }

  // Update system settings
  Future<void> updateSystemSettings(Map<String, dynamic> settings) async {
    await _firestore.collection('settings').doc('system').update(settings);
  }

  // Get pending escrow payments
  Stream<List<Map<String, dynamic>>> getPendingEscrowPayments() {
    return _firestore
        .collection('admin_escrow_payments')
        .where('adminStatus', isEqualTo: 'pending_release')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  // Get escrow payments that are available for release (excluding refunded ones)
  Stream<List<Map<String, dynamic>>> getEscrowPaymentsForRelease() {
    return _firestore
        .collection('admin_escrow_payments')
        .where('adminStatus', whereIn: ['pending', 'held', 'pending_release'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Get all escrow payments (including refunded ones for history)
  Stream<List<Map<String, dynamic>>> getAllEscrowPayments() {
    return _firestore
        .collection('admin_escrow_payments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Release payment to trainer
  Future<void> releasePaymentToTrainer(String paymentId, String paymentIntentId) async {
    try {
      // --- Step 1: Capture Payment Intent on Stripe ---
      final captureResponse = await http.post(
        Uri.parse('https://gtfinder.onrender.com/capture-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'paymentIntentId': paymentIntentId}),
      );

      if (captureResponse.statusCode != 200) {
        print(
            'Failed to capture payment intent: ${captureResponse.body}. Status: ${captureResponse.statusCode}');
        throw Exception(
            'Failed to capture payment. It might have already been captured or cancelled.');
      } else {
        print('Payment successfully captured in Stripe.');
      }

      final batch = _firestore.batch();
      final escrowDocRef =
          _firestore.collection('admin_escrow_payments').doc(paymentId);
      final escrowDoc = await escrowDocRef.get();

      if (!escrowDoc.exists) {
        throw Exception('Escrow payment document not found.');
      }
      final escrowData = escrowDoc.data()!;
      final trainerId = escrowData['trainerId'];
      final bookingId = escrowData['bookingId'];

      // Update the status of the escrow payment
      batch.update(escrowDocRef, {'adminStatus': 'released'});

      // Update the status in the original booking
      batch.update(_firestore.collection('bookings').doc(bookingId),
          {'paymentStatus': 'released'});

      // Set the calorie sharing expiry date
      final bookingDoc =
          await _firestore.collection('bookings').doc(bookingId).get();
      if (bookingDoc.exists) {
        final sessionTimestamp =
            bookingDoc.data()?['sessionDateTime'] as Timestamp?;
        if (sessionTimestamp != null) {
          final expiryTime =
              sessionTimestamp.toDate().add(const Duration(hours: 24));
          batch.update(_firestore.collection('bookings').doc(bookingId), {
            'calorieSharingExpiry': Timestamp.fromDate(expiryTime),
          });
        }
      }

      await batch.commit();

      // Create notification for trainer AFTER the batch commits
      final notificationService = NotificationService();
      await notificationService.createPaymentReleasedNotification(
        trainerId: trainerId,
        userName: escrowData['userName'],
        amount: escrowData['amount'],
        bookingId: bookingId,
      );
    } catch (e) {
      print('Error releasing payment to trainer: $e');
      rethrow;
    }
  }

  // Update admin name
  Future<void> updateAdminName(String newName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No authenticated user found';

      await _firestore.collection('admins').doc(user.uid).update({
        'name': newName,
      });
    } catch (e) {
      print('Error updating admin name: $e');
      rethrow;
    }
  }

  // Create a test trainer
  Future<void> createTestTrainer() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No authenticated user found';

      final trainerData = {
        'name': 'Test Trainer',
        'email': 'trainer@example.com',
        'specialization': 'General Fitness',
        'experience': 5,
        'sessionFee': 100.0,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('trainer').doc('test_trainer_id').set(trainerData);
    } catch (e) {
      print('Error creating test trainer: $e');
      rethrow;
    }
  }

  // Refund payment when trainer cancels booking
  Future<void> refundPaymentForCancelledBooking({
    required String bookingId,
    required String paymentIntentId,
    required String userId,
    required String trainerId,
    required double amount,
    required String reason,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'No authenticated user found';

      // Call the refund endpoint
      final response = await http.post(
        Uri.parse('https://gtfinder.onrender.com/refund-payment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'paymentIntentId': paymentIntentId,
          'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw errorData['error'] ?? 'Failed to refund payment';
      }

      final refundData = json.decode(response.body);
      
      // Start a batch write to update all related documents
      final batch = _firestore.batch();

      // Create refund record
      final refundRecord = {
        'bookingId': bookingId,
        'paymentIntentId': paymentIntentId,
        'userId': userId,
        'trainerId': trainerId,
        'amount': amount,
        'refundId': refundData['refundId'],
        'refundStatus': refundData['status'],
        'refundReason': reason,
        'refundedBy': user.uid,
        'refundedAt': FieldValue.serverTimestamp(),
        'adminNotes': 'Refunded due to trainer cancellation',
        'initiatedBy': user.uid == trainerId ? 'trainer' : 'admin',
      };

      // Add refund record to admin refunds collection
      final adminRefundRef = _firestore.collection('admin_refunds').doc();
      batch.set(adminRefundRef, refundRecord);

      // Update user's payment status
      final userPaymentQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .where('paymentIntentId', isEqualTo: paymentIntentId)
          .get();

      if (userPaymentQuery.docs.isNotEmpty) {
        batch.update(userPaymentQuery.docs.first.reference, {
          'status': 'refunded',
          'refundId': refundData['refundId'],
          'refundedAt': FieldValue.serverTimestamp(),
          'refundReason': reason,
        });
      }

      // Update trainer's payment status
      final trainerPaymentQuery = await _firestore
          .collection('trainer')
          .doc(trainerId)
          .collection('payments')
          .where('paymentIntentId', isEqualTo: paymentIntentId)
          .get();

      if (trainerPaymentQuery.docs.isNotEmpty) {
        batch.update(trainerPaymentQuery.docs.first.reference, {
          'status': 'refunded',
          'refundId': refundData['refundId'],
          'refundedAt': FieldValue.serverTimestamp(),
          'refundReason': reason,
        });
      }

      // Update booking status to include refund information
      final bookingUpdates = {
        'paymentStatus': 'refunded',
        'refundId': refundData['refundId'],
        'refundedAt': FieldValue.serverTimestamp(),
        'refundReason': reason,
        'refundedBy': user.uid,
      };

      // Update booking in all collections
      batch.update(
        _firestore.collection('bookings').doc(bookingId),
        bookingUpdates,
      );

      batch.update(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('bookings')
            .doc(bookingId),
        bookingUpdates,
      );

      batch.update(
        _firestore
            .collection('trainer')
            .doc(trainerId)
            .collection('bookings')
            .doc(bookingId),
        bookingUpdates,
      );

      // Remove from admin escrow if it exists
      final escrowQuery = await _firestore
          .collection('admin_escrow_payments')
          .where('paymentIntentId', isEqualTo: paymentIntentId)
          .get();

      if (escrowQuery.docs.isNotEmpty) {
        batch.update(escrowQuery.docs.first.reference, {
          'adminStatus': 'refunded',
          'refundedAt': FieldValue.serverTimestamp(),
          'refundReason': reason,
        });
      }

      await batch.commit();

      // Create notifications for user, confirming the refund has been processed.
      final notificationService = NotificationService();
      await notificationService.createRefundNotification(
        userId: userId,
        amount: amount,
        bookingId: bookingId,
        reason: 'Your booking was cancelled and your refund has been processed by the admin.',
      );

    } catch (e) {
      print('Error refunding payment: $e');
      rethrow;
    }
  }

  // Trainer-initiated refund (doesn't require admin authentication)
  Future<void> processTrainerRefund({
    required String bookingId,
    required String paymentIntentId,
    required String userId,
    required String trainerId,
    required double amount,
    required String reason,
  }) async {
    try {
      // Call the refund endpoint
      final response = await http.post(
        Uri.parse('https://gtfinder.onrender.com/refund-payment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'paymentIntentId': paymentIntentId,
          'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = json.decode(response.body);
        throw errorData['error'] ?? 'Failed to refund payment';
      }

      final refundData = json.decode(response.body);
      
      // Start a batch write to update all related documents
      final batch = _firestore.batch();

      // Create refund record
      final refundRecord = {
        'bookingId': bookingId,
        'paymentIntentId': paymentIntentId,
        'userId': userId,
        'trainerId': trainerId,
        'amount': amount,
        'refundId': refundData['refundId'],
        'refundStatus': refundData['status'],
        'refundReason': reason,
        'refundedBy': trainerId,
        'refundedAt': FieldValue.serverTimestamp(),
        'adminNotes': 'Refunded due to trainer cancellation',
        'initiatedBy': 'trainer',
      };

      // Add refund record to admin refunds collection
      final adminRefundRef = _firestore.collection('admin_refunds').doc();
      batch.set(adminRefundRef, refundRecord);

      // Update user's payment status
      final userPaymentQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .where('paymentIntentId', isEqualTo: paymentIntentId)
          .get();

      if (userPaymentQuery.docs.isNotEmpty) {
        batch.update(userPaymentQuery.docs.first.reference, {
          'status': 'refunded',
          'refundId': refundData['refundId'],
          'refundedAt': FieldValue.serverTimestamp(),
          'refundReason': reason,
        });
      }

      // Update trainer's payment status
      final trainerPaymentQuery = await _firestore
          .collection('trainer')
          .doc(trainerId)
          .collection('payments')
          .where('paymentIntentId', isEqualTo: paymentIntentId)
          .get();

      if (trainerPaymentQuery.docs.isNotEmpty) {
        batch.update(trainerPaymentQuery.docs.first.reference, {
          'status': 'refunded',
          'refundId': refundData['refundId'],
          'refundedAt': FieldValue.serverTimestamp(),
          'refundReason': reason,
        });
      }

      // Update booking status to include refund information
      final bookingUpdates = {
        'paymentStatus': 'refunded',
        'refundId': refundData['refundId'],
        'refundedAt': FieldValue.serverTimestamp(),
        'refundReason': reason,
        'refundedBy': trainerId,
      };

      // Update booking in all collections
      batch.update(
        _firestore.collection('bookings').doc(bookingId),
        bookingUpdates,
      );

      batch.update(
        _firestore
            .collection('users')
            .doc(userId)
            .collection('bookings')
            .doc(bookingId),
        bookingUpdates,
      );

      batch.update(
        _firestore
            .collection('trainer')
            .doc(trainerId)
            .collection('bookings')
            .doc(bookingId),
        bookingUpdates,
      );

      // Remove from admin escrow and mark as refunded
      final escrowQuery = await _firestore
          .collection('admin_escrow_payments')
          .where('paymentIntentId', isEqualTo: paymentIntentId)
          .get();

      if (escrowQuery.docs.isNotEmpty) {
        // Update the escrow payment to mark it as refunded
        batch.update(escrowQuery.docs.first.reference, {
          'adminStatus': 'refunded',
          'refundedAt': FieldValue.serverTimestamp(),
          'refundReason': reason,
          'refundId': refundData['refundId'],
          'refundedBy': trainerId,
        });
      } else {
        // If not found in escrow, check if there's a payment record to move to refunds
        final paymentQuery = await _firestore
            .collection('admin_escrow_payments')
            .where('bookingId', isEqualTo: bookingId)
            .get();

        if (paymentQuery.docs.isNotEmpty) {
          // Update the payment to mark it as refunded
          batch.update(paymentQuery.docs.first.reference, {
            'adminStatus': 'refunded',
            'refundedAt': FieldValue.serverTimestamp(),
            'refundReason': reason,
            'refundId': refundData['refundId'],
            'refundedBy': trainerId,
          });
        }
      }

      await batch.commit();

      // Create notifications
      final notificationService = NotificationService();
      
      // Notify user about refund
      await notificationService.createRefundNotification(
        userId: userId,
        amount: amount,
        bookingId: bookingId,
        reason: reason,
      );

      // Notify trainer about refund
      await notificationService.createTrainerRefundNotification(
        trainerId: trainerId,
        amount: amount,
        bookingId: bookingId,
        reason: reason,
      );

    } catch (e) {
      print('Error processing trainer refund: $e');
      rethrow;
    }
  }

  // Send an announcement to a target audience
  Future<void> sendAnnouncement({
    required String title,
    required String message,
    required String audience, // 'everyone', 'users_only', 'trainers_only'
  }) async {
    final notificationService = NotificationService();
    // Use a Set to automatically handle duplicate IDs.
    Set<String> recipientIds = {};

    // Get user IDs based on the selected audience
    if (audience == 'everyone' || audience == 'users_only') {
      final usersSnapshot = await _firestore.collection('users').get();
      for (final doc in usersSnapshot.docs) {
        recipientIds.add(doc.id);
      }
    }

    if (audience == 'everyone' || audience == 'trainers_only') {
      final trainersSnapshot = await _firestore.collection('trainers').get();
      final trainerSingularSnapshot = await _firestore.collection('trainer').get();
      for (final doc in trainersSnapshot.docs) {
        recipientIds.add(doc.id);
      }
      for (final doc in trainerSingularSnapshot.docs) {
        recipientIds.add(doc.id);
      }
    }

    if (recipientIds.isEmpty) {
      print('No recipients found for the announcement.');
      return;
    }

    // Create a notification for each recipient
    for (String userId in recipientIds) {
      await notificationService.createNotification(
        userId: userId,
        title: title,
        body: message,
        type: NotificationType.announcement,
      );
    }

    print('Announcement sent to ${recipientIds.length} unique recipients.');
  }

  // When a trainer cancels, this method marks the payment for a manual refund by an admin.
  Future<void> requestRefundForCancelledBooking({
    required String bookingId,
    required String paymentIntentId,
  }) async {
    try {
      final escrowQuery = await _firestore
          .collection('admin_escrow_payments')
          .where('paymentIntentId', isEqualTo: paymentIntentId)
          .get();

      if (escrowQuery.docs.isNotEmpty) {
        final docId = escrowQuery.docs.first.id;
        await _firestore
            .collection('admin_escrow_payments')
            .doc(docId)
            .update({
          'adminStatus': 'pending_refund',
          'cancellationReason': 'trainer_cancellation',
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating payment status to pending_refund: $e');
      // We don't rethrow because the cancellation should proceed.
      // The admin will see the cancellation and can handle the refund manually.
    }
  }

  // Get all refunds (combines admin_refunds and escrow payments that were refunded)
  Stream<List<Map<String, dynamic>>> getAllRefunds() {
    return Rx.combineLatest2(
      _firestore
          .collection('admin_refunds')
          .orderBy('refundedAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                data['source'] = 'admin_refunds';
                return data;
              }).toList()),
      _firestore
          .collection('admin_escrow_payments')
          .where('adminStatus', isEqualTo: 'refunded')
          .orderBy('refundedAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                data['source'] = 'escrow_refunded';
                // Map escrow fields to refund fields for consistency
                data['refundStatus'] = data['adminStatus'] ?? 'succeeded';
                data['refundReason'] = data['refundReason'] ?? 'Trainer cancellation';
                data['initiatedBy'] = data['refundedBy'] != null ? 'trainer' : 'admin';
                return data;
              }).toList()),
      (List<Map<String, dynamic>> adminRefunds, List<Map<String, dynamic>> escrowRefunds) {
        final allRefunds = [...adminRefunds, ...escrowRefunds];
        // Sort by refundedAt timestamp (most recent first)
        allRefunds.sort((a, b) {
          final aTime = a['refundedAt'] as Timestamp?;
          final bTime = b['refundedAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        return allRefunds;
      },
    );
  }

  // Get escrow payments that are pending a manual refund by an admin.
  Stream<List<Map<String, dynamic>>> getPaymentsPendingRefund() {
    return _firestore
        .collection('admin_escrow_payments')
        .where('adminStatus', isEqualTo: 'pending_refund')
        .orderBy('lastUpdated', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Get active bookings
  Stream<List<Map<String, dynamic>>> getActiveBookings() {
    return _firestore
        .collection('bookings')
        .where('status', whereIn: ['active', 'confirmed'])
        .orderBy('bookingDateTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }
} 