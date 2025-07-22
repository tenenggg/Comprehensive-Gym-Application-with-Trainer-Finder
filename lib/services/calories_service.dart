import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class CaloriesService {
  final String apiKey = '5af9e1f082msha4035be15f4871ep15950ajsn8620391a80dc';
  final String apiHost = 'calories-burned-by-api-ninjas.p.rapidapi.com';

  /// Fetches calories burned for a specific activity and duration
  /// 
  /// [activity] - The name of the activity/exercise
  /// [duration] - Duration in minutes
  /// Returns a list of calorie data including total calories burned
  Future<List<dynamic>> fetchCaloriesBurned(String activity, int duration) async {
    try {
      final url = Uri.parse(
        'https://calories-burned-by-api-ninjas.p.rapidapi.com/v1/caloriesburned?activity=$activity&duration=$duration',
      );

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
        throw Exception('Failed to load calorie data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching calorie data: $e');
    }
  }

  /// Maps exercise category to activity name for the calories API
  String mapExerciseToActivity(String exerciseName, String category) {
    // Convert exercise name to lowercase for better matching
    final name = exerciseName.toLowerCase();
    
    // Map common exercise names to activities
    if (name.contains('push-up') || name.contains('pushup')) {
      return 'push-ups';
    } else if (name.contains('sit-up') || name.contains('situp')) {
      return 'sit-ups';
    } else if (name.contains('pull-up') || name.contains('pullup')) {
      return 'pull-ups';
    } else if (name.contains('squat')) {
      return 'squats';
    } else if (name.contains('plank')) {
      return 'plank';
    } else if (name.contains('jump')) {
      return 'jumping jacks';
    } else if (name.contains('run') || name.contains('jog')) {
      return 'running';
    } else if (name.contains('walk')) {
      return 'walking';
    } else if (name.contains('swim')) {
      return 'swimming';
    } else if (name.contains('bike') || name.contains('cycling')) {
      return 'cycling';
    }
    
    // If no specific match, return a generic activity based on category
    switch (category.toLowerCase()) {
      case 'chest':
        return 'push-ups';
      case 'back':
        return 'pull-ups';
      case 'legs':
        return 'squats';
      case 'core':
        return 'sit-ups';
      case 'shoulder':
        return 'push-ups';
      case 'arms':
        return 'push-ups';
      default:
        return 'calisthenics';
    }
  }
} 