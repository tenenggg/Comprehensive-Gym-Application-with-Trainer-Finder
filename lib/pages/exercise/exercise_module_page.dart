import 'package:flutter/material.dart';
import '../../models/exercise.dart';
import '../../services/exercise_service.dart';
import '../../services/calories_service.dart';
import '../trainer/trainer_landing_page.dart';
import '../user/user_landing_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:numberpicker/numberpicker.dart';

class ExerciseModulePage extends StatelessWidget {
  final ExerciseService _exerciseService = ExerciseService();
  final bool isTrainer;

  ExerciseModulePage({
    super.key,
    required this.isTrainer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2468),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Exercise Categories',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF212E83),
              const Color(0xFF1A2468),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.fitness_center,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Choose Category',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.1,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: ExerciseCategory.values.length,
                            itemBuilder: (context, index) {
                              final category = ExerciseCategory.values[index];
                              return _buildCategoryCard(context, category);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, ExerciseCategory category) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExerciseCategoryPage(
              category: category,
              isTrainer: isTrainer,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(category),
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.categoryName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(ExerciseCategory category) {
    switch (category) {
      case ExerciseCategory.triceps:
        return Icons.fitness_center;
      case ExerciseCategory.biceps:
        return Icons.fitness_center;
      case ExerciseCategory.legs:
        return Icons.directions_run;
      case ExerciseCategory.traps:
        return Icons.fitness_center;
      case ExerciseCategory.chest:
        return Icons.fitness_center;
      case ExerciseCategory.core:
        return Icons.fitness_center;
      case ExerciseCategory.back:
        return Icons.fitness_center;
      case ExerciseCategory.arms:
        return Icons.fitness_center;
      case ExerciseCategory.shoulder:
        return Icons.fitness_center;
    }
  }
}

class ExerciseCategoryPage extends StatefulWidget {
  final ExerciseCategory category;
  final ExerciseService _exerciseService = ExerciseService();
  final CaloriesService _caloriesService = CaloriesService();
  final bool isTrainer;

  ExerciseCategoryPage({
    super.key, 
    required this.category,
    required this.isTrainer,
  });

  @override
  State<ExerciseCategoryPage> createState() => _ExerciseCategoryPageState();
}

class _ExerciseCategoryPageState extends State<ExerciseCategoryPage> {
  final ExerciseService _exerciseService = ExerciseService();
  final CaloriesService _caloriesService = CaloriesService();
  String _selectedIntensity = 'Low';
  double _duration = 30;
  final bool _showExercises = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isTimerRunning = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  int _selectedMinutes = 30;
  final List<int> _presetDurations = [5, 10, 15, 20, 30, 45, 60];
  String? _selectedExercise;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _selectedMinutes * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _showMinutesInputDialog() async {
    if (_isTimerRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please stop the timer before changing the duration'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final TextEditingController controller = TextEditingController(
      text: _selectedMinutes.toString(),
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2468),
        title: const Text(
          'Set Exercise Duration',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quick Select',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetDurations.map((minutes) {
                  final isSelected = minutes == _selectedMinutes;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMinutes = minutes;
                        _remainingSeconds = minutes * 60;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.white24,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$minutes min',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Custom Duration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              NumberPicker(
                value: _selectedMinutes,
                minValue: 1,
                maxValue: 120,
                itemHeight: 40,
                itemWidth: 60,
                axis: Axis.horizontal,
                textStyle: const TextStyle(color: Colors.white54, fontSize: 20),
                selectedTextStyle: const TextStyle(color: Colors.blue, fontSize: 28, fontWeight: FontWeight.bold),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.blue.withOpacity(0.4)),
                    bottom: BorderSide(color: Colors.blue.withOpacity(0.4)),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedMinutes = value;
                    _remainingSeconds = value * 60;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Minutes',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixText: 'min',
                        suffixStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      ),
                      autofocus: true,
                      onSubmitted: (value) {
                        final minutes = int.tryParse(value);
                        if (minutes != null && minutes > 0) {
                          setState(() {
                            _selectedMinutes = minutes;
                            _remainingSeconds = minutes * 60;
                          });
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid number of minutes'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      final minutes = int.tryParse(controller.text);
                      if (minutes != null && minutes > 0) {
                        setState(() {
                          _selectedMinutes = minutes;
                          _remainingSeconds = minutes * 60;
                        });
                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid number of minutes'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.blue, size: 32),
                    tooltip: 'Set Duration',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can scroll, type, or tap a preset to set your workout duration (e.g. 12 for 12 minutes).',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    if (_remainingSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a valid duration first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isTimerRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
          _isTimerRunning = false;
          _showTimerCompleteDialog();
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _remainingSeconds = _selectedMinutes * 60;
    });
  }

  void _showTimerCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2468),
        title: const Text(
          'Exercise Complete!',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Great job! You\'ve completed your exercise session.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleContinue();
            },
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildTimer() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Exercise Timer',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: _showMinutesInputDialog,
                icon: const Icon(Icons.timer, color: Colors.white),
                tooltip: 'Set Duration',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: _isTimerRunning ? _remainingSeconds / (_selectedMinutes * 60) : 1.0,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isTimerRunning ? Colors.blue : Colors.white.withOpacity(0.3),
                  ),
                  strokeWidth: 8,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(_remainingSeconds),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${_selectedMinutes} min',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isTimerRunning ? _stopTimer : _startTimer,
                icon: Icon(_isTimerRunning ? Icons.stop : Icons.play_arrow),
                label: Text(_isTimerRunning ? 'Stop' : 'Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTimerRunning ? Colors.red : Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _resetTimer,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveExerciseData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No user logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get user data to check user type
      final userRef = widget.isTrainer 
          ? _firestore.collection('trainer').doc(user.uid)
          : _firestore.collection('users').doc(user.uid);
      
      final userData = await userRef.get();

      if (!userData.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User profile not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastWorkout = userData.data()?['lastWorkout'] as Timestamp?;
      int currentStreak = userData.data()?['workoutStreak'] ?? 0;

      // Calculate calories burned using the Calories API
      int estimatedCalories = 0;
      if (_selectedExercise != null) {
        try {
          final activity = _caloriesService.mapExerciseToActivity(
            _selectedExercise!,
            widget.category.toString().split('.').last,
          );
          final caloriesData = await _caloriesService.fetchCaloriesBurned(
            activity,
            _duration.round(),
          );
          if (caloriesData.isNotEmpty) {
            // Apply intensity multiplier
            double intensityMultiplier = 1.0;
            switch (_selectedIntensity.toLowerCase()) {
              case 'low':
                intensityMultiplier = 0.8;
                break;
              case 'medium':
                intensityMultiplier = 1.0;
                break;
              case 'high':
                intensityMultiplier = 1.3;
                break;
            }
            estimatedCalories = (caloriesData[0]['total_calories'] * intensityMultiplier).round();
          }
        } catch (e) {
          print('Error calculating calories: $e');
          // Fallback to basic calculation if API fails
          estimatedCalories = _calculateCaloriesBurned(_duration.round(), _selectedIntensity);
        }
      } else {
        // Fallback to basic calculation if no exercise selected
        estimatedCalories = _calculateCaloriesBurned(_duration.round(), _selectedIntensity);
      }

      // Update streak based on last workout
      if (lastWorkout != null) {
        final lastWorkoutDate = lastWorkout.toDate();
        final difference = now.difference(lastWorkoutDate);

        if (difference.inDays == 0) {
          // Already worked out today, keep streak
        } else if (difference.inDays == 1) {
          // Consecutive day, increase streak
          currentStreak++;
        } else {
          // Streak broken, reset to 1
          currentStreak = 1;
        }
      } else {
        // First workout ever
        currentStreak = 1;
      }

      // Get today's calories
      final dailyCaloriesRef = userRef.collection('daily_calories').doc(today.toIso8601String());
      final dailyCaloriesDoc = await dailyCaloriesRef.get();
      int todayCalories = 0;
      
      if (dailyCaloriesDoc.exists) {
        final data = dailyCaloriesDoc.data();
        if (data != null && data.containsKey('calories')) {
          todayCalories = (data['calories'] as num).toInt();
        }
      }

      // Update today's calories
      await dailyCaloriesRef.set({
        'date': today,
        'calories': todayCalories + estimatedCalories,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add to calories history
      await userRef.collection('calories_history').add({
        'date': today,
        'calories': estimatedCalories,
        'exercise': _selectedExercise ?? 'General Exercise',
        'category': widget.category.toString().split('.').last,
        'intensity': _selectedIntensity,
        'duration': _duration.round(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      final exerciseData = {
        'userId': user.uid,
        'userName': userData.data()?['name'] ?? 'Unknown',
        'category': widget.category.toString().split('.').last,
        'exercise': _selectedExercise ?? 'General Exercise',
        'intensity': _selectedIntensity,
        'duration': _duration.round(),
        'timestamp': FieldValue.serverTimestamp(),
        'caloriesBurned': estimatedCalories,
      };

      // Update user document with new workout data
      await userRef.update({
        'lastWorkout': FieldValue.serverTimestamp(),
        'workoutStreak': currentStreak,
        'totalCaloriesBurned': FieldValue.increment(estimatedCalories),
      });

      // Store workout in user's workouts collection
      await userRef.collection('workouts').add(exerciseData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exercise completed! Calories burned: $estimatedCalories'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving exercise data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving exercise data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _calculateCaloriesBurned(int duration, String intensity) {
    // Base calories burned per minute for moderate exercise
    const baseCaloriesPerMinute = 5;
    
    // Multiplier based on intensity
    double intensityMultiplier;
    switch (intensity.toLowerCase()) {
      case 'low':
        intensityMultiplier = 0.8;
        break;
      case 'medium':
        intensityMultiplier = 1.0;
        break;
      case 'high':
        intensityMultiplier = 1.3;
        break;
      default:
        intensityMultiplier = 1.0;
    }

    // Calculate total calories burned
    return (baseCaloriesPerMinute * duration * intensityMultiplier).round();
  }

  void _handleContinue() async {
    // First save the exercise data
    await _saveExerciseData();

    // Then navigate to the appropriate landing page
    if (widget.isTrainer) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => TrainerLandingPage(),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => UserLandingPage(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A2468),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.category.categoryName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF212E83),
              const Color(0xFF1A2468),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_showExercises) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Intensity',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildIntensityOption(
                          'Low',
                          '1-5 reps',
                          Icons.trending_down,
                        ),
                        const SizedBox(height: 16),
                        _buildIntensityOption(
                          'Medium',
                          '5-10 reps',
                          Icons.trending_flat,
                        ),
                        const SizedBox(height: 16),
                        _buildIntensityOption(
                          'High',
                          '10+ reps',
                          Icons.trending_up,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Select Duration',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${_duration.round()} min',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Slider(
                          value: _duration,
                          min: 1,
                          max: 120,
                          divisions: 119,
                          activeColor: Colors.blue,
                          inactiveColor: Colors.white.withOpacity(0.3),
                          onChanged: (value) {
                            setState(() {
                              _duration = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTimer(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else
                  _buildExerciseList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntensityOption(String title, String subtitle, IconData icon) {
    final isSelected = _selectedIntensity == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIntensity = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseList() {
    return FutureBuilder<List<dynamic>>(
      future: widget._exerciseService.fetchExercisesByCategory(widget.category),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final exercises = snapshot.data ?? [];

        if (exercises.isEmpty) {
          return const Center(
            child: Text(
              'No exercises found in this category',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final exercise = exercises[index];
            final isSelected = _selectedExercise == exercise['name'];
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  unselectedWidgetColor: Colors.white70,
                  colorScheme: ColorScheme.dark(
                    primary: Colors.blue.shade100,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedExercise = exercise['name'];
                    });
                  },
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise['name'] ?? 'Unknown Exercise',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                    subtitle: Text(
                      exercise['instructions'] ?? 'No instructions available',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Equipment', exercise['equipment'] ?? 'Unknown'),
                            const SizedBox(height: 12),
                            _buildInfoRow('Target Muscle', exercise['target'] ?? 'Unknown'),
                            const SizedBox(height: 12),
                            _buildInfoRow('Intensity', _selectedIntensity),
                            const SizedBox(height: 12),
                            _buildInfoRow('Duration', '${_duration.round()} minutes'),
                            const SizedBox(height: 16),
                            const Text(
                              'Instructions:',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              exercise['instructions'] ?? 'No instructions available',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            if (exercise['gifUrl'] != null) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Exercise Demo:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Image.network(
                                exercise['gifUrl'],
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedExercise = exercise['name'];
                                  });
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Select This Exercise',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
} 