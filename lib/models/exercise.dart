import 'package:cloud_firestore/cloud_firestore.dart';

enum ExerciseCategory {
  triceps,
  biceps,
  legs,
  traps,
  chest,
  core,
  back,
  arms,
  shoulder;

  String get categoryName {
    switch (this) {
      case ExerciseCategory.triceps:
        return 'Triceps';
      case ExerciseCategory.biceps:
        return 'Biceps';
      case ExerciseCategory.legs:
        return 'Legs';
      case ExerciseCategory.traps:
        return 'Traps';
      case ExerciseCategory.chest:
        return 'Chest';
      case ExerciseCategory.core:
        return 'Core';
      case ExerciseCategory.back:
        return 'Back';
      case ExerciseCategory.arms:
        return 'Arms';
      case ExerciseCategory.shoulder:
        return 'Shoulder';
    }
  }
}

class Exercise {
  final String id;
  final String name;
  final String description;
  final ExerciseCategory category;
  final List<String> muscleGroups;
  final String difficulty;
  final String equipment;
  final List<String> steps;
  final String? imageUrl;
  final String createdBy;
  final DateTime createdAt;

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.muscleGroups,
    required this.difficulty,
    required this.equipment,
    required this.steps,
    this.imageUrl,
    required this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.toString().split('.').last,
      'muscleGroups': muscleGroups,
      'difficulty': difficulty,
      'equipment': equipment,
      'steps': steps,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: ExerciseCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => ExerciseCategory.arms,
      ),
      muscleGroups: List<String>.from(map['muscleGroups'] ?? []),
      difficulty: map['difficulty'] ?? '',
      equipment: map['equipment'] ?? '',
      steps: List<String>.from(map['steps'] ?? []),
      imageUrl: map['imageUrl'],
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  String get categoryName {
    switch (category) {
      case ExerciseCategory.triceps:
        return 'Triceps';
      case ExerciseCategory.biceps:
        return 'Biceps';
      case ExerciseCategory.legs:
        return 'Legs';
      case ExerciseCategory.traps:
        return 'Traps';
      case ExerciseCategory.chest:
        return 'Chest';
      case ExerciseCategory.core:
        return 'Core';
      case ExerciseCategory.back:
        return 'Back';
      case ExerciseCategory.arms:
        return 'Arms';
      case ExerciseCategory.shoulder:
        return 'Shoulder';
    }
  }
} 