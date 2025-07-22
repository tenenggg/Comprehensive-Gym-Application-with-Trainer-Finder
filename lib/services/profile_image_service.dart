import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileImageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Take a photo with camera
  static Future<File?> takePhotoWithCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      print('Error taking photo with camera: $e');
      return null;
    }
  }

  /// Upload profile image to Firebase Storage
  static Future<String?> uploadProfileImage(File imageFile, String userType) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Create a unique filename
      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child('profile_images/$userType/$fileName');

      // Upload the file
      final uploadTask = storageRef.putFile(imageFile);
      final snapshot = await uploadTask;
      
      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update the user's profile in Firestore
      await _updateProfileImageInFirestore(user.uid, userType, downloadUrl);
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  /// Update profile image URL in Firestore
  static Future<void> _updateProfileImageInFirestore(
    String userId, 
    String userType, 
    String imageUrl
  ) async {
    try {
      final collectionName = _getCollectionName(userType);
      await _firestore
          .collection(collectionName)
          .doc(userId)
          .update({
        'profileImage': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating profile image in Firestore: $e');
      throw e;
    }
  }

  /// Get collection name based on user type
  static String _getCollectionName(String userType) {
    switch (userType.toLowerCase()) {
      case 'trainer':
        return 'trainer';
      case 'admin':
        return 'admins';
      case 'user':
      default:
        return 'users';
    }
  }

  /// Delete profile image from Firebase Storage
  static Future<bool> deleteProfileImage(String userType) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Get current profile image URL
      final collectionName = _getCollectionName(userType);
      final userDoc = await _firestore
          .collection(collectionName)
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final currentImageUrl = userDoc.data()?['profileImage'] as String?;
        
        if (currentImageUrl != null && currentImageUrl.isNotEmpty) {
          // Delete from Firebase Storage
          try {
            final storageRef = _storage.refFromURL(currentImageUrl);
            await storageRef.delete();
          } catch (e) {
            print('Error deleting from storage (image might not exist): $e');
          }
        }

        // Remove from Firestore
        await _firestore
            .collection(collectionName)
            .doc(user.uid)
            .update({
          'profileImage': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting profile image: $e');
      return false;
    }
  }

  /// Get profile image URL from Firestore
  static Future<String?> getProfileImageUrl(String userType) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final collectionName = _getCollectionName(userType);
      final userDoc = await _firestore
          .collection(collectionName)
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        return userDoc.data()?['profileImage'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting profile image URL: $e');
      return null;
    }
  }

  /// Show image picker dialog
  static Future<File?> showImagePickerDialog(BuildContext context) async {
    return showDialog<File?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2468),
          title: const Text(
            'Select Profile Picture',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.of(context).pop(await pickImageFromGallery());
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.of(context).pop(await takePhotoWithCamera());
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Compress image before upload
  static Future<File?> compressImage(File imageFile) async {
    try {
      // For now, we'll use the original file
      // In a production app, you might want to add image compression here
      return imageFile;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }
} 