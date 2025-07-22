import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';

class CaloriesHistoryPage extends StatelessWidget {
  final bool isTrainer;

  const CaloriesHistoryPage({
    super.key,
    required this.isTrainer,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFF232A6E),
      appBar: AppBar(
        title: const Text('Calories History'),
        backgroundColor: const Color(0xFF3A4CB1),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(isTrainer ? 'trainer' : 'users')
            .doc(user.uid)
            .collection('daily_calories')
            .orderBy('date', descending: true)
            .limit(30) // Show last 30 days
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('No workout history yet', style: TextStyle(color: Colors.white70)),
            );
          }

          // Prepare data for chart
          final chartData = docs.reversed.toList();
          final maxCalories = chartData.fold<double>(
            0,
            (max, doc) {
              final caloriesRaw = (doc.data() as Map<String, dynamic>)['calories'];
              final calories = (caloriesRaw is int)
                  ? caloriesRaw.toDouble()
                  : (caloriesRaw is double ? caloriesRaw : 0.0);
              return math.max(max, calories);
            },
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chart
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3A9E),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calories Burned (Last 30 Days)',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: GoogleFonts.poppins(
                                        color: Colors.white54,
                                        fontSize: 11,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= chartData.length) return const Text('');
                                    final date = (chartData[value.toInt()].data() as Map<String, dynamic>)['date'] as Timestamp;
                                    return Text(
                                      DateFormat('MM/dd').format(date.toDate()),
                                      style: GoogleFonts.poppins(
                                        color: Colors.white54,
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(chartData.length, (index) {
                                  final data = chartData[index].data() as Map<String, dynamic>;
                                  final raw = data['calories'];
                                  double caloriesValue = 0.0;
                                  if (raw is int) {
                                    caloriesValue = raw.toDouble();
                                  } else if (raw is double) {
                                    caloriesValue = raw;
                                  }
                                  return FlSpot(
                                    index.toDouble(),
                                    caloriesValue,
                                  );
                                }),
                                isCurved: true,
                                color: const Color(0xFFFFA726), // Orange accent
                                barWidth: 4,
                                isStrokeCapRound: true,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: const Color(0xFFFFA726).withOpacity(0.13),
                                ),
                              ),
                            ],
                            minY: 0,
                            maxY: maxCalories * 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Recent History',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final date = (data['date'] as Timestamp).toDate();
                    final raw = data['calories'];
                    double calories = 0.0;
                    if (raw is int) {
                      calories = raw.toDouble();
                    } else if (raw is double) {
                      calories = raw;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3A9E),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, MMM d').format(date),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.92),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.local_fire_department, color: const Color(0xFFFFA726), size: 22),
                              const SizedBox(width: 6),
                              Text(
                                '${calories.toStringAsFixed(0)} kcal',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFFA726),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 