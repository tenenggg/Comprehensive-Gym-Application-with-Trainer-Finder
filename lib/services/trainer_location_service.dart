import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trainer_service.dart';

class TrainerLocationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static StreamSubscription<Position>? _locationSubscription;
  static Timer? _locationUpdateTimer;
  static bool _isLocationTrackingActive = false;
  static Position? _lastKnownPosition;
  
  // Minimum distance (in meters) that the trainer must move to trigger a location update
  static const int _minimumDistanceForUpdate = 100; // 100 meters
  static const Duration _locationUpdateInterval = Duration(minutes: 5); // Update every 5 minutes
  
  /// Start automatic location tracking for the current trainer
  static Future<void> startLocationTracking() async {
    if (_isLocationTrackingActive) {
      print('[TrainerLocationService] Location tracking already active');
      return;
    }
    
    try {
      // Check if user is logged in and is a trainer
      final user = _auth.currentUser;
      if (user == null) {
        print('[TrainerLocationService] No user logged in');
        return;
      }
      
      // Check if user is a trainer
      final trainerDoc = await _firestore.collection('trainer').doc(user.uid).get();
      if (!trainerDoc.exists) {
        print('[TrainerLocationService] User is not a trainer');
        return;
      }
      
      print('[TrainerLocationService] Starting location tracking for trainer: ${user.uid}');
      
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[TrainerLocationService] Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('[TrainerLocationService] Requesting location permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[TrainerLocationService] Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[TrainerLocationService] Location permissions are permanently denied');
        return;
      }

      // Get initial location
      print('[TrainerLocationService] Getting initial location...');
      await _updateTrainerLocation();
      
      // Start periodic location updates
      _locationUpdateTimer = Timer.periodic(_locationUpdateInterval, (timer) {
        print('[TrainerLocationService] Periodic location update triggered');
        _updateTrainerLocation();
      });
      
      // Start location stream for significant movement
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _minimumDistanceForUpdate,
        ),
      ).listen(
        (Position position) {
          print('[TrainerLocationService] Significant movement detected, updating location');
          _updateTrainerLocationWithPosition(position);
        },
        onError: (error) {
          print('[TrainerLocationService] Error in location stream: $error');
        },
      );
      
      _isLocationTrackingActive = true;
      print('[TrainerLocationService] Location tracking started successfully');
      
    } catch (e) {
      print('[TrainerLocationService] Error starting location tracking: $e');
    }
  }
  
  /// Stop automatic location tracking
  static void stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _isLocationTrackingActive = false;
    _lastKnownPosition = null;
    print('[TrainerLocationService] Location tracking stopped');
  }
  
  /// Update trainer location with current position
  static Future<void> _updateTrainerLocation() async {
    try {
      final position = await TrainerService.getCurrentLocation();
      if (position != null) {
        await _updateTrainerLocationWithPosition(position);
      } else {
        print('[TrainerLocationService] Could not get current location');
      }
    } catch (e) {
      print('[TrainerLocationService] Error updating trainer location: $e');
    }
  }
  
  /// Update trainer location with provided position
  static Future<void> _updateTrainerLocationWithPosition(Position position) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      // Check if position has changed significantly
      if (_lastKnownPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastKnownPosition!.latitude,
          _lastKnownPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        
        // Only update if moved more than 50 meters or if this is the first update
        if (distance < 50 && _lastKnownPosition != null) {
          print('[TrainerLocationService] Position change too small (${distance.toStringAsFixed(1)}m), skipping update');
          return;
        }
      }
      
      // Get address from coordinates
      String? address;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          address = '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}';
        }
      } catch (e) {
        print('[TrainerLocationService] Error getting address: $e');
      }
      
      // Update trainer location in Firestore
      await TrainerService.updateTrainerLocation(
        user.uid,
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );
      
      _lastKnownPosition = position;
      print('[TrainerLocationService] Trainer location updated: ${position.latitude}, ${position.longitude}');
      
    } catch (e) {
      print('[TrainerLocationService] Error updating trainer location with position: $e');
    }
  }
  
  /// Check if location tracking is active
  static bool get isLocationTrackingActive => _isLocationTrackingActive;
  
  /// Get current location tracking status
  static Future<Map<String, dynamic>> getLocationTrackingStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'isLoggedIn': false,
        'isTrainer': false,
        'locationServicesEnabled': false,
        'locationPermissionGranted': false,
        'isTrackingActive': false,
      };
    }
    
    // Check if user is a trainer
    final trainerDoc = await _firestore.collection('trainer').doc(user.uid).get();
    final isTrainer = trainerDoc.exists;
    
    // Check location services
    final locationServicesEnabled = await Geolocator.isLocationServiceEnabled();
    
    // Check location permissions
    final permission = await Geolocator.checkPermission();
    final locationPermissionGranted = permission == LocationPermission.whileInUse || 
                                     permission == LocationPermission.always;
    
    return {
      'isLoggedIn': true,
      'isTrainer': isTrainer,
      'locationServicesEnabled': locationServicesEnabled,
      'locationPermissionGranted': locationPermissionGranted,
      'isTrackingActive': _isLocationTrackingActive,
      'lastKnownPosition': _lastKnownPosition != null ? {
        'latitude': _lastKnownPosition!.latitude,
        'longitude': _lastKnownPosition!.longitude,
      } : null,
    };
  }
  
  /// Request location permissions and start tracking if granted
  static Future<bool> requestLocationPermissionAndStartTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('[TrainerLocationService] Location services are disabled');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('[TrainerLocationService] Requesting location permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('[TrainerLocationService] Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('[TrainerLocationService] Location permission permanently denied');
        return false;
      }

      // Start tracking if permissions are granted
      await startLocationTracking();
      return _isLocationTrackingActive;
      
    } catch (e) {
      print('[TrainerLocationService] Error requesting location permission: $e');
      return false;
    }
  }
  
  /// Force update location (for manual refresh)
  static Future<bool> forceUpdateLocation() async {
    try {
      await _updateTrainerLocation();
      return true;
    } catch (e) {
      print('[TrainerLocationService] Error forcing location update: $e');
      return false;
    }
  }
} 