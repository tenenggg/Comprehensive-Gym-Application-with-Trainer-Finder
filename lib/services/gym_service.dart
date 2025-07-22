import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/gym_location.dart';
import '../config/mapbox_config.dart';
import '../config/foursquare_config.dart';
import '../config/google_config.dart';
import 'package:dio/dio.dart';
import 'places_service.dart';

class GymService {
  static const String _baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';
  static final Dio _dio = Dio();
  
  static Future<List<GymLocation>> getNearbyGyms(Position position) async {
    try {
      // Get gyms from multiple sources
      final mapboxGyms = await _getMapboxGyms(position);
      final placesGyms = await PlacesService.searchGyms(
        position.latitude,
        position.longitude,
        radius: 35000, // 35km radius
      );
      
      // Combine and deduplicate gyms
      final allGyms = [...mapboxGyms];
      
      for (final placesGym in placesGyms) {
        // Check if this gym is already in the list (within 100 meters)
        bool isDuplicate = false;
        for (final existingGym in allGyms) {
          final distance = Geolocator.distanceBetween(
            existingGym.latitude,
            existingGym.longitude,
            placesGym.latitude,
            placesGym.longitude,
          );
          if (distance < 100) {
            isDuplicate = true;
            break;
          }
        }
        
        if (!isDuplicate) {
          allGyms.add(placesGym);
        }
      }
      
      // Calculate distances and filter gyms within 35km
      final gymsWithDistance = allGyms.map((gym) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          gym.latitude,
          gym.longitude,
        );
        return GymLocation(
          id: gym.id,
          name: gym.name,
          address: gym.address,
          latitude: gym.latitude,
          longitude: gym.longitude,
          distance: distance,
          rating: gym.rating,
          isOpen: gym.isOpen,
          phoneNumber: gym.phoneNumber,
          website: gym.website,
          photos: gym.photos,
          amenities: gym.amenities,
        );
      }).where((gym) => gym.distance <= 35000).toList(); // Filter gyms within 35km
      
      gymsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));
      return gymsWithDistance;
    } catch (e) {
      print('Error fetching nearby gyms: $e');
      return [];
    }
  }

  static Future<List<GymLocation>> _getMapboxGyms(Position position) async {
    try {
      final response = await _dio.get(
        'https://api.mapbox.com/search/searchbox/v1/category',
        queryParameters: {
          'access_token': MapboxConfig.accessToken,
          'category': 'gym',
          'proximity': '${position.longitude},${position.latitude}',
          'radius': 35000, // 35km radius
          'country': 'MY',
          'limit': 50,
        },
      );

      if (response.statusCode == 200) {
        final features = response.data['features'] as List;
        return features.map((feature) {
          final properties = feature['properties'];
          final coordinates = feature['geometry']['coordinates'];
          
          return GymLocation(
            id: feature['id'],
            name: properties['name'] ?? 'Unknown Gym',
            address: properties['address'] ?? 'No address available',
            latitude: coordinates[1],
            longitude: coordinates[0],
            distance: 0,
            rating: properties['rating']?.toDouble() ?? 0.0,
            isOpen: properties['is_open'] ?? false,
            phoneNumber: properties['phone'] ?? '',
            website: properties['website'] ?? '',
            photos: properties['photos'] != null ? List<String>.from(properties['photos']) : [],
            amenities: properties['amenities'] != null ? List<String>.from(properties['amenities']) : [],
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching gyms from Mapbox: $e');
      return [];
    }
  }

  static Future<List<GymLocation>> searchGyms(String query, Position position) async {
    try {
      // Get gyms from Google Places API
      final placesGyms = await PlacesService.searchGyms(
        position.latitude,
        position.longitude,
        radius: 50000,
      );
      
      // Filter gyms by name and calculate distances
      final filteredGyms = placesGyms.where((gym) =>
        gym.name.toLowerCase().contains(query.toLowerCase())
      ).map((gym) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          gym.latitude,
          gym.longitude,
        );
        return GymLocation(
          id: gym.id,
          name: gym.name,
          address: gym.address,
          latitude: gym.latitude,
          longitude: gym.longitude,
          distance: distance,
          rating: gym.rating,
          isOpen: gym.isOpen,
          phoneNumber: gym.phoneNumber,
          website: gym.website,
          photos: gym.photos,
          amenities: gym.amenities,
        );
      }).toList();
      
      filteredGyms.sort((a, b) => a.distance.compareTo(b.distance));
      return filteredGyms;
    } catch (e) {
      print('Error searching gyms: $e');
      return [];
    }
  }

  static Future<List<dynamic>> fetchFoursquarePlaces(double lat, double lng) async {
    final url = Uri.parse(
      '${FoursquareConfig.baseUrl}/places/search?ll=$lat,$lng&query=gym&radius=50000&country=MY',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': FoursquareConfig.apiKey,
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'];
    } else {
      throw Exception('Failed to load places');
    }
  }

  static Future<List<GymLocation>> getNearbyGymsFromFoursquare(Position userPosition) async {
    try {
      final results = await fetchFoursquarePlaces(userPosition.latitude, userPosition.longitude);
      
      final gyms = <GymLocation>[];
      for (final place in results) {
        final location = place['location'] as Map<String, dynamic>;
        final distanceInMeters = Geolocator.distanceBetween(
          userPosition.latitude,
          userPosition.longitude,
          location['lat'] as double,
          location['lng'] as double,
        );

        // Fetch photo for this gym
        final photoUrl = await _getFoursquarePhotoUrl(place['fsq_id'] as String);
        
        gyms.add(GymLocation(
          id: place['fsq_id'] as String,
          name: place['name'] as String,
          address: place['location']['formatted_address'] as String? ?? '',
          latitude: location['lat'] as double,
          longitude: location['lng'] as double,
          distance: distanceInMeters,
          rating: (place['rating'] as num?)?.toDouble() ?? 0.0,
          isOpen: place['hours']?['is_open'] as bool? ?? false,
          phoneNumber: place['tel'] as String? ?? '',
          website: place['website'] as String? ?? '',
          photos: photoUrl != null ? [photoUrl] : [], // Add the fetched photo URL
          amenities: [],
        ));
      }

      gyms.sort((a, b) => a.distance.compareTo(b.distance));
      return gyms;
    } catch (e) {
      print('Error fetching nearby gyms from Foursquare: $e');
      return [];
    }
  }

  static Future<String?> _getFoursquarePhotoUrl(String fsqId) async {
    try {
      final url = Uri.parse('${FoursquareConfig.baseUrl}/places/$fsqId/photos?limit=1');
      final response = await http.get(
        url,
        headers: {
          'Authorization': FoursquareConfig.apiKey,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final photo = data.first;
          return '${photo['prefix']}original${photo['suffix']}';
        }
      }
      return null;
    } catch (e) {
      print('Error fetching photo for Foursquare place $fsqId: $e');
      return null;
    }
  }
} 