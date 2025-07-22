import 'package:cloud_firestore/cloud_firestore.dart';

class TrainerModel {
  final String id;
  final String name;
  final String email;
  final String username;
  final int age;
  final String gender;
  final String specialization;
  final int experience;
  final double sessionFee;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? profileImage;
  final double? distance; // Calculated distance from user

  TrainerModel({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.age,
    required this.gender,
    required this.specialization,
    required this.experience,
    required this.sessionFee,
    required this.createdAt,
    this.updatedAt,
    this.latitude,
    this.longitude,
    this.address,
    this.profileImage,
    this.distance,
  });

  factory TrainerModel.fromMap(Map<String, dynamic> map, String id) {
    return TrainerModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      age: map['age'] ?? 0,
      gender: map['gender'] ?? 'Not specified',
      specialization: map['specialization'] ?? '',
      experience: map['experience'] ?? 0,
      sessionFee: (map['sessionFee'] ?? 50.0).toDouble(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      address: map['address'],
      profileImage: map['profileImage'],
      distance: map['distance']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'username': username,
      'age': age,
      'gender': gender,
      'specialization': specialization,
      'experience': experience,
      'sessionFee': sessionFee,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'profileImage': profileImage,
    };
  }

  // Convert distance to kilometers
  double get distanceInKm => (distance ?? 0) / 1000;

  // Convert distance to miles
  double get distanceInMiles => (distance ?? 0) / 1609.34;

  // Check if trainer has location data
  bool get hasLocation => latitude != null && longitude != null;

  // Create a copy with updated distance
  TrainerModel copyWith({double? distance}) {
    return TrainerModel(
      id: id,
      name: name,
      email: email,
      username: username,
      age: age,
      gender: gender,
      specialization: specialization,
      experience: experience,
      sessionFee: sessionFee,
      createdAt: createdAt,
      updatedAt: updatedAt,
      latitude: latitude,
      longitude: longitude,
      address: address,
      profileImage: profileImage,
      distance: distance ?? this.distance,
    );
  }
} 