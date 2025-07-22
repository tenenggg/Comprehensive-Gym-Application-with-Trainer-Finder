class GymLocation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  double distance; // Changed from final to mutable
  final double rating;
  final bool isOpen;
  final String phoneNumber;
  final String website;
  final List<String> photos;
  final List<String> amenities;

  GymLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.rating,
    required this.isOpen,
    required this.phoneNumber,
    required this.website,
    required this.photos,
    required this.amenities,
  });

  // Convert distance to kilometers
  double get distanceInKm => distance / 1000;

  // Convert distance to miles
  double get distanceInMiles => distance / 1609.34;

  factory GymLocation.fromJson(Map<String, dynamic> json) {
    return GymLocation(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      distance: json['distance'] as double,
      rating: json['rating'] as double,
      isOpen: json['isOpen'] as bool,
      phoneNumber: json['phoneNumber'] as String,
      website: json['website'] as String,
      photos: json['photos'] != null
          ? List<String>.from(json['photos'] as List)
          : const [],
      amenities: json['amenities'] != null
          ? List<String>.from(json['amenities'] as List)
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
      'rating': rating,
      'isOpen': isOpen,
      'phoneNumber': phoneNumber,
      'website': website,
      'photos': photos,
      'amenities': amenities,
    };
  }
} 