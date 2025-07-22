import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/gym_location.dart';
import '../config/google_config.dart';

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  
  static Future<List<GymLocation>> searchGyms(double lat, double lng, {double radius = 50000}) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/nearbysearch/json'
        '?location=$lat,$lng'
        '&radius=$radius'
        '&type=gym'
        '&key=${GoogleConfig.apiKey}'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        
        return Future.wait(results.map((place) async {
          final location = place['geometry']['location'];
          final lat = location['lat'] as double;
          final lng = location['lng'] as double;
          
          // Convert photo references to URLs
          List<String> photoUrls = [];
          if (place['photos'] != null) {
            for (var photo in place['photos']) {
              final photoRef = photo['photo_reference'] as String;
              final photoUrl = await getPhotoUrl(photoRef);
              photoUrls.add(photoUrl);
            }
          }
          
          return GymLocation(
            id: place['place_id'],
            name: place['name'],
            address: place['vicinity'] ?? 'No address available',
            latitude: lat,
            longitude: lng,
            distance: 0, // Will be calculated later
            rating: (place['rating'] as num?)?.toDouble() ?? 0.0,
            isOpen: place['opening_hours']?['open_now'] ?? false,
            phoneNumber: '',
            website: '',
            photos: photoUrls,
            amenities: [],
          );
        })).then((gyms) => gyms.toList());
      }
      return [];
    } catch (e) {
      print('Error searching gyms with Places API: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/details/json'
        '?place_id=$placeId'
        '&fields=name,formatted_address,formatted_phone_number,website,opening_hours,rating,photos'
        '&key=${GoogleConfig.apiKey}'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'] as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print('Error getting place details: $e');
      return {};
    }
  }

  static Future<String> getPhotoUrl(String photoReference) async {
    return '$_baseUrl/photo'
        '?maxwidth=400'
        '&photo_reference=$photoReference'
        '&key=${GoogleConfig.apiKey}';
  }
} 