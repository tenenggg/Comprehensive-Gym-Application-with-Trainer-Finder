import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class NotificationBadge extends StatefulWidget {
  final Widget child;
  final String? userId;
  final double? size;
  final Color? backgroundColor;
  final Color? textColor;

  const NotificationBadge({
    super.key,
    required this.child,
    this.userId,
    this.size = 16,
    this.backgroundColor = const Color(0xFFFF3B30),
    this.textColor = Colors.white,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final count = await _notificationService.getUnreadNotificationCount(userId);
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    
    return StreamBuilder<int>(
      stream: _notificationService.getUnreadNotificationCountStream(userId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _unreadCount = snapshot.data!;
        }
        
        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            if (_unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints: BoxConstraints(
                    minWidth: widget.size!,
                    minHeight: widget.size!,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF1A2468),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                      style: TextStyle(
                        color: widget.textColor,
                        fontSize: widget.size! * 0.7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
} 