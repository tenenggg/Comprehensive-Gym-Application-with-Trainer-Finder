import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/src/platform_specifics/android/bitmap.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initialize() async {
    try {
      // Initialize timezone
      tz.initializeTimeZones();

      // Request permission for notifications
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Initialize local notifications
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsIOS = DarwinInitializationSettings();
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications.initialize(initializationSettings);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Get FCM token and save it only if user is logged in
      if (_auth.currentUser != null) {
        String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          await _saveFcmToken(token);
        }

        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen(_saveFcmToken);
      }
    } catch (e) {
      print('Error in notification service initialization: $e');
      // Don't rethrow the error, let the app continue
    }
  }

  Future<void> _saveFcmToken(String token) async {
    final user = _auth.currentUser;
    if (user != null) {
      // Check if user is a trainer or regular user
      final trainerDoc = await _firestore.collection('trainer').doc(user.uid).get();
      if (trainerDoc.exists) {
        await _firestore
            .collection('trainer')
            .doc(user.uid)
            .update({'fcmToken': token});
      } else {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      }
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Show local notification when app is in foreground
    const androidDetails = AndroidNotificationDetails(
      'calories_channel',
      'Calories Notifications',
      channelDescription: 'Notifications for calorie goals',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigPictureStyleInformation(
        DrawableResourceAndroidBitmap('big_notification'),
        largeIcon: DrawableResourceAndroidBitmap('notification_icon'),
        htmlFormatContent: true,
      ),
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body,
      notificationDetails,
    );
  }

  // Enhanced notification methods
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
    String? senderId,
    String? senderName,
  }) async {
    try {
      final notification = NotificationModel(
        id: '',
        userId: userId,
        title: title,
        body: body,
        type: type,
        status: NotificationStatus.unread,
        timestamp: DateTime.now(),
        data: data,
        senderId: senderId,
        senderName: senderName,
      );

      await _firestore
          .collection('notifications')
          .add(notification.toMap());

      // Send push notification if user has FCM token
      await _sendPushNotification(userId, title, body);
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Future<void> _sendPushNotification(String userId, String title, String body) async {
    try {
      // Get user's FCM token
      String? fcmToken;
      
      // Check if user is a trainer
      final trainerDoc = await _firestore.collection('trainer').doc(userId).get();
      if (trainerDoc.exists) {
        fcmToken = trainerDoc.data()?['fcmToken'];
      } else {
        // Check if user is a regular user
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          fcmToken = userDoc.data()?['fcmToken'];
        }
      }

      if (fcmToken != null) {
        await _firestore.collection('push_notifications').add({
          'token': fcmToken,
          'title': title,
          'body': body,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({
        'status': NotificationStatus.read.toString().split('.').last,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: NotificationStatus.unread.toString().split('.').last)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {
          'status': NotificationStatus.read.toString().split('.').last,
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: NotificationStatus.unread.toString().split('.').last)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }

  Stream<int> getUnreadNotificationCountStream(String? userId) {
    if (userId == null) {
      return Stream.value(0);
    }
    
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: NotificationStatus.unread.toString().split('.').last)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
          print('Error in unread notification count stream: $error');
          return 0;
        });
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Specific notification creation methods
  Future<void> createBookingRequestNotification({
    required String trainerId,
    required String trainerName,
    required String userId,
    required String userName,
  }) async {
    await createNotification(
      userId: trainerId,
      title: 'New Booking Request',
      body: '$userName has requested to book a session with you',
      type: NotificationType.bookingRequest,
      data: {
        'bookingType': 'request',
        'userId': userId,
        'userName': userName,
      },
      senderId: userId,
      senderName: userName,
    );
  }

  Future<void> createBookingConfirmedNotification({
    required String userId,
    required String trainerName,
    required String bookingId,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Booking Confirmed',
      body: 'Your booking with $trainerName has been confirmed',
      type: NotificationType.bookingConfirmed,
      data: {
        'bookingType': 'confirmed',
        'bookingId': bookingId,
        'trainerName': trainerName,
      },
      senderName: trainerName,
    );
  }

  Future<void> createPaymentReceivedNotification({
    required String trainerId,
    required String userName,
    required double amount,
  }) async {
    await createNotification(
      userId: trainerId,
      title: 'Payment Received',
      body: 'You received RM ${amount.toStringAsFixed(2)} from $userName',
      type: NotificationType.paymentReceived,
      data: {
        'paymentType': 'received',
        'amount': amount,
        'userName': userName,
      },
      senderName: userName,
    );
  }

  Future<void> createPaymentHeldNotification({
    required String trainerId,
    required String userName,
    required double amount,
    required String bookingId,
  }) async {
    await createNotification(
      userId: trainerId,
      title: 'Payment Held in Escrow',
      body: 'RM ${amount.toStringAsFixed(2)} from $userName is held in escrow. Payment will be released after session completion.',
      type: NotificationType.paymentHeld,
      data: {
        'paymentType': 'held',
        'amount': amount,
        'userName': userName,
        'bookingId': bookingId,
      },
      senderName: userName,
    );
  }

  Future<void> createPaymentReleasedNotification({
    required String trainerId,
    required String userName,
    required double amount,
    required String bookingId,
  }) async {
    await createNotification(
      userId: trainerId,
      title: 'Payment Released',
      body: 'RM ${amount.toStringAsFixed(2)} from $userName has been released to your account.',
      type: NotificationType.paymentReleased,
      data: {
        'paymentType': 'released',
        'amount': amount,
        'userName': userName,
        'bookingId': bookingId,
      },
      senderName: 'Admin',
    );
  }

  Future<void> createExerciseReminderNotification({
    required String userId,
    required String exerciseName,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Exercise Reminder',
      body: 'Time to do your $exerciseName exercise!',
      type: NotificationType.exerciseReminder,
      data: {
        'exerciseName': exerciseName,
      },
    );
  }

  Future<void> createRefundNotification({
    required String userId,
    required double amount,
    required String bookingId,
    required String reason,
  }) async {
    await createNotification(
      userId: userId,
      title: 'Payment Refunded',
      body: 'RM ${amount.toStringAsFixed(2)} has been refunded to your account due to $reason.',
      type: NotificationType.refund,
      data: {
        'refundType': 'payment_refund',
        'amount': amount,
        'bookingId': bookingId,
        'reason': reason,
      },
      senderName: 'Admin',
    );
  }

  Future<void> createTrainerRefundNotification({
    required String trainerId,
    required double amount,
    required String bookingId,
    required String reason,
  }) async {
    await createNotification(
      userId: trainerId,
      title: 'Payment Refunded to User',
      body: 'RM ${amount.toStringAsFixed(2)} has been refunded to the user due to $reason.',
      type: NotificationType.refund,
      data: {
        'refundType': 'trainer_refund',
        'amount': amount,
        'bookingId': bookingId,
        'reason': reason,
      },
      senderName: 'Admin',
    );
  }

  // Existing methods for backward compatibility
  Future<void> checkAndNotifyCalorieGoal() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check if user is a trainer
    final trainerDoc = await _firestore.collection('trainer').doc(user.uid).get();
    final isTrainer = trainerDoc.exists;
    final userDoc = await _firestore
        .collection(isTrainer ? 'trainer' : 'users')
        .doc(user.uid)
        .get();
    
    if (!userDoc.exists) return;

    final userData = userDoc.data()!;
    final dailyGoal = userData['dailyCalorieGoal'] ?? 500; // Default goal if not set
    final userName = userData['name'] ?? 'User';

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final dailyCaloriesDoc = await _firestore
        .collection(isTrainer ? 'trainer' : 'users')
        .doc(user.uid)
        .collection('daily_calories')
        .doc(today.toIso8601String())
        .get();

    int todayCalories = 0;
    if (dailyCaloriesDoc.exists) {
      final data = dailyCaloriesDoc.data();
      if (data != null && data.containsKey('calories')) {
        todayCalories = (data['calories'] as num).toInt();
      }
    }

    final now = DateTime.now();
    final remaining = dailyGoal - todayCalories;
    
    // Morning reminder (9 AM) if no calories burned yet
    if (now.hour == 9 && todayCalories == 0) {
      await createNotification(
        userId: user.uid,
        title: 'Start Your Day Right! 🌅',
        body: 'Time to start working on your daily goal of $dailyGoal calories!',
        type: NotificationType.calorieReminder,
        data: {
          'dailyGoal': dailyGoal,
          'timeOfDay': 'morning',
          'remainingCalories': dailyGoal,
        },
      );
    }
    
    // Afternoon reminder (2 PM) if less than 50% achieved
    else if (now.hour == 14 && todayCalories < (dailyGoal * 0.5)) {
      await createNotification(
        userId: user.uid,
        title: 'Afternoon Check-in 🌞',
        body: 'You\'ve burned $todayCalories kcal so far. Still $remaining kcal to go!',
        type: NotificationType.calorieReminder,
        data: {
          'dailyGoal': dailyGoal,
          'timeOfDay': 'afternoon',
          'currentCalories': todayCalories,
          'remainingCalories': remaining,
          'percentageComplete': (todayCalories / dailyGoal * 100).round(),
        },
      );
    }
    
    // Evening reminder (6 PM) if goal not met
    else if (now.hour == 18 && todayCalories < dailyGoal) {
      final percentComplete = (todayCalories / dailyGoal * 100).round();
      String message;
      if (percentComplete >= 75) {
        message = 'Almost there! Just $remaining kcal left to reach your goal.';
      } else if (percentComplete >= 50) {
        message = 'You\'re making progress! $remaining kcal left to burn today.';
      } else {
        message = 'You still have $remaining kcal to burn to reach your goal!';
      }

      await createNotification(
        userId: user.uid,
        title: 'Evening Goal Check 🌙',
        body: message,
        type: NotificationType.calorieReminder,
        data: {
          'dailyGoal': dailyGoal,
          'timeOfDay': 'evening',
          'currentCalories': todayCalories,
          'remainingCalories': remaining,
          'percentageComplete': percentComplete,
        },
      );
    }

    // Goal achievement notification
    else if (todayCalories >= dailyGoal && !dailyCaloriesDoc.data()?['goalAchievedNotified']) {
      await createNotification(
        userId: user.uid,
        title: 'Goal Achieved! 🎉',
        body: 'Congratulations! You\'ve reached your daily goal of $dailyGoal calories!',
        type: NotificationType.calorieReminder,
        data: {
          'dailyGoal': dailyGoal,
          'timeOfDay': 'achievement',
          'currentCalories': todayCalories,
          'achievement': 'daily_goal',
        },
      );

      // Mark goal as notified to prevent duplicate notifications
      await _firestore
          .collection(isTrainer ? 'trainer' : 'users')
          .doc(user.uid)
          .collection('daily_calories')
          .doc(today.toIso8601String())
          .set({
            'goalAchievedNotified': true,
          }, SetOptions(merge: true));
    }
  }

  Future<void> showLocalNotification({required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'calories_channel',
      'Calories Notifications',
      channelDescription: 'Notifications for calorie goals',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> scheduleDailyNotifications() async {
    try {
      // Cancel previous scheduled notifications
      await _localNotifications.cancelAll();

      // Define the times for notifications
      final times = [
        const TimeOfDay(hour: 9, minute: 0),   // 9:00 AM
        const TimeOfDay(hour: 14, minute: 0),  // 2:00 PM
        const TimeOfDay(hour: 19, minute: 0),  // 7:00 PM
      ];

      final now = tz.TZDateTime.now(tz.local);
      print('Current time in local timezone: $now');

      for (int i = 0; i < times.length; i++) {
        var scheduledTime = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          times[i].hour,
          times[i].minute,
        );

        // If the time has already passed today, schedule for tomorrow
        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }

        print('Scheduling notification for: $scheduledTime');

        await _localNotifications.zonedSchedule(
          1000 + i, // Unique ID for each notification
          'Calorie Goal Reminder',
          'Don\'t forget to log your calories and reach your daily goal!',
          scheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'calories_channel',
              'Calories Notifications',
              channelDescription: 'Notifications for calorie goals',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exact,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      print('Successfully scheduled all notifications');
    } catch (e) {
      print('Error scheduling notifications: $e');
    }
  }

  // Public method to trigger scheduling from outside
  Future<void> triggerDailyNotificationScheduling() async {
    try {
      final now = DateTime.now();
      
      // Schedule morning reminder for 9 AM
      if (now.hour < 9) {
        final morningTime = DateTime(now.year, now.month, now.day, 9);
        await _scheduleLocalNotification(morningTime);
      }
      
      // Schedule afternoon reminder for 2 PM
      if (now.hour < 14) {
        final afternoonTime = DateTime(now.year, now.month, now.day, 14);
        await _scheduleLocalNotification(afternoonTime);
      }
      
      // Schedule evening reminder for 6 PM
      if (now.hour < 18) {
        final eveningTime = DateTime(now.year, now.month, now.day, 18);
        await _scheduleLocalNotification(eveningTime);
      }
    } catch (e) {
      print('Error triggering daily notification scheduling: $e');
    }
  }

  Future<void> _scheduleLocalNotification(DateTime scheduledTime) async {
    try {
      final androidDetails = const AndroidNotificationDetails(
        'calories_channel',
        'Calories Notifications',
        channelDescription: 'Notifications for calorie goals',
        importance: Importance.high,
        priority: Priority.high,
      );

      final iosDetails = const DarwinNotificationDetails();

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);
      
      await _localNotifications.zonedSchedule(
        scheduledTime.millisecondsSinceEpoch ~/ 1000,
        'Calorie Goal Reminder',
        'Time to check your calorie goals!',
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Error scheduling local notification: $e');
    }
  }
}

// This needs to be a top-level function
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here
  print('Handling a background message: ${message.messageId}');
} 