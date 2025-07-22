import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final String? profileImage;
  final Map<String, dynamic>? metadata;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.isActive,
    this.isVerified = false,
    required this.createdAt,
    this.profileImage,
    this.metadata,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      isActive: map['isActive'] ?? true,
      isVerified: map['isVerified'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      profileImage: map['profileImage'],
      metadata: map['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'isActive': isActive,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'profileImage': profileImage,
      'metadata': metadata,
    };
  }
} 