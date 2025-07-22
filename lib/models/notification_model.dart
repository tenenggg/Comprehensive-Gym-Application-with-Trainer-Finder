import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  bookingRequest,
  bookingConfirmed,
  bookingCancelled,
  paymentReceived,
  paymentHeld,
  paymentReleased,
  refund,
  calorieReminder,
  exerciseReminder,
  announcement,
  general,
}

enum NotificationStatus {
  unread,
  read,
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationStatus status;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final String? senderId;
  final String? senderName;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.status,
    required this.timestamp,
    this.data,
    this.senderId,
    this.senderName,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${map['type']}',
        orElse: () => NotificationType.general,
      ),
      status: NotificationStatus.values.firstWhere(
        (e) => e.toString() == 'NotificationStatus.${map['status']}',
        orElse: () => NotificationStatus.unread,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      data: map['data'],
      senderId: map['senderId'],
      senderName: map['senderName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'data': data,
      'senderId': senderId,
      'senderName': senderName,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    NotificationStatus? status,
    DateTime? timestamp,
    Map<String, dynamic>? data,
    String? senderId,
    String? senderName,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      data: data ?? this.data,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
    );
  }
} 