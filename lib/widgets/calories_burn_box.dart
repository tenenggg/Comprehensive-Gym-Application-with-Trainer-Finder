import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/calories_history_page.dart';

class CaloriesBurnBox extends StatelessWidget {
  final bool isTrainer;
  static const int dailyGoal = 500; // Default daily goal in calories

  const CaloriesBurnBox({
    super.key,
    this.isTrainer = false,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(isTrainer ? 'trainer' : 'users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorBox('Error loading data');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingBox();
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final totalCaloriesBurned = userData['totalCaloriesBurned'] ?? 0;
        final lastWorkout = userData['lastWorkout'] as Timestamp?;
        final workoutStreak = userData['workoutStreak'] ?? 0;
        // Personalized goal calculation
        double? personalizedGoal;
        String? personalizedGoalMsg;
        if (userData['weight'] != null && userData['height'] != null && userData['age'] != null && userData['gender'] != null && userData['activityLevel'] != null && userData['goal'] != null) {
          final weight = (userData['weight'] as num).toDouble();
          final height = (userData['height'] as num).toDouble();
          final age = (userData['age'] as num).toInt();
          final gender = userData['gender'] as String;
          final activityLevel = userData['activityLevel'] as String;
          final goal = userData['goal'] as String;
          final bmr = _calculateBMR(weight: weight, height: height, age: age, gender: gender);
          final tdee = _calculateTDEE(bmr, activityLevel);
          personalizedGoal = _calculateDailyCalorieGoal(tdee: tdee, goal: goal);
          if (goal == 'lose') {
            personalizedGoalMsg = 'To lose weight, you should burn about ${personalizedGoal.toStringAsFixed(0)} kcal/day!';
          } else if (goal == 'gain') {
            personalizedGoalMsg = 'To gain weight, you should burn about ${personalizedGoal.toStringAsFixed(0)} kcal/day!';
          } else {
            personalizedGoalMsg = 'To maintain weight, you should burn about ${personalizedGoal.toStringAsFixed(0)} kcal/day!';
          }
        }
        final dailyGoal = userData['dailyCalorieGoal'] != null
            ? (userData['dailyCalorieGoal'] as num).toDouble()
            : personalizedGoal ?? CaloriesBurnBox.dailyGoal;
        final double dailyGoalDouble = (dailyGoal as num).toDouble();
        final weeklyGoal = 7 * dailyGoalDouble;

        return FutureBuilder<double>(
          future: _getWeeklyCalories(user.uid, isTrainer),
          builder: (context, weeklySnapshot) {
            final burnedThisWeek = weeklySnapshot.data ?? 0.0;
            final remaining = (weeklyGoal - burnedThisWeek).clamp(0, weeklyGoal);

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(isTrainer ? 'trainer' : 'users')
                  .doc(user.uid)
                  .collection('daily_calories')
                  .doc(today.toIso8601String())
                  .snapshots(),
              builder: (context, dailySnapshot) {
                final dailyData = dailySnapshot.data?.data() as Map<String, dynamic>? ?? {};
                final todayCalories = dailyData['calories'] ?? 0;
                final progress = (todayCalories / dailyGoal).clamp(0.0, 1.0);
                final remainingToday = (dailyGoal - todayCalories).clamp(0, dailyGoal);

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CaloriesHistoryPage(isTrainer: isTrainer),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF3A4CB1),
                          const Color(0xFF2A3A9E),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Today\'s Calories',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$todayCalories',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        'kcal',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_fire_department,
                                color: Colors.orange,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Progress Bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Daily Goal: $dailyGoal kcal',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 1.0 ? Colors.green : Colors.orange,
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                        // Weekly Progress Bar
                        FutureBuilder<double>(
                          future: _getWeeklyCalories(user.uid, isTrainer),
                          builder: (context, weeklySnapshot) {
                            final burnedThisWeek = weeklySnapshot.data ?? 0.0;
                            final weeklyProgress = (burnedThisWeek / weeklyGoal).clamp(0.0, 1.0);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Weekly Goal: ${weeklyGoal.toStringAsFixed(0)} kcal',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${(weeklyProgress * 100).toInt()}%',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: weeklyProgress,
                                    backgroundColor: Colors.white.withOpacity(0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      weeklyProgress >= 1.0 ? Colors.green : Colors.orange,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Daily Goals', overflow: TextOverflow.ellipsis),
                              onPressed: () async {
                                await showDialog(
                                  context: context,
                                  builder: (context) => _EditDailyGoalsDialog(isTrainer: isTrainer),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              Expanded(child: _buildInfoItem(
                                icon: Icons.calendar_today,
                                label: 'Last Workout',
                                value: lastWorkout != null
                                    ? _formatDate(lastWorkout.toDate())
                                    : 'No workouts',
                              )),
                              Expanded(child: _buildInfoItem(
                                icon: Icons.local_fire_department,
                                label: 'Total Calories',
                                value: '$totalCaloriesBurned kcal',
                                iconColor: Colors.orange,
                              )),
                              Expanded(child: _buildInfoItem(
                                icon: Icons.trending_up,
                                label: 'Streak',
                                value: '$workoutStreak days',
                                iconColor: Colors.green,
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Tap to view history',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'You have ${remainingToday.toStringAsFixed(0)} kcal left to burn today!',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildLoadingBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3A9E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor ?? Colors.white,
            size: 15,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Future<double> _getWeeklyCalories(String userId, bool isTrainer) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final query = await FirebaseFirestore.instance
        .collection(isTrainer ? 'trainer' : 'users')
        .doc(userId)
        .collection('daily_calories')
        .where('date', isGreaterThanOrEqualTo: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day))
        .get();
    double total = 0.0;
    for (var doc in query.docs) {
      final raw = doc['calories'];
      if (raw is int) {
        total += raw.toDouble();
      } else if (raw is double) {
        total += raw;
      }
    }
    return total;
  }

  double _calculateBMR({
    required double weight,
    required double height,
    required int age,
    required String gender,
  }) {
    if (gender == 'male') {
      return 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      return 10 * weight + 6.25 * height - 5 * age - 161;
    }
  }

  double _calculateTDEE(double bmr, String activityLevel) {
    switch (activityLevel) {
      case 'sedentary':
        return bmr * 1.2;
      case 'light':
        return bmr * 1.375;
      case 'moderate':
        return bmr * 1.55;
      case 'active':
        return bmr * 1.725;
      default:
        return bmr * 1.2;
    }
  }

  double _calculateDailyCalorieGoal({
    required double tdee,
    required String goal,
    double deficit = 500,
    double surplus = 300,
  }) {
    if (goal == 'lose') {
      return tdee - deficit;
    } else if (goal == 'gain') {
      return tdee + surplus;
    } else {
      return tdee;
    }
  }
}

class _EditProfileGoalDialog extends StatefulWidget {
  final bool isTrainer;
  const _EditProfileGoalDialog({required this.isTrainer});

  @override
  State<_EditProfileGoalDialog> createState() => _EditProfileGoalDialogState();
}

class _EditProfileGoalDialogState extends State<_EditProfileGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  double? weight;
  double? height;
  int? age;
  String gender = 'male';
  String activityLevel = 'moderate';
  String goal = 'maintain';
  double? dailyCalorieGoal;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection(widget.isTrainer ? 'trainer' : 'users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};
    setState(() {
      weight = (data['weight'] as num?)?.toDouble();
      height = (data['height'] as num?)?.toDouble();
      age = (data['age'] as num?)?.toInt();
      gender = (data['gender'] ?? 'male').toString().toLowerCase();
      activityLevel = data['activityLevel'] ?? 'moderate';
      goal = data['goal'] ?? 'maintain';
      dailyCalorieGoal = (data['dailyCalorieGoal'] as num?)?.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Profile & Goal'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: weight?.toString(),
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter weight' : null,
                onSaved: (v) => weight = double.tryParse(v ?? ''),
              ),
              TextFormField(
                initialValue: height?.toString(),
                decoration: const InputDecoration(labelText: 'Height (cm)'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter height' : null,
                onSaved: (v) => height = double.tryParse(v ?? ''),
              ),
              TextFormField(
                initialValue: age?.toString(),
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter age' : null,
                onSaved: (v) => age = int.tryParse(v ?? ''),
              ),
              DropdownButtonFormField<String>(
                value: gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                ],
                onChanged: (v) => setState(() => gender = v ?? 'male'),
              ),
              DropdownButtonFormField<String>(
                value: activityLevel,
                decoration: const InputDecoration(labelText: 'Activity Level'),
                items: const [
                  DropdownMenuItem(value: 'sedentary', child: Text('Sedentary (little/no exercise)')),
                  DropdownMenuItem(value: 'light', child: Text('Light (1-3 days/week)')),
                  DropdownMenuItem(value: 'moderate', child: Text('Moderate (3-5 days/week)')),
                  DropdownMenuItem(value: 'active', child: Text('Active (6-7 days/week)')),
                ],
                onChanged: (v) => setState(() => activityLevel = v ?? 'moderate'),
              ),
              DropdownButtonFormField<String>(
                value: goal,
                decoration: const InputDecoration(labelText: 'Goal'),
                items: const [
                  DropdownMenuItem(value: 'lose', child: Text('Lose Weight')),
                  DropdownMenuItem(value: 'maintain', child: Text('Maintain Weight')),
                  DropdownMenuItem(value: 'gain', child: Text('Gain Weight')),
                ],
                onChanged: (v) => setState(() => goal = v ?? 'maintain'),
              ),
              TextFormField(
                initialValue: dailyCalorieGoal?.toString(),
                decoration: const InputDecoration(labelText: 'Daily Calorie Goal (kcal, optional)'),
                keyboardType: TextInputType.number,
                onSaved: (v) => dailyCalorieGoal = double.tryParse(v ?? ''),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              _formKey.currentState?.save();
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection(widget.isTrainer ? 'trainer' : 'users')
                    .doc(user.uid)
                    .update({
                  'weight': weight,
                  'height': height,
                  'age': age,
                  'gender': gender,
                  'activityLevel': activityLevel,
                  'goal': goal,
                  if (dailyCalorieGoal != null && dailyCalorieGoal! > 0) 'dailyCalorieGoal': dailyCalorieGoal,
                });
              }
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EditDailyGoalsDialog extends StatefulWidget {
  final bool isTrainer;
  const _EditDailyGoalsDialog({required this.isTrainer});

  @override
  State<_EditDailyGoalsDialog> createState() => _EditDailyGoalsDialogState();
}

class _EditDailyGoalsDialogState extends State<_EditDailyGoalsDialog> {
  final _formKey = GlobalKey<FormState>();
  double? dailyCalorieGoal;

  @override
  void initState() {
    super.initState();
    _loadGoal();
  }

  Future<void> _loadGoal() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection(widget.isTrainer ? 'trainer' : 'users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};
    setState(() {
      dailyCalorieGoal = (data['dailyCalorieGoal'] as num?)?.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Daily Goal'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: TextFormField(
            initialValue: dailyCalorieGoal?.toString(),
            decoration: const InputDecoration(labelText: 'Daily Calorie Goal (kcal)'),
            keyboardType: TextInputType.number,
            validator: (v) => v == null || v.isEmpty ? 'Enter a value' : null,
            onSaved: (v) => dailyCalorieGoal = double.tryParse(v ?? ''),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState?.validate() ?? false) {
              _formKey.currentState?.save();
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && dailyCalorieGoal != null && dailyCalorieGoal! > 0) {
                await FirebaseFirestore.instance
                    .collection(widget.isTrainer ? 'trainer' : 'users')
                    .doc(user.uid)
                    .update({'dailyCalorieGoal': dailyCalorieGoal});
              }
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
} 