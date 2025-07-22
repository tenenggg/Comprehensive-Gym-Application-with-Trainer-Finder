import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service class for handling exercise-related API calls to the ExerciseDB API
class ExerciseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Your RapidAPI key for ExerciseDB
  final String apiKey = '5af9e1f082msha4035be15f4871ep15950ajsn8620391a80dc';
  
  /// The RapidAPI host for ExerciseDB
  final String apiHost = 'exercisedb.p.rapidapi.com';

  /// Maps our exercise categories to ExerciseDB body parts
  String _mapCategoryToBodyPart(ExerciseCategory category) {
    switch (category) {
      case ExerciseCategory.triceps:
        return 'upper arms';
      case ExerciseCategory.biceps:
        return 'upper arms';
      case ExerciseCategory.legs:
        return 'upper legs';
      case ExerciseCategory.traps:
        return 'back';
      case ExerciseCategory.chest:
        return 'chest';
      case ExerciseCategory.core:
        return 'waist';
      case ExerciseCategory.back:
        return 'back';
      case ExerciseCategory.arms:
        return 'upper arms';
      case ExerciseCategory.shoulder:
        return 'shoulders';
    }
  }

  /// Fetches exercises for a specific category from the ExerciseDB API
  Future<List<dynamic>> fetchExercisesByCategory(ExerciseCategory category) async {
    final bodyPart = _mapCategoryToBodyPart(category);
    return fetchExercisesByBodyPart(bodyPart);
  }

  /// Fetches exercises for a specific body part from the ExerciseDB API
  /// 
  /// [bodyPart] - The body part to fetch exercises for (e.g., 'chest', 'back', 'legs')
  /// Returns a list of exercises for the specified body part
  /// Throws an exception if the API call fails
  Future<List<dynamic>> fetchExercisesByBodyPart(String bodyPart) async {
    try {
      final url = Uri.parse('https://exercisedb.p.rapidapi.com/exercises/bodyPart/$bodyPart');

      final response = await http.get(
        url,
        headers: {
          'X-RapidAPI-Key': apiKey,
          'X-RapidAPI-Host': apiHost,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load exercises: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching exercises: $e');
    }
  }

  // Get all exercises
  Stream<List<Exercise>> getAllExercises() {
    return _firestore
        .collection('exercises')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Exercise.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  // Get exercises by category
  Stream<List<Exercise>> getExercisesByCategory(ExerciseCategory category) {
    return _firestore
        .collection('exercises')
        .where('category', isEqualTo: category.toString().split('.').last)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Exercise.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  // Add new exercise
  Future<void> addExercise(Exercise exercise) async {
    await _firestore.collection('exercises').add(exercise.toMap());
  }

  // Update exercise
  Future<void> updateExercise(Exercise exercise) async {
    await _firestore
        .collection('exercises')
        .doc(exercise.id)
        .update(exercise.toMap());
  }

  // Delete exercise
  Future<void> deleteExercise(String exerciseId) async {
    await _firestore.collection('exercises').doc(exerciseId).delete();
  }

  // Get exercises created by a specific trainer
  Stream<List<Exercise>> getExercisesByTrainer(String trainerId) {
    return _firestore
        .collection('exercises')
        .where('createdBy', isEqualTo: trainerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Exercise.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }
} 