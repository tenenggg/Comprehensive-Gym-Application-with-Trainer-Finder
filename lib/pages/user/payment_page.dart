import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../user/user_landing_page.dart';
import 'package:flutter/services.dart';
import '../../services/notification_service.dart';
import '../../widgets/profile_image_widget.dart';

class PaymentPage extends StatefulWidget {
  final String bookingId;
  final String trainerId;
  final String trainerName;
  final String specialization;
  final int experience;
  final String bookingDateTime;
  final double amount;

  const PaymentPage({
    super.key,
    required this.bookingId,
    required this.trainerId,
    required this.trainerName,
    required this.specialization,
    required this.experience,
    required this.bookingDateTime,
    required this.amount,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _isProcessing = false;
  String? _paymentIntentId;
  String? _trainerProfileImageUrl;
  bool _isProfileImageLoading = true;

  // Trainer details fetched from Firestore
  String? _trainerName;
  String? _trainerSpecialization;
  int? _trainerExperience;
  bool _isTrainerDetailsLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeStripe();
    _fetchTrainerDetails();
  }

  Future<void> _initializeStripe() async {
    try {
      print('Initializing Stripe...');
      // Initialize Stripe with your publishable key
      Stripe.publishableKey = 'pk_test_51QjJmZC8SPAz3zkOeGkX263Jwn2k9pO0lE1oFjlB5CnI99DcfRpT4E33UEWXrLazNrAzm7jabf6iw1Mc2zfTgHMe00jvLWCaEW';
      await Stripe.instance.applySettings();
      print('Stripe initialized successfully');
    } catch (e) {
      print('Error initializing Stripe: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing payment system: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _createPaymentIntent() async {
    try {
      print('Starting payment intent creation...');
      
      // Format amount as integer (cents)
      final amountInCents = (widget.amount * 100).round();
      print('Amount in cents: $amountInCents');
      
      // Create payment intent on your server
      print('Sending request to payment server...');
      
      // Use your deployed server URL or local IP address
      final Uri uri = Uri.parse('https://gtfinder.onrender.com/create-payment-intent');
      print('Attempting to connect to: $uri');
      
        final response = await http.post(
          uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
            'amount': amountInCents,
          }),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
          throw TimeoutException('Connection timed out. Please check your internet connection and try again.');
          },
        );

        if (response.statusCode == 200) {
        print('Payment intent created successfully');
        return json.decode(response.body);
      } else {
        print('Error response from server: ${response.body}');
        throw Exception('Failed to create payment intent: ${response.body}');
      }
    } catch (e) {
      print('Error creating payment intent: $e');
      if (e is TimeoutException) {
        throw Exception('Connection timed out. Please check your internet connection and try again.');
      }
      throw Exception('Failed to create payment intent: $e');
    }
  }

  Future<void> _processPayment() async {
    if (_isProcessing) return;
    
    try {
      setState(() => _isProcessing = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Get user's name from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userName = userDoc.data()?['name'] ?? 'User';

      // Create payment intent
      print('Creating payment intent...');
      final response = await http.post(
        Uri.parse('https://gtfinder.onrender.com/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': (widget.amount * 100).round(), // Convert to cents
          'currency': 'myr',
        }),
      );

      if (response.statusCode != 200) {
        // Handle server error gracefully
        print('Server error creating payment intent: ${response.body}');
        throw Exception(
            'Could not initiate payment. The server responded with an error.');
      }

      final paymentIntentData = jsonDecode(response.body);
      final clientSecret = paymentIntentData['clientSecret'] as String?;
      _paymentIntentId = paymentIntentData['paymentIntentId'] as String?;

      if (clientSecret == null || _paymentIntentId == null) {
        // Handle missing data from server
        print('Server response missing required data.');
        throw Exception(
            'Could not initiate payment. Invalid response from server.');
      }

      // Initialize payment sheet
      print('Initializing payment sheet...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'GTFinder',
          paymentIntentClientSecret: clientSecret, // Use the safe variable
          style: ThemeMode.dark,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              background: const Color(0xFF1A2468),    // Match the app's main background
              primary: const Color(0xFF1A2468),       // Your primary blue for buttons
              componentBackground: const Color(0xFF2C3E50), // Match the app's card color
              componentBorder: Colors.transparent, // No borders for a flatter look
              placeholderText: Colors.grey[400],
              primaryText: Colors.white,
              secondaryText: Colors.grey[300],
              componentText: Colors.white,
              icon: Colors.white,
            ),
            shapes: PaymentSheetShape(
              borderRadius: 12.0,
              borderWidth: 1.0,
              shadow: PaymentSheetShadowParams(color: Colors.black.withOpacity(0.2)),
            ),
            primaryButton: PaymentSheetPrimaryButtonAppearance(
              colors: PaymentSheetPrimaryButtonTheme(
                light: PaymentSheetPrimaryButtonThemeColors(
                  background: const Color(0xFF1A2468),
                  text: Colors.white,
                  border: Colors.transparent,
                ),
                dark: PaymentSheetPrimaryButtonThemeColors(
                  background: const Color(0xFF1A2468),
                  text: Colors.white,
                  border: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      );
      print('Payment sheet initialized');

      // Present the payment sheet
      print('Presenting payment sheet...');
      
      // Wrap the payment sheet presentation in a try-catch block
      bool paymentSuccess = false;
      try {
        // Add a timeout to prevent hanging
        await Future.any([
          Stripe.instance.presentPaymentSheet(),
          Future.delayed(const Duration(minutes: 2), () {
            throw TimeoutException('Payment timed out');
          }),
        ]);
        paymentSuccess = true;
        print('Payment sheet presented successfully');
      } on TimeoutException {
        print('Payment timed out');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment timed out. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } on PlatformException catch (e) {
        print('Platform error: ${e.message}');
        if (mounted) {
          String errorMessage = 'Payment failed. ';
          if (e.message?.contains('card_number') ?? false) {
            errorMessage += 'Invalid card number.';
          } else if (e.message?.contains('expiry') ?? false) {
            errorMessage += 'Invalid expiry date.';
          } else if (e.message?.contains('cvc') ?? false) {
            errorMessage += 'Invalid CVC.';
          } else {
            errorMessage += 'Please try again.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        print('Payment sheet error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment failed. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      // Only proceed if payment was successful
      if (paymentSuccess) {
        // If we get here, payment was successful
        print('Payment successful, updating Firestore...');
        // Update Firestore in the background
        await _updateFirestore(user.uid, userName, _paymentIntentId!);

        if (!mounted) return;

        // Show success message and navigate back to home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Booking confirmed.'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to landing page
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const UserLandingPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error in processPayment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _updateFirestore(String userId, String userName, String paymentIntentId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Create payment data with escrow status
      final paymentData = {
        'bookingId': widget.bookingId,
        'userId': userId,
        'userName': userName,
        'trainerId': widget.trainerId,
        'trainerName': widget.trainerName,
        'amount': widget.amount,
        'status': 'held', // Changed from 'completed' to 'held' for escrow
        'paymentIntentId': paymentIntentId,
        'timestamp': FieldValue.serverTimestamp(),
        'escrowStatus': 'pending', // New field for escrow tracking
        'sessionStatus': 'scheduled', // New field for session tracking
        'paymentType': 'escrow', // New field to identify escrow payments
      };

      // Add payment record to user's payments subcollection
      final userPaymentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('payments')
          .doc();

      batch.set(userPaymentRef, paymentData);

      // Add payment record to trainer's payments subcollection
      final trainerPaymentRef = FirebaseFirestore.instance
          .collection('trainer')
          .doc(widget.trainerId)
          .collection('payments')
          .doc(userPaymentRef.id);

      batch.set(trainerPaymentRef, paymentData);

      // Add payment record to admin's escrow payments collection
      final adminEscrowRef = FirebaseFirestore.instance
          .collection('admin_escrow_payments')
          .doc(userPaymentRef.id);

      batch.set(adminEscrowRef, {
        ...paymentData,
        'adminStatus': 'pending', // Changed from 'pending_release' to 'pending'
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update booking statuses
      final updates = {
        'status': 'confirmed',
        'paymentId': userPaymentRef.id,
        'paymentIntentId': paymentIntentId,
        'paymentStatus': 'paid_held', // Changed to indicate payment is held
        'paymentTimestamp': FieldValue.serverTimestamp(),
        'userName': userName,
        'escrowStatus': 'pending', // New field
        'sessionStatus': 'scheduled', // New field
      };

      batch.update(
        FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('bookings')
            .doc(widget.bookingId),
        updates,
      );

      batch.update(
        FirebaseFirestore.instance
            .collection('trainer')
            .doc(widget.trainerId)
            .collection('bookings')
            .doc(widget.bookingId),
        updates,
      );

      // Update root booking collection
      batch.update(
        FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId),
        updates,
      );

      await batch.commit();

      // Create notifications for both user and trainer
      final notificationService = NotificationService();
      
      // Notify user about booking confirmation
      await notificationService.createBookingConfirmedNotification(
        userId: userId,
        trainerName: widget.trainerName,
        bookingId: widget.bookingId,
      );

      // Notify trainer about payment held in escrow
      await notificationService.createPaymentHeldNotification(
        trainerId: widget.trainerId,
        userName: userName,
        amount: widget.amount,
        bookingId: widget.bookingId,
      );
    } catch (e) {
      print('Error updating Firestore: $e');
      // Don't throw the error as payment was successful
    }
  }

  Future<void> _fetchTrainerDetails() async {
    setState(() {
      _isTrainerDetailsLoading = true;
      _isProfileImageLoading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance.collection('trainer').doc(widget.trainerId).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _trainerProfileImageUrl = data?['profileImage'] as String?;
          _trainerName = data?['name'] as String?;
          _trainerSpecialization = data?['specialization'] as String?;
          _trainerExperience = (data?['experience'] as num?)?.toInt();
        });
      }
    } catch (e) {
      // ignore error, fallback to passed-in values
    } finally {
      if (mounted) setState(() {
        _isTrainerDetailsLoading = false;
        _isProfileImageLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation while processing payment
        if (_isProcessing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait for the payment to complete'),
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A2468),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Payment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _isProcessing ? null : () => Navigator.pop(context),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0xFF212E83), const Color(0xFF1A2468)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
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
                          children: [
                            _isProfileImageLoading
                              ? Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : (_trainerProfileImageUrl != null && _trainerProfileImageUrl!.isNotEmpty)
                                ? ProfileImageDisplay(
                                    imageUrl: _trainerProfileImageUrl,
                                    size: 48,
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _isTrainerDetailsLoading
                                ? const SizedBox(
                                    height: 24,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _trainerName ?? widget.trainerName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _trainerSpecialization ?? widget.specialization,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildInfoRow('Experience', '${_trainerExperience ?? widget.experience} years'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Schedule', widget.bookingDateTime),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
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
                        const Text(
                          'Payment Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Amount',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            Text(
                              '\$${widget.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
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
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child:
                          _isProcessing
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Pay Now',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
 