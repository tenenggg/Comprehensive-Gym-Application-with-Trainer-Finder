import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

class NotificationPage extends StatefulWidget {
  final bool isTrainer;
  
  const NotificationPage({
    super.key,
    this.isTrainer = false,
  });

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationService _notificationService = NotificationService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    if (_currentUserId != null) {
      final count = await _notificationService.getUnreadNotificationCount(_currentUserId!);
      setState(() {
        _unreadCount = count;
      });
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.bookingRequest:
        return Icons.calendar_today;
      case NotificationType.bookingConfirmed:
        return Icons.check_circle;
      case NotificationType.bookingCancelled:
        return Icons.cancel;
      case NotificationType.paymentReceived:
        return Icons.payment;
      case NotificationType.paymentHeld:
        return Icons.pending_actions;
      case NotificationType.paymentReleased:
        return Icons.payment_outlined;
      case NotificationType.refund:
        return Icons.money_off;
      case NotificationType.calorieReminder:
        return Icons.local_fire_department;
      case NotificationType.exerciseReminder:
        return Icons.fitness_center;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.bookingRequest:
        return Colors.blue;
      case NotificationType.bookingConfirmed:
        return Colors.green;
      case NotificationType.bookingCancelled:
        return Colors.red;
      case NotificationType.paymentReceived:
        return Colors.orange;
      case NotificationType.paymentHeld:
        return Colors.orange;
      case NotificationType.paymentReleased:
        return Colors.green;
      case NotificationType.refund:
        return Colors.red;
      case NotificationType.calorieReminder:
        return Colors.purple;
      case NotificationType.exerciseReminder:
        return Colors.teal;
      case NotificationType.announcement:
        return Colors.indigo;
      case NotificationType.general:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.status == NotificationStatus.unread) {
      await _notificationService.markNotificationAsRead(notification.id);
      _loadUnreadCount();
    }
  }

  Future<void> _markAllAsRead() async {
    if (_currentUserId != null) {
      await _notificationService.markAllNotificationsAsRead(_currentUserId!);
      setState(() {
        _unreadCount = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _notificationService.deleteNotification(notification.id);
      if (notification.status == NotificationStatus.unread) {
        _loadUnreadCount();
      }
    }
  }

  Future<void> _createTestNotification() async {
    if (_currentUserId != null) {
      await _notificationService.createNotification(
        userId: _currentUserId!,
        title: 'Test Notification',
        body: 'This is a test notification created at ${DateTime.now().toString()}',
        type: NotificationType.general,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A2468),
        body: Center(
          child: Text(
            'Please log in to view notifications',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A2468),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, color: Colors.white70),
              label: const Text(
                'Mark all read',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.getUserNotifications(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            );
          }

          if (snapshot.hasError) {
            final error = snapshot.error.toString();
            if (error.contains('failed-precondition') && error.contains('index')) {
              return _buildSetupInProgress();
            }
            return _buildError(error);
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification);
            },
          );
        },
      ),
      floatingActionButton: widget.isTrainer 
          ? FloatingActionButton(
              onPressed: _createTestNotification,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final isUnread = notification.status == NotificationStatus.unread;
    
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(notification),
      child: GestureDetector(
        onTap: () => _markAsRead(notification),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isUnread
                ? Colors.white.withOpacity(0.15)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: isUnread
                ? Border.all(color: Colors.white24, width: 1)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getTimeAgo(notification.timestamp),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                          if (notification.senderName != null) ...[
                            const SizedBox(width: 16),
                            Icon(
                              Icons.person,
                              size: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'From: ${notification.senderName}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll see your notifications here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          if (widget.isTrainer) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _createTestNotification,
              child: const Text('Create Test Notification'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetupInProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hourglass_empty,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Setting up notifications',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This is a one-time setup and should be ready in a few minutes. Please check back soon.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          'Error loading notifications: $error',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
} 