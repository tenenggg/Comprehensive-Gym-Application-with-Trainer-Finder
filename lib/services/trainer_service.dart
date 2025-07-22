import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trainer_model.dart';

class TrainerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get nearby trainers based on user's location
  static Future<List<TrainerModel>> getNearbyTrainers(
    Position userPosition, {
    double radius = 30000, // 30km default radius
    String? searchQuery,
    double? minFee,
    double? maxFee,
  }) async {
    try {
      // Get all trainers from Firestore
      final querySnapshot = await _firestore.collection('trainer').get();
      
      List<TrainerModel> trainers = [];
      
      for (final doc in querySnapshot.docs) {
        final trainerData = doc.data();
        
        // Create trainer model
        final trainer = TrainerModel.fromMap(trainerData, doc.id);
        
        // Apply text search filter
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          final name = trainer.name.toLowerCase();
          final specialization = trainer.specialization.toLowerCase();
          
          if (!name.contains(query) && !specialization.contains(query)) {
            continue;
          }
        }
        
        // Apply fee filter
        if (minFee != null && trainer.sessionFee < minFee) {
          continue;
        }
        if (maxFee != null && trainer.sessionFee > maxFee) {
          continue;
        }
        
        // Calculate distance if trainer has location
        if (trainer.hasLocation) {
          final distance = Geolocator.distanceBetween(
            userPosition.latitude,
            userPosition.longitude,
            trainer.latitude!,
            trainer.longitude!,
          );
          
          // Filter by radius
          if (distance <= radius) {
            trainers.add(trainer.copyWith(distance: distance));
          }
        } else {
          // Include trainers without location data (for backward compatibility)
          trainers.add(trainer);
        }
      }
      
      // Sort by distance (trainers with location first, then by distance)
      trainers.sort((a, b) {
        if (a.hasLocation && !b.hasLocation) return -1;
        if (!a.hasLocation && b.hasLocation) return 1;
        if (a.hasLocation && b.hasLocation) {
          return (a.distance ?? 0).compareTo(b.distance ?? 0);
        }
        return 0;
      });
      
      return trainers;
    } catch (e) {
      print('Error fetching nearby trainers: $e');
      return [];
    }
  }

  /// Get trainers with availability check for specific date and time
  static Future<List<TrainerModel>> getAvailableTrainers(
    Position userPosition, {
    required DateTime selectedDate,
    required String selectedTimeSlot,
    double radius = 30000,
    String? searchQuery,
    double? minFee,
    double? maxFee,
    String? userId, // To check user's existing bookings
  }) async {
    try {
      final allTrainers = await getNearbyTrainers(
        userPosition,
        radius: radius,
        searchQuery: searchQuery,
        minFee: minFee,
        maxFee: maxFee,
      );
      
      List<TrainerModel> availableTrainers = [];
      
      for (final trainer in allTrainers) {
        // Check if user already has a booking with this trainer at this time
        if (userId != null) {
          final userBookingSnapshot = await _firestore
              .collection('bookings')
              .where('userId', isEqualTo: userId)
              .where('trainerId', isEqualTo: trainer.id)
              .where('timeSlot', isEqualTo: selectedTimeSlot)
              .where('status', whereIn: ['pending', 'confirmed'])
              .get();
          
          final userHasBooking = userBookingSnapshot.docs.any((doc) {
            final bookingDate = (doc['bookingDate'] as Timestamp).toDate();
            return bookingDate.year == selectedDate.year &&
                   bookingDate.month == selectedDate.month &&
                   bookingDate.day == selectedDate.day;
          });
          
          if (userHasBooking) {
            continue;
          }
        }
        
        // Check trainer's availability for this time slot
        final trainerBookingsSnapshot = await _firestore
            .collection('trainer')
            .doc(trainer.id)
            .collection('bookings')
            .where('bookingDate', isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime(selectedDate.year, selectedDate.month, selectedDate.day).toUtc(),
            ))
            .where('bookingDate', isLessThan: Timestamp.fromDate(
              DateTime(selectedDate.year, selectedDate.month, selectedDate.day).toUtc().add(const Duration(days: 1)),
            ))
            .where('timeSlot', isEqualTo: selectedTimeSlot)
            .get();
        
        // If no bookings found for this time slot, trainer is available
        if (trainerBookingsSnapshot.docs.isEmpty) {
          availableTrainers.add(trainer);
        }
      }
      
      return availableTrainers;
    } catch (e) {
      print('Error fetching available trainers: $e');
      return [];
    }
  }

  /// Update trainer's location
  static Future<void> updateTrainerLocation(
    String trainerId, {
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      await _firestore.collection('trainer').doc(trainerId).update({
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating trainer location: $e');
      throw e;
    }
  }

  /// Get user's current location
  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Calculate distance between two points
  static double calculateDistance(
    double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Format distance for display
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
  }
} 