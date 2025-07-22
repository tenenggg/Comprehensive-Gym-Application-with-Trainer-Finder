import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import './booking_schedule_page.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
import '../../services/trainer_service.dart';
import '../../models/trainer_model.dart';
import '../../widgets/profile_image_widget.dart';

class TrainerFinderPage extends StatefulWidget {
  const TrainerFinderPage({super.key});

  @override
  State<TrainerFinderPage> createState() => _TrainerFinderPageState();
}

class _TrainerFinderPageState extends State<TrainerFinderPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';

  double? _minFee;
  double? _maxFee;

  String? _selectedTimeSlot;
  DateTime? _selectedDate;
  
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  List<TrainerModel> _trainers = [];
  bool _isLoadingTrainers = false;

  final List<String> _timeSlots = [
    '09:00 AM',
    '10:00 AM',
    '11:00 AM',
    '12:00 PM',
    '02:00 PM',
    '03:00 PM',
    '04:00 PM',
    '05:00 PM',
    '06:00 PM',
    '07:00 PM',
    '08:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await TrainerService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
        await _loadTrainers();
      } else {
        setState(() {
          _isLoadingLocation = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get your location. Showing all trainers.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        await _loadTrainers();
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      await _loadTrainers();
    }
  }

  Future<void> _loadTrainers() async {
    setState(() {
      _isLoadingTrainers = true;
    });

    try {
      List<TrainerModel> trainers;
      
      if (_currentPosition != null) {
        // Use location-based search with 30km radius
        if (_selectedDate != null && _selectedTimeSlot != null) {
          trainers = await TrainerService.getAvailableTrainers(
            _currentPosition!,
            selectedDate: _selectedDate!,
            selectedTimeSlot: _selectedTimeSlot!,
            searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
            minFee: _minFee,
            maxFee: _maxFee,
            userId: _auth.currentUser?.uid,
            radius: 30000, // 30km
          );
        } else {
          trainers = await TrainerService.getNearbyTrainers(
            _currentPosition!,
            searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
            minFee: _minFee,
            maxFee: _maxFee,
            radius: 30000, // 30km
          );
        }
      } else {
        // Fallback to original method without location
        trainers = await _getTrainersWithoutLocation();
      }

      setState(() {
        _trainers = trainers;
        _isLoadingTrainers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTrainers = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading trainers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<TrainerModel>> _getTrainersWithoutLocation() async {
    // Original method for backward compatibility
    final querySnapshot = await _firestore.collection('trainer').get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      return TrainerModel.fromMap(data, doc.id);
    }).where((trainer) {
      final name = trainer.name.toLowerCase();
      final specialization = trainer.specialization.toLowerCase();
      final matchesQuery = _searchQuery.isEmpty || 
          name.contains(_searchQuery.toLowerCase()) || 
          specialization.contains(_searchQuery.toLowerCase());
      final matchesMin = _minFee == null || trainer.sessionFee >= _minFee!;
      final matchesMax = _maxFee == null || trainer.sessionFee <= _maxFee!;
      return matchesQuery && matchesMin && matchesMax;
    }).toList();
  }

  void _showFeeFilterDialog() {
    final minController = TextEditingController(text: _minFee?.toString() ?? '');
    final maxController = TextEditingController(text: _maxFee?.toString() ?? '');
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A2468),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF212E83),
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by Session Fee',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Min Fee (RM)',
                  labelStyle: TextStyle(color: Colors.blue.shade100),
                  prefixIcon: const Icon(Icons.arrow_downward, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.blue.shade100,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: maxController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Max Fee (RM)',
                  labelStyle: TextStyle(color: Colors.blue.shade100),
                  prefixIcon: const Icon(Icons.arrow_upward, color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.blue.shade100,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _minFee = null;
                        _maxFee = null;
                      });
                      Navigator.pop(context);
                      _loadTrainers();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _minFee = double.tryParse(minController.text);
                        _maxFee = double.tryParse(maxController.text);
                      });
                      Navigator.pop(context);
                      _loadTrainers();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAvailabilityFilterDialog() {
    DateTime? tempSelectedDate = _selectedDate;
    String? tempSelectedTimeSlot = _selectedTimeSlot;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A2468),
          title: const Text(
            'Filter by Availability',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date Selection
              const Text(
                'Select Date',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: tempSelectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Colors.blue,
                            onPrimary: Colors.white,
                            surface: Color(0xFF1A2468),
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() {
                      tempSelectedDate = date;
                      tempSelectedTimeSlot = null; // Reset time slot when date changes
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tempSelectedDate != null
                            ? DateFormat('MMM d, yyyy').format(tempSelectedDate!)
                            : 'Select Date',
                        style: TextStyle(
                          color: tempSelectedDate != null
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Time Slot Selection
              const Text(
                'Select Time',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: tempSelectedTimeSlot,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A2468),
                  underline: const SizedBox(),
                  hint: const Text(
                    'Select Time Slot',
                    style: TextStyle(color: Colors.white70),
                  ),
                  items: _getAvailableTimeSlotsForDate(tempSelectedDate).map((String slot) {
                    return DropdownMenuItem<String>(
                      value: slot,
                      child: Text(
                        slot,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() => tempSelectedTimeSlot = newValue);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  tempSelectedDate = null;
                  tempSelectedTimeSlot = null;
                });
                Navigator.pop(context);
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Update parent state with selected values
                this.setState(() {
                  _selectedDate = tempSelectedDate;
                  _selectedTimeSlot = tempSelectedTimeSlot;
                });
                Navigator.pop(context);
                _loadTrainers();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
              ),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bookTrainer(String trainerId, String trainerName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        throw Exception('User profile not found');
      }

      final userName = userDoc.data()?['name'] ?? 'Unknown User';
      final bookingData = {
        'userId': user.uid,
        'userName': userName,
        'trainerId': trainerId,
        'trainerName': trainerName,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add booking to bookings collection
      await _firestore.collection('bookings').add(bookingData);

      // Create notification for the trainer
      final notificationService = NotificationService();
      await notificationService.createBookingRequestNotification(
        trainerId: trainerId,
        trainerName: trainerName,
        userId: user.uid,
        userName: userName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking request sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error booking trainer: $e'),
          backgroundColor: Colors.red,
        ),
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
        title: const Text(
          'Find Trainer',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: _getCurrentLocation,
            tooltip: 'Refresh Location',
          ),
          IconButton(
            icon: const Icon(Icons.access_time, color: Colors.white),
            onPressed: _showAvailabilityFilterDialog,
            tooltip: 'Filter by Availability',
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            onPressed: _showFeeFilterDialog,
            tooltip: 'Filter by Session Fee',
          ),
        ],
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Location indicator
                    if (_currentPosition != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Finding trainers within 30km',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Search field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search trainers...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                          // Debounce search to avoid too many API calls
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (mounted) {
                              _loadTrainers();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingLocation || _isLoadingTrainers
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _trainers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_off,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No trainers found nearby'
                                      : 'No trainers found matching "$_searchQuery"',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                                                 if (_currentPosition != null) ...[
                                   const SizedBox(height: 8),
                                   Text(
                                     'Searching within 30km of your location',
                                     style: TextStyle(
                                       color: Colors.white.withOpacity(0.7),
                                       fontSize: 14,
                                     ),
                                   ),
                                 ],
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _trainers.length,
                            itemBuilder: (context, index) {
                              final trainer = _trainers[index];
                              return _buildTrainerCard(
                                trainer.id,
                                trainer.name,
                                trainer.specialization,
                                trainer.experience.toString(),
                                trainer.sessionFee,
                                context,
                                trainer: trainer,
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrainerCard(String trainerId, String trainerName, String specialization, String experience, double sessionFee, BuildContext context, {TrainerModel? trainer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: ProfileImageDisplay(
          imageUrl: trainer?.profileImage,
          size: 48,
        ),
        title: Text(
          trainerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Specialization: $specialization',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Experience: $experience years',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Session Fee: RM${sessionFee.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (trainer?.hasLocation == true && trainer?.distance != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.blue.shade300,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    TrainerService.formatDistance(trainer!.distance!),
                    style: TextStyle(
                      color: Colors.blue.shade300,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (trainer?.address != null && trainer!.address!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                trainer!.address!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () async {
            final trainerDoc = await _firestore
                .collection('trainer')
                .doc(trainerId)
                .get();
            final sessionFee = (trainerDoc.data()?['sessionFee'] ?? 50.0).toDouble();
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingSchedulePage(
                  trainerId: trainerId,
                  trainerName: trainerName,
                  specialization: specialization,
                  experience: int.parse(experience),
                  sessionFee: sessionFee,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Book',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  List<String> _getAvailableTimeSlotsForDate(DateTime? date) {
    if (date == null) {
      return _timeSlots;
    }

    final now = DateTime.now();
    final selectedDate = DateTime(date.year, date.month, date.day);
    
    // If selected date is today, filter out past time slots
    final isToday = selectedDate.year == now.year && 
                   selectedDate.month == now.month && 
                   selectedDate.day == now.day;
    
    return _timeSlots.where((slot) {
      // If it's today, check if the time slot has passed
      if (isToday) {
        final slotTime = _parseTimeSlot(slot);
        final currentTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
        
        // Add 30 minutes buffer to current time to prevent booking too close to current time
        final bufferTime = currentTime.add(const Duration(minutes: 30));
        
        return slotTime.isAfter(bufferTime);
      }
      
      // If it's a future date, all slots are available
      return true;
    }).toList();
  }
  
  DateTime _parseTimeSlot(String timeSlot) {
    // Parse time slots like "09:00 AM", "02:00 PM"
    final parts = timeSlot.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final period = parts[1];
    
    // Convert to 24-hour format
    if (period == 'PM' && hour != 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }
    
    return DateTime(_selectedDate?.year ?? DateTime.now().year, 
                   _selectedDate?.month ?? DateTime.now().month, 
                   _selectedDate?.day ?? DateTime.now().day, 
                   hour, minute);
  }
} 