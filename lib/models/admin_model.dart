import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModel {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;
  final List<String> permissions;
  final bool isActive;
  final String? profileImage;

  AdminModel({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    required this.permissions,
    required this.isActive,
    this.profileImage,
  });

  factory AdminModel.fromMap(Map<String, dynamic> map, String id) {
    return AdminModel(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      permissions: List<String>.from(map['permissions'] ?? []),
      isActive: map['isActive'] ?? false,
      profileImage: map['profileImage'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'permissions': permissions,
      'isActive': isActive,
      'profileImage': profileImage,
    };
  }

  AdminModel copyWith({
    String? id,
    String? email,
    String? name,
    DateTime? createdAt,
    List<String>? permissions,
    bool? isActive,
    String? profileImage,
  }) {
    return AdminModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }

  static List<String> availablePermissions = [
    'manage_users',
    'manage_trainers',
    'view_analytics',
    'manage_content',
    'manage_settings',
    'view_reports',
    'verify_trainers',
  ];
} 